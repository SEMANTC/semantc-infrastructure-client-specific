# infrastructure/terraform/modules/user_resources/outputs.tf
output "service_account_email" {
  description = "Email of the user's service account"
  value       = data.google_service_account.existing_sa[0].email
}

output "raw_dataset_id" {
  description = "ID of the raw dataset"
  value       = data.google_bigquery_dataset.raw_data[0].dataset_id
}

output "transformed_dataset_id" {
  description = "ID of the transformed dataset"
  value       = data.google_bigquery_dataset.transformed_data[0].dataset_id
}