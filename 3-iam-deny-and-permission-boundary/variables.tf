# variables.tf — inputs for the deny-policy + conditional-binding lab.

variable "project_id" {
  description = "GCP project ID — the isolation boundary that the deny policy attaches to."
  type        = string
}

variable "gcp_region" {
  description = "Default region for the provider and the IAM Condition allow scope."
  type        = string
  default     = "asia-southeast1"
}

variable "student" {
  description = "Student identifier — stamped into resource names so a shared project stays collision-free."
  type        = string
}

variable "developer_member" {
  description = <<-EOT
    The IAM member the deny policy targets and the conditional binding grants to.
    Format: user:alice@example.com | serviceAccount:svc@PROJECT.iam.gserviceaccount.com | group:team@example.com.
  EOT
  type        = string
}
