# main.tf — Envelope encryption (CMEK) with a customer-managed Cloud KMS key
# plus a Secret Manager secret encrypted by that key. Read top-to-bottom:
# key ring -> crypto key -> IAM binding (grant) -> secret -> version -> rotation.
#
# GCP differs from AWS in three ways visible here:
#   1. A crypto key MUST live inside a key ring (an extra container AWS has no
#      equivalent for). The key ring is REGIONAL and CANNOT be deleted.
#   2. There is no "key policy" attached to the key. Access is a separate IAM
#      BINDING (member + role) resource — you never embed a policy JSON in the
#      key itself.
#   3. The project is the hard isolation boundary; every resource below is
#      scoped to var.project_id, discovered at apply time from the provider.

# Project metadata — used to reference the Secret Manager service agent, the
# Google-managed identity that performs envelope encryption on your behalf.
data "google_project" "current" {}

# random suffix -> unique key ring / key / secret names so two students in the
# same project do not collide.
resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# 1. Key ring — the regional container every crypto key must live in. There is
#    no AWS analogue: a CMK on AWS stands alone, a crypto key on GCP is always
#    "keyRings/<ring>/cryptoKeys/<key>". A key ring CANNOT be deleted from GCP;
#    terraform destroy only drops it from state (deletion_policy default ABANDON
#    semantics for the ring).
# ---------------------------------------------------------------------------
resource "google_kms_key_ring" "this" {
  name     = "lesson-ring-${random_id.suffix.hex}"
  location = var.location
}

# ---------------------------------------------------------------------------
# 2. The customer-managed crypto key. This is the KEK (key-encryption-key) of
#    envelope encryption: it never encrypts your data directly — it wraps the
#    per-secret data keys. ENCRYPT_DECRYPT + SOFTWARE protection is the CMEK
#    use case; rotation_period rotates the key material automatically.
# ---------------------------------------------------------------------------
resource "google_kms_crypto_key" "this" {
  name     = "lesson-cmek-${random_id.suffix.hex}"
  key_ring = google_kms_key_ring.this.id

  # The immutable purpose of the key. ENCRYPT_DECRYPT is the default and what
  # CMEK envelope encryption requires; ASYMMETRIC_SIGN/_DECRYPT and MAC_SIGN
  # cannot wrap a data key.
  purpose = "ENCRYPT_DECRYPT"

  # Every rotation_period seconds, KMS generates a new key version and makes it
  # primary. Old versions are kept so previously-wrapped data keys still
  # decrypt — rotation is free and needs no re-encrypt. Minimum 86400s (1 day).
  rotation_period = var.rotation_period

  version_template {
    # SOFTWARE keeps the key in Google's software HSM-backed store (cheapest);
    # HSM/EXTERNAL raise the protection level and the price.
    protection_level = "SOFTWARE"
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  # Lab-friendly: allow terraform destroy to schedule key versions for
  # destruction. Production often sets PREVENT so a key is never torn down by
  # accident (it would orphan every ciphertext it ever wrapped).
  lifecycle {
    prevent_destroy = false
  }
}

# ---------------------------------------------------------------------------
# 3a. Let the Secret Manager service agent use this key. CMEK requires the
#     Google-managed Secret Manager identity to hold the
#     cloudkms.cryptoKeyEncrypterDecrypter role on the key — otherwise the
#     secret cannot be encrypted and apply fails. This is an IAM BINDING, not a
#     policy embedded in the key (the GCP vs AWS difference).
# ---------------------------------------------------------------------------
resource "google_kms_crypto_key_iam_member" "secretmanager_agent" {
  crypto_key_id = google_kms_crypto_key.this.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# 3b. Optional least-privilege grant. A separate IAM member binding gives ONE
#     extra identity decrypt-only access — analogous to an AWS KMS grant, but
#     expressed as a normal IAM (member + role) resource. Created only when
#     grantee_member is supplied so the offline path stays clean.
# ---------------------------------------------------------------------------
resource "google_kms_crypto_key_iam_member" "decrypt_only" {
  count = var.grantee_member == "" ? 0 : 1

  crypto_key_id = google_kms_crypto_key.this.id

  # cryptoKeyDecrypter = Decrypt only, no Encrypt. The narrowest predefined role
  # for "this app may read CMEK-encrypted data but not write new ciphertext".
  role   = "roles/cloudkms.cryptoKeyDecrypter"
  member = var.grantee_member
}

# ---------------------------------------------------------------------------
# 4. The secret container. user_managed replication pins the secret to a single
#    region and binds it to OUR crypto key via customer_managed_encryption
#    (CMEK). Omit that block and Secret Manager uses a Google-managed key (less
#    control, no custom IAM on the key, no separate audit). The replica region
#    MUST be in the same location as the crypto key.
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret" "db" {
  secret_id = "${var.secret_id}-${random_id.suffix.hex}"

  replication {
    user_managed {
      replicas {
        location = var.location

        customer_managed_encryption {
          kms_key_name = google_kms_crypto_key.this.id
        }
      }
    }
  }

  # Optional automatic rotation. GCP only EMITS a Pub/Sub message on the
  # schedule — a subscriber you write must actually add the new version. Created
  # only when enable_secret_rotation is true (needs a topic, omitted by default).
  dynamic "rotation" {
    for_each = var.enable_secret_rotation ? [1] : []
    content {
      rotation_period    = "2592000s" # 30 days
      next_rotation_time = timeadd(timestamp(), "24h")
    }
  }

  dynamic "topics" {
    for_each = var.enable_secret_rotation ? [1] : []
    content {
      name = google_pubsub_topic.rotation[0].id
    }
  }

  # The service-agent IAM binding must exist before the secret tries to use the
  # key, otherwise the first encrypt fails with a permission error.
  depends_on = [google_kms_crypto_key_iam_member.secretmanager_agent]
}

# Pub/Sub topic that receives rotation notifications (only with rotation on).
resource "google_pubsub_topic" "rotation" {
  count = var.enable_secret_rotation ? 1 : 0
  name  = "lesson-secret-rotation-${random_id.suffix.hex}"
}

# ---------------------------------------------------------------------------
# 5. A secret VERSION holds the actual ciphertext. Each write creates a new
#    immutable, numbered version; the "latest" alias points at the newest
#    enabled one. secret_data is encrypted by the CMEK before being stored.
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "db" {
  secret = google_secret_manager_secret.db.id

  # JSON string is the convention for multi-field credentials. Secret Manager
  # asks the crypto key for a data key, encrypts this with it, and stores the
  # wrapped data key alongside the ciphertext — textbook envelope encryption.
  secret_data = jsonencode({
    username = "lesson_app"
    password = "ch4nge-me-${random_id.suffix.hex}"
    engine   = "postgres"
    host     = "db.internal.lesson"
    port     = 5432
  })

  # Mark this version enabled and serve it as the live value.
  enabled = true

  # Lab-friendly: destroy the version on terraform destroy.
  deletion_policy = "DELETE"
}
