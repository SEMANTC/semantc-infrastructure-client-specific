# terraform/modules/client_resources/outputs.tf

output "client_sa_email" {
  description = "Service account email for the client"
  value       = google_service_account.client_sa.email
}

output "client_bucket_name" {
  description = "Storage bucket name for the client"
  value       = google_storage_bucket.client_bucket.name
}

output "raw_dataset_id" {
  description = "Raw BigQuery dataset ID for the client"
  value       = google_bigquery_dataset.raw_dataset.dataset_id
}

output "transformed_dataset_id" {
  description = "Transformed BigQuery dataset ID for the client"
  value       = google_bigquery_dataset.transformed_dataset.dataset_id
}