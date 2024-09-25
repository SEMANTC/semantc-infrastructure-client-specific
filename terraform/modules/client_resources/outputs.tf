output "service_account_email" {
  value = google_service_account.client_sa.email
}

output "bucket_name" {
  value = google_storage_bucket.client_bucket.name
}

output "raw_dataset_id" {
  value = google_bigquery_dataset.raw_dataset.dataset_id
}

output "transformed_dataset_id" {
  value = google_bigquery_dataset.transformed_dataset.dataset_id
}

output "secret_name" {
  value = google_secret_manager_secret.client_token_secret.name
}