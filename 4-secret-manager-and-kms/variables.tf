# variables.tf — inputs for the lesson. Defaults make `apply` work with one flag
# (project_id), unlike AWS where the account id is discovered at runtime.
variable "project_id" {
  description = "GCP project id where the key ring, crypto key and secret are created. GCP scopes every resource to a project — there is no account-wide default like AWS."
  type        = string
}

variable "location" {
  description = "Cloud KMS location for the key ring (e.g. us-central1, asia-southeast1, or the multi-region 'global'). The Secret Manager CMEK key must live in a location that matches the secret's replica region."
  type        = string
  default     = "us-central1"
}

variable "secret_id" {
  description = "Friendly id of the Secret Manager secret (unique within the project)."
  type        = string
  default     = "lesson-db-credentials"
}

variable "rotation_period" {
  description = "How often Cloud KMS rotates the crypto key material, in seconds (minimum 86400 = 1 day). 7776000s = 90 days."
  type        = string
  default     = "7776000s"
}

variable "grantee_member" {
  description = "IAM member that receives a decrypt-only binding on the crypto key, e.g. 'serviceAccount:app@PROJECT.iam.gserviceaccount.com'. Empty = skip the binding (offline fmt/validate path)."
  type        = string
  default     = ""
}

variable "enable_secret_rotation" {
  description = "Whether to attach a rotation schedule + Pub/Sub topic to the secret. Most labs leave this off because secret rotation requires a Pub/Sub topic and a subscriber that actually changes the value."
  type        = bool
  default     = false
}
