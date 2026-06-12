# providers.tf — terraform{} block + Google provider version lock.
# This lesson drills GCP Organization Policy + the Resource Manager folder
# hierarchy as an org-level GUARDRAIL: a folder under the org, a BOOLEAN-
# constraint policy (restrict VM external IP), a LIST-constraint policy
# (restrict member domains), and a folder-level IAM binding — plus how this
# differs from AWS SCP (GCP attaches a member+role BINDING, never "attaches" a
# policy document to a principal).
#
# OFFLINE path: `terraform fmt`, `terraform validate`, and `terraform init`
# (provider plugin download) all run with NO credentials.
# APPLY path: creating a real folder / org policy needs ORG-LEVEL Google
# credentials (GOOGLE_APPLICATION_CREDENTIALS or gcloud auth + GOOGLE_PROJECT)
# with orgpolicy.policies.create on the organization, so apply is gated behind
# real creds (see .e2e require-creds flow).

terraform {
  # Floor at a modern CLI; the google provider 5.x needs >= 1.3 and we use
  # optional() object semantics plus a for_each over the constraints map.
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

# The provider block is where project + region resolve. Org Policy and folders
# are ORG-LEVEL resources (no project for the org/folder/policy themselves), but
# the provider still needs a project for quota + endpoint. Credentials are NEVER
# set here: the provider reads them from the default chain
# (GOOGLE_APPLICATION_CREDENTIALS, gcloud auth application-default, or the
# attached service account) so no secret lands in the repo.
provider "google" {
  project = var.project_id
  region  = var.region
}
