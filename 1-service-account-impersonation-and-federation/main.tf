# Resolve THIS project's number; the pool/provider resource names and the
# principalSet:// member string are keyed by project NUMBER, not project ID.
data "google_project" "current" {
  project_id = var.project_id
}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name_suffix = random_id.suffix.hex
  # principalSet member that the WIF provider maps every GitHub token to,
  # scoped down to a single repository via attribute.repository.
  github_principal = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.pool_id}/attribute.repository/${var.github_repository}"
}

# ---------------------------------------------------------------------------
# Part A — Service Account impersonation (short-lived token, no key)
# ---------------------------------------------------------------------------

# The privileged SA whose identity gets borrowed. It would hold the real
# business roles (here: object viewer on a bucket, granted out of band).
resource "google_service_account" "target" {
  account_id   = "wif-target-${local.name_suffix}"
  display_name = "Impersonation target — holds the real permissions"
  project      = var.project_id
}

# The caller SA that is allowed to impersonate the target. In real life this
# is a CI runner identity or a developer's bootstrap SA.
resource "google_service_account" "caller" {
  account_id   = "wif-caller-${local.name_suffix}"
  display_name = "Impersonation caller — allowed to mint target tokens"
  project      = var.project_id
}

# THE impersonation grant: caller may create short-lived tokens for target.
# Without this binding, generateAccessToken returns PERMISSION_DENIED.
resource "google_service_account_iam_member" "caller_can_impersonate" {
  service_account_id = google_service_account.target.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.caller.email}"
}

# ---------------------------------------------------------------------------
# Part B — Workload Identity Federation (keyless, external GitHub OIDC)
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions pool"
  description               = "Federates GitHub OIDC tokens to GCP without service account keys"
  project                   = var.project_id
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC provider"
  project                            = var.project_id

  # Map GitHub OIDC claims to Google attributes. google.subject is mandatory;
  # attribute.repository is what the principalSet member and the SA binding key on.
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Hard gate BEFORE any token is minted: only this repo's tokens are accepted.
  # Without an attribute_condition GCP rejects the provider for security.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    # GitHub's OIDC issuer; GCP fetches its JWKS from here to verify signatures.
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Let any GitHub token from the allowed repo impersonate the target SA.
# member is a principalSet, NOT a serviceAccount — this is the keyless bridge.
resource "google_service_account_iam_member" "github_can_impersonate" {
  service_account_id = google_service_account.target.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.github_principal
}
