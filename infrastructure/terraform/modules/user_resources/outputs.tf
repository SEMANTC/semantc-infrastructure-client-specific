# modules/user_resources/outputs.tf
output "service_account_email" {
  description = "Email of the user's service account"
  value       = google_service_account.user_sa.email
}

output "service_account_id" {
  description = "ID of the user's service account"
  value       = google_service_account.user_sa.id
}