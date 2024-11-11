# infrastructure/terraform/modules/connector_resources/outputs.tf
output "bucket_name" {
  description = "Name of the connector storage bucket"
  value       = data.google_storage_bucket.existing_bucket[0].name
}

output "ingestion_job_name" {
  description = "Name of the ingestion Cloud Run job"
  value       = data.google_cloud_run_v2_job.existing_ingestion[0].name
}

output "transformation_job_name" {
  description = "Name of the transformation Cloud Run job"
  value       = data.google_cloud_run_v2_job.existing_transform[0].name
}