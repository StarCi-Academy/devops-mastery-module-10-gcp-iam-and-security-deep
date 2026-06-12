# outputs.tf — expose the folder + policy identifiers so a downstream step or
# gcloud can inspect the hierarchy without re-querying.

output "organization_name" {
  description = "The organization resource name (organizations/<org_id>) — the parent of the lab folder."
  value       = data.google_organization.org.name
}

output "folder_id" {
  description = "The lab folder resource name (folders/<folder_id>) — the guardrail attachment point that projects inherit from."
  value       = google_folder.lab.name
}

output "restrict_external_ip_policy" {
  description = "Resource name of the boolean-constraint org policy (.../policies/compute.vmExternalIpAccess) enforced on the folder."
  value       = google_org_policy_policy.restrict_external_ip.name
}

output "restrict_member_domains_policy" {
  description = "Resource name of the list-constraint org policy (.../policies/iam.allowedPolicyMemberDomains) enforced on the folder."
  value       = google_org_policy_policy.restrict_member_domains.name
}

output "folder_viewer_binding_etag" {
  description = "Etag of the folder IAM policy after adding the folderViewer member binding — proof the additive binding applied."
  value       = google_folder_iam_member.viewer.etag
}
