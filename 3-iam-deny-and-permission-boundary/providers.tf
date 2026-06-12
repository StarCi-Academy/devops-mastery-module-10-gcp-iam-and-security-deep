# providers.tf — terraform{} block + Google provider version lock.
# This lesson drills the GCP equivalent of an AWS permission boundary:
#   - google_iam_deny_policy: an explicit deny layer that beats every allow,
#     attached to a project (the URL-encoded resource name).
#   - an IAM Condition (CEL) on a google_project_iam_member binding: a guard
#     that scopes WHEN/WHERE an allow applies (region, time, resource tag).
#
# OFFLINE path: `terraform fmt`, `terraform validate`, and
# `terraform init -backend=false` (provider plugin download) all run with NO
# credentials.
# APPLY path: creating the real deny policy + conditional binding requires GCP
# credentials (GOOGLE_APPLICATION_CREDENTIALS or `gcloud auth application-default
# login`) plus GOOGLE_PROJECT, and the caller needs
# iam.denypolicies.create + resourcemanager.projects.setIamPolicy.

terraform {
  # Floor at a CLI that supports optional() in object variables.
  required_version = ">= 1.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      # `~> 5.40` allows >= 5.40.0 and < 6.0.0 — patch + minor upgrades only.
      version = "~> 5.40"
    }
  }
}

# Credentials resolve from the standard Google chain:
#   GOOGLE_APPLICATION_CREDENTIALS (service-account key file) OR
#   Application Default Credentials from `gcloud auth application-default login`.
# The project is the isolation unit in GCP — every resource lives inside it.
# No secret is ever committed to the repo.
provider "google" {
  project = var.project_id
  region  = var.gcp_region
}
