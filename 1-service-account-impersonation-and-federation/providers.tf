terraform {
  # Floor at a modern CLI; the google provider 5.x needs >= 1.3 and we use
  # optional() object semantics plus the data.google_service_account_access_token
  # impersonation data source which is stable on recent releases.
  required_version = ">= 1.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      # `~> 5.40` is the PESSIMISTIC operator: allows >= 5.40.0 and < 6.0.0,
      # i.e. patch + minor upgrades but never the next major (6.x) which may
      # rename arguments. This is the production default for the google provider.
      version = "~> 5.40"
    }
  }
}

provider "google" {
  # project + region come from variables so the same code runs in any project.
  # Credentials are NEVER set here: the provider reads them from the default
  # chain (GOOGLE_APPLICATION_CREDENTIALS, gcloud auth application-default,
  # or the attached service account) so no secret lands in the repo.
  project = var.project_id
  region  = var.region
}
