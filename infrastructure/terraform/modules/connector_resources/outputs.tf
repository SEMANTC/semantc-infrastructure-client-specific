# infrastructure/terraform/modules/connector_resources/outputs.tf
output "bucket_name" {
  description = "name of the connector storage bucket"
  value       = google_storage_bucket.connector_bucket.name
}

output "ingestion_job_name" {
  description = "name of the ingestion cloud run job"
  value       = google_cloud_run_v2_job.ingestion_job.name
}

output "transformation_job_name" {
  description = "name of the transformation cloud run job"
  value       = google_cloud_run_v2_job.transformation_job.name
}