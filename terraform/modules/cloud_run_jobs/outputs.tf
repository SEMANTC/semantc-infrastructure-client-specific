output "data_ingestion_job_name" {
  value = google_cloud_run_v2_job.data_ingestion_job.name
}

output "data_transformation_job_name" {
  value = google_cloud_run_v2_job.data_transformation_job.name
}