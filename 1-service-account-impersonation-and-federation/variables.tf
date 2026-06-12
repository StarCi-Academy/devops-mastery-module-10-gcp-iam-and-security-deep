variable "project_id" {
  type        = string
  description = "GCP project ID where the service accounts, pool and provider are created."

  validation {
    # GCP project IDs are 6-30 chars, lowercase letters / digits / hyphens,
    # must start with a letter and not end with a hyphen.
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase, start with a letter)."
  }
}

variable "region" {
  type        = string
  description = "Default region for the google provider. IAM is global; region only affects regional resources."
  default     = "asia-southeast1"
}

variable "pool_id" {
  type        = string
  description = "Workload Identity Pool ID — final component of the pool resource name."
  default     = "github-pool"

  validation {
    # Registry rule: 4-32 chars, [a-z0-9-], cannot start with the reserved gcp- prefix.
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.pool_id)) && !startswith(var.pool_id, "gcp-")
    error_message = "pool_id must be 4-32 chars of [a-z0-9-] and must not start with the reserved gcp- prefix."
  }
}

variable "github_repository" {
  type        = string
  description = "GitHub repository allowed to federate, in owner/repo form. Scopes the attribute_condition so only this repo can impersonate."
  default     = "StarCi-Academy/devops-mastery-module-10-gcp-iam-and-security-deep"
}

variable "token_lifetime" {
  type        = string
  description = "Lifetime of the impersonated OAuth2 access token, e.g. 3600s. Hard-capped by GCP at 3600s (1 hour)."
  default     = "3600s"

  validation {
    # GCP caps impersonated tokens at 3600s; reject anything above to fail fast in Terraform.
    condition     = can(regex("^[1-9][0-9]{0,3}s$", var.token_lifetime)) && tonumber(trimsuffix(var.token_lifetime, "s")) <= 3600
    error_message = "token_lifetime must be a duration like 600s and not exceed 3600s (GCP hard cap)."
  }
}
