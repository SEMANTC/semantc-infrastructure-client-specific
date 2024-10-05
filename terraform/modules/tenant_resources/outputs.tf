output "tenant_sa_email" {
  description = "Service Account email for the tenant"
  value       = google_service_account.tenant_sa.email
}

output "tenant_bucket_name" {
  description = "Cloud Storage Bucket name for the tenant"
  value       = google_storage_bucket.tenant_bucket_xero.name
}

output "raw_dataset_id" {
  description = "Raw BigQuery dataset ID for the tenant"
  value       = google_bigquery_dataset.raw_dataset.dataset_id
}

output "transformed_dataset_id" {
  description = "Transformed BigQuery dataset ID for the tenant"
  value       = google_bigquery_dataset.transformed_dataset.dataset_id
}