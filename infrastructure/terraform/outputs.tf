# outputs.tf
output "user_service_account" {
  description = "user's service account email"
  value       = module.user_resources.service_account_email
}