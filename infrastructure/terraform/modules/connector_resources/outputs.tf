# infrastructure/terraform/modules/connector_resources/outputs.tf
output "bucket_name" {
  description = "name of the connector storage bucket"
  value       = local.bucket_name
}

output "ingestion_job_name" {
  description = "name of the ingestion cloud run job"
  value       = local.ingestion_job_name
}

output "transformation_job_name" {
  description = "name of the transformation cloud run job"
  value       = try(
    data.google_cloud_run_v2_job.existing_transformation.name,
    google_cloud_run_v2_job.transformation_job[0].name
  )
}