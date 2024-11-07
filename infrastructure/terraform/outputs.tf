# outputs.tf
output "user_service_account" {
  description = "User's service account email"
  value       = module.user_resources.service_account_email
}

output "connector_resources" {
  description = "Resources created for each connector"
  value = {
    for k, v in module.connector_resources : k => {
      bucket_name = v.bucket_name
      ingestion_job = v.ingestion_job_name
      transformation_job = v.transformation_job_name
    }
  }
}