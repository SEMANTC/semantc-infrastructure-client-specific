# terraform/outputs.tf

output "client_service_account_email" {
  description = "Service account email for the client"
  value       = module.client_resources.client_sa_email
}

output "client_bucket_name" {
  description = "Storage bucket name for the client"
  value       = module.client_resources.client_bucket_name
}

output "client_raw_dataset_id" {
  description = "Raw BigQuery dataset ID for the client"
  value       = module.client_resources.raw_dataset_id
}

output "client_transformed_dataset_id" {
  description = "Transformed BigQuery dataset ID for the client"
  value       = module.client_resources.transformed_dataset_id
}

output "cloud_run_ingestion_job_name" {
  description = "Data ingestion Cloud Run job name"
  value       = module.cloud_run_jobs.data_ingestion_job_name
}

output "cloud_run_transformation_job_name" {
  description = "Data transformation Cloud Run job name"
  value       = module.cloud_run_jobs.data_transformation_job_name
}