# variables.tf — inputs that parameterise the lab. No secrets here.

variable "project_id" {
  description = "GCP project ID where the lab resources are created. IAM bindings here are PROJECT-level (inherited by every resource in the project)."
  type        = string
  default     = ""
}

variable "region" {
  description = "Region for the bucket and the KMS key ring. IAM is global; only these resources are regional."
  type        = string
  default     = "us-central1"
}

variable "reader_member" {
  description = "Identity that receives the read bindings, in GCP member syntax (user:..., group:..., serviceAccount:...). Defaults to a placeholder service account member; override with your own."
  type        = string
  default     = "serviceAccount:reader@example-project.iam.gserviceaccount.com"

  validation {
    # GCP member syntax always carries a type prefix and a colon.
    condition     = can(regex("^(user|group|serviceAccount|domain):", var.reader_member))
    error_message = "reader_member must start with user:, group:, serviceAccount: or domain:."
  }
}

variable "condition_expiry" {
  description = "RFC3339 timestamp; the time-boxed IAM Condition grants access only BEFORE this instant. Demonstrates attribute-based access without a custom role."
  type        = string
  default     = "2030-01-01T00:00:00Z"
}
