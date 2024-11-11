output "service_account_email" {
  description = "Email of the user's service account"
  value       = google_service_account.user_sa.email
}

output "raw_dataset_id" {
  description = "ID of the raw dataset"
  value       = google_bigquery_dataset.raw_data.dataset_id
}

output "transformed_dataset_id" {
  description = "ID of the transformed dataset"
  value       = google_bigquery_dataset.transformed_data.dataset_id
}