# outputs.tf — values the test flows consume after apply.

output "deny_policy_id" {
  description = "Full resource id of the deny policy (used by gcloud iam policies describe)."
  value       = google_iam_deny_policy.project_ceiling.id
}

output "deny_policy_name" {
  description = "Short name of the deny policy."
  value       = google_iam_deny_policy.project_ceiling.name
}

output "deny_attachment_point" {
  description = "URL-encoded attachment point (the project resource name)."
  value       = google_iam_deny_policy.project_ceiling.parent
}

output "break_glass_sa_email" {
  description = "Email of the break-glass service account exempted from the deny rule."
  value       = google_service_account.break_glass.email
}

output "conditional_binding_role" {
  description = "Role granted by the conditional allow binding."
  value       = google_project_iam_member.developer_compute_viewer.role
}
