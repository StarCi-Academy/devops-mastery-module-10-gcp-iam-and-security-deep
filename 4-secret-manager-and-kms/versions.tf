# versions.tf — pin Terraform core and the Google provider.
# `terraform init` downloads the Google provider WITHOUT any credentials, so
# `fmt` / `validate` run fully offline. `apply` is the only step that calls GCP.
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.location

  # Label every resource the provider creates so cleanup / cost lookup can
  # filter by lesson=<slug>. default_labels merges into each resource's labels.
  default_labels = {
    lesson  = "4-secret-manager-and-kms"
    module  = "devops-mastery-module-10-gcp-iam-and-security-deep"
    managed = "terraform"
  }
}
