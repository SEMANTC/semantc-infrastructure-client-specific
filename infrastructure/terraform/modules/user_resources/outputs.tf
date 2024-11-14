# infrastructure/terraform/modules/user_resources/outputs.tf
output "service_account_email" {
  description = "email of the user's service account"
  value       = local.service_account_email
}

output "raw_dataset_id" {
  description = "id of the raw dataset"
  value       = local.create_raw_dataset ? (
    google_bigquery_dataset.raw_data[0].dataset_id
  ) : (
    module.names.raw_dataset_id
  )
}

output "transformed_dataset_id" {
  description = "id of the transformed dataset"
  value       = local.create_transformed_dataset ? (
    google_bigquery_dataset.transformed_data[0].dataset_id
  ) : (
    module.names.transformed_dataset_id
  )
}