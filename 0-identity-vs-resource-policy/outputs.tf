# outputs.tf — values the student copies into gcloud / verification commands.

output "bucket_name" {
  description = "Name of the demo bucket the resource-level bindings target."
  value       = google_storage_bucket.demo.name
}

output "custom_role_id" {
  description = "Full id of the project-level custom role (projects/<project>/roles/labObjectLister)."
  value       = google_project_iam_custom_role.object_lister.id
}

output "crypto_key_id" {
  description = "Full id of the KMS crypto key carrying its own resource-level binding."
  value       = google_kms_crypto_key.demo.id
}

output "authoritative_policy_data" {
  description = "The authoritative policy JSON rendered by data.google_iam_policy (reference only; not applied)."
  value       = data.google_iam_policy.bucket_authoritative.policy_data
}
