# Mint a short-lived OAuth2 access token for the target SA by impersonation.
# This data source calls iam.generateAccessToken at plan/apply time, so it needs
# real credentials AND the caller identity must already hold Token Creator on the
# target SA (the binding above). The token is non-refreshable and capped at 3600s.
#
# Gated behind a count so `validate`/`plan` stay offline-friendly by default:
# set -var 'mint_token=true' only when you have credentials and want a live token.
data "google_service_account_access_token" "impersonated" {
  count = var.mint_token ? 1 : 0

  target_service_account = google_service_account.target.email
  scopes                 = ["cloud-platform"]
  lifetime               = var.token_lifetime
}

variable "mint_token" {
  type        = bool
  description = "When true, call generateAccessToken to mint a live impersonated token (requires credentials)."
  default     = false
}

output "impersonated_token_prefix" {
  description = "First characters of the minted token, proof of impersonation. Empty unless mint_token=true."
  value       = var.mint_token ? substr(data.google_service_account_access_token.impersonated[0].access_token, 0, 8) : ""
  sensitive   = true
}
