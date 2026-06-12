output "target_service_account_email" {
  description = "Email of the privileged SA to impersonate. Pass as --impersonate-service-account or target_service_account."
  value       = google_service_account.target.email
}

output "caller_service_account_email" {
  description = "Email of the SA allowed to mint short-lived tokens for the target via Token Creator."
  value       = google_service_account.caller.email
}

output "workload_identity_pool_name" {
  description = "Full resource name of the Workload Identity Pool, keyed by project number."
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider_name" {
  description = "Full resource name of the OIDC provider; pass to the GitHub auth action as workload_identity_provider."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_principal_set" {
  description = "The principalSet:// member GitHub tokens map to; granted workloadIdentityUser on the target SA."
  value       = local.github_principal
}
