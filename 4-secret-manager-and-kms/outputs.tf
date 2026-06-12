# outputs.tf — values printed after apply (read with `terraform output`).
output "key_ring_id" {
  description = "Full resource id of the regional key ring (projects/.../locations/.../keyRings/...)."
  value       = google_kms_key_ring.this.id
}

output "crypto_key_id" {
  description = "Full resource id of the customer-managed crypto key (the KEK of envelope encryption)."
  value       = google_kms_crypto_key.this.id
}

output "secret_id" {
  description = "Short secret id used by the gcloud read-back command."
  value       = google_secret_manager_secret.db.secret_id
}

output "secret_name" {
  description = "Full resource name of the Secret Manager secret (projects/.../secrets/...)."
  value       = google_secret_manager_secret.db.name
}

output "secret_version_name" {
  description = "Full resource name of the live secret version."
  value       = google_secret_manager_secret_version.db.name
}
