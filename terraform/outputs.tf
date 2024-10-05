output "tenant_service_account_email" {
  description = "service account email for the tenant"
  value       = module.tenant_resources.tenant_sa_email
}

output "tenant_bucket_name" {
  description = "storage bucket name for the tenant"
  value       = module.tenant_resources.tenant_bucket_name
}

output "tenant_raw_dataset_id" {
  description = "raw bigquery dataset id for the tenant"
  value       = module.tenant_resources.raw_dataset_id
}

output "tenant_transformed_dataset_id" {
  description = "transformed bigquery dataset id for the tenant"
  value       = module.tenant_resources.transformed_dataset_id
}

output "cloud_run_ingestion_job_name" {
  description = "data ingestion cloud run job name"
  value       = module.cloud_run_jobs.data_ingestion_job_name
}

output "cloud_run_transformation_job_name" {
  description = "data transformation cloud run job name"
  value       = module.cloud_run_jobs.data_transformation_job_name
}