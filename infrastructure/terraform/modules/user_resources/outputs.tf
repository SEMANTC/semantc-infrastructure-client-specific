# infrastructure/terraform/modules/user_resources/outputs.tf
output "service_account_email" {
  description = "email of the user's service account"
  value       = local.service_account_email
}

output "service_account_id" {
  description = "id of the user's service account"
  value       = local.service_account_id
}