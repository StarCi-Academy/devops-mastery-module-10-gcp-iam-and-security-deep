# providers.tf — terraform{} block + Google provider version lock.
# This lesson drills the difference between IDENTITY-BASED policy (a member+role
# BINDING attached at the PROJECT level) and RESOURCE-LEVEL IAM (a binding
# attached directly ON a bucket / KMS key), plus GCP policy evaluation: bindings
# are ADDITIVE (no deny inside a normal binding), inherited down the hierarchy
# Organization -> Folder -> Project -> Resource, and refined by IAM Conditions.
#
# OFFLINE path: `terraform fmt`, `terraform validate`, and `terraform init`
# (provider plugin download) all run with NO credentials.
# APPLY path: creating the real bucket / custom role / KMS key + the IAM bindings
# needs GOOGLE_APPLICATION_CREDENTIALS (or `gcloud auth application-default
# login`) and a GOOGLE_PROJECT / project variable.

terraform {
  # Floor at a modern CLI: optional() object attributes + the for_each on
  # member sets used below need >= 1.5.
  required_version = ">= 1.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      # `~> 5.40` is the PESSIMISTIC operator: allows >= 5.40.0 and < 6.0.0,
      # i.e. patch + minor upgrades but never the next major (6.x) which may
      # rename arguments. Production default for the Google provider.
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# The provider block is where project + region + credentials resolve. project
# comes from a variable (or the GOOGLE_PROJECT env var); credentials come from
# Application Default Credentials so NO key JSON is ever written into the repo.
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "random" {}
