# infrastructure/terraform/modules/connector_resources/outputs.tf
output "bucket_name" {
  description = "name of the connector storage bucket"
  value       = try(
    google_storage_bucket.connector_bucket[0].name,
    data.google_storage_bucket.existing_bucket.name
  )
}

output "ingestion_job_name" {
  description = "name of the ingestion cloud run job"
  value       = try(
    google_cloud_run_v2_job.ingestion_job[0].name,
    data.google_cloud_run_v2_job.existing_ingestion.name
  )
}

output "transformation_job_name" {
  description = "name of the transformation cloud run job"
  value       = try(
    google_cloud_run_v2_job.transformation_job[0].name,
    data.google_cloud_run_v2_job.existing_transformation.name
  )
}

output "scheduler_name" {
  description = "name of the cloud scheduler job"
  value       = local.scheduler_name
}