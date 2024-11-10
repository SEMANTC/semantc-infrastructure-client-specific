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
  value       = local.transformation_job_name
}