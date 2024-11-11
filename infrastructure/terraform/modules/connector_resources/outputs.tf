output "bucket_name" {
  description = "Name of the connector storage bucket"
  value       = google_storage_bucket.connector_bucket.name
}

output "ingestion_job_name" {
  description = "Name of the ingestion Cloud Run job"
  value       = google_cloud_run_v2_job.ingestion_job.name
}

output "transformation_job_name" {
  description = "Name of the transformation Cloud Run job"
  value       = google_cloud_run_v2_job.transformation_job.name
}