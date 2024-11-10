# infrastructure/terraform/outputs.tf
output "user_service_account" {
  description = "service account email created for the user"
  value       = module.user_resources.service_account_email
}

output "raw_dataset" {
  description = "name of the raw dataset created for the user"
  value       = module.user_resources.raw_dataset_id
}

output "transformed_dataset" {
  description = "name of the transformed dataset created for the user"
  value       = module.user_resources.transformed_dataset_id
}