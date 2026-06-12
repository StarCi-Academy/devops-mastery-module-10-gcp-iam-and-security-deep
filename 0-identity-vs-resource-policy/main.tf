# main.tf — IDENTITY-level (project) vs RESOURCE-level IAM, side by side, on GCP.
#
# GCP model differs from AWS in three ways this lab makes concrete:
#   1. A grant is a member+role BINDING, you do NOT "attach a policy" to an
#      identity. The same role can be bound at PROJECT level or directly ON a
#      single resource (bucket / KMS key).
#   2. Bindings are ADDITIVE and INHERITED down Org -> Folder -> Project ->
#      Resource. A project-level binding is INHERITED by every bucket in the
#      project; a resource-level binding adds on top of that, scoped to one
#      resource only. There is no "deny" inside a normal binding.
#   3. An IAM Condition (CEL expression) refines a single binding so access is
#      time-boxed or path-scoped WITHOUT writing a custom role.

# random suffix -> globally-unique bucket name per student run.
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "identity-vs-resource-demo-${random_id.suffix.hex}"
}

# ---------------------------------------------------------------------------
# 1. IDENTITY-LEVEL grant via a CUSTOM ROLE bound at the PROJECT level. The
#    custom role packages a least-privilege permission set; the project-level
#    member binding makes it INHERITED by every bucket in the project. This is
#    "what may this member do across the project".
# ---------------------------------------------------------------------------
resource "google_project_iam_custom_role" "object_lister" {
  role_id     = "labObjectLister"
  title       = "Lab Object Lister"
  description = "Least-privilege custom role: list buckets and objects, no read of object data."
  stage       = "GA"
  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.list",
  ]
}

resource "google_project_iam_member" "lister_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.object_lister.id
  member  = var.reader_member
}

# ---------------------------------------------------------------------------
# 2. THE TARGET RESOURCE. uniform_bucket_level_access = true DISABLES ACLs, so
#    bucket-level IAM is the ONLY access path — exactly the model this lab
#    teaches. force_destroy lets `terraform destroy` clean a non-empty bucket.
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "demo" {
  name                        = local.bucket_name
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = true
}

# ---------------------------------------------------------------------------
# 3. RESOURCE-LEVEL grant: a binding attached DIRECTLY ON the bucket, scoped to
#    THIS bucket only (not inherited project-wide). google_storage_bucket_iam_
#    member is NON-AUTHORITATIVE: it adds one member to one role and leaves any
#    other binding on the bucket untouched.
# ---------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "reader_on_bucket" {
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.objectViewer"
  member = var.reader_member
}

# ---------------------------------------------------------------------------
# 4. RESOURCE-LEVEL grant WITH AN IAM CONDITION. Same member, same bucket, but
#    the CEL expression time-boxes the grant: access only BEFORE condition_
#    expiry. The condition refines THIS binding without any custom role. title +
#    expression are required; description is optional (Registry).
# ---------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "reader_timeboxed" {
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.legacyObjectReader"
  member = var.reader_member

  condition {
    title       = "time-boxed-read"
    description = "Grant expires at condition_expiry; demonstrates attribute-based access."
    expression  = "request.time < timestamp(\"${var.condition_expiry}\")"
  }
}

# ---------------------------------------------------------------------------
# 5. A second RESOURCE-LEVEL surface: a Cloud KMS crypto key with its OWN
#    binding. KMS key IAM is the GCP analogue of a key policy — the binding
#    lives on the key, scoped to the key only. roles/cloudkms.cryptoKeyEncrypter
#    Decrypter is the standard encrypt+decrypt role.
# ---------------------------------------------------------------------------
resource "google_kms_key_ring" "demo" {
  name     = "${local.bucket_name}-ring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "demo" {
  name     = "demo-key"
  key_ring = google_kms_key_ring.demo.id

  # Let `terraform destroy` schedule key destruction instead of erroring.
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key_iam_member" "encrypter" {
  crypto_key_id = google_kms_crypto_key.demo.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = var.reader_member
}

# ---------------------------------------------------------------------------
# 6. THE AUTHORITATIVE ALTERNATIVE. data.google_iam_policy renders a full policy
#    document from binding blocks; feeding it to a *_iam_policy resource REPLACES
#    every binding on that resource. Shown here on the bucket as a commented
#    reference so the additive _member bindings above stay intact — uncomment to
#    see authoritative-vs-additive in action (it would FIGHT the _member above).
# ---------------------------------------------------------------------------
data "google_iam_policy" "bucket_authoritative" {
  binding {
    role    = "roles/storage.objectViewer"
    members = [var.reader_member]

    condition {
      title       = "time-boxed-read"
      expression  = "request.time < timestamp(\"${var.condition_expiry}\")"
      description = "Same time-box, expressed authoritatively in one policy doc."
    }
  }
}
