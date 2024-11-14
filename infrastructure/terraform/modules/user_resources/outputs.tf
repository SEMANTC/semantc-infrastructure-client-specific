# infrastructure/terraform/modules/user_resources/outputs.tf
output "service_account_email" {
  description = "email of the user's service account"
  value       = local.service_account_email
}

output "raw_dataset_id" {
  description = "id of the raw dataset"
  value       = try(
    google_bigquery_dataset.raw_data[0].dataset_id,
    data.google_bigquery_dataset.existing_raw.dataset_id
  )
}

output "transformed_dataset_id" {
  description = "id of the transformed dataset"
  value       = try(
    google_bigquery_dataset.transformed_data[0].dataset_id,
    data.google_bigquery_dataset.existing_transformed.dataset_id
  )
}