output "service_account_id" {
  description = "Service account ID (6-30 chars, lowercase letters/numbers/hyphens, start with letter)"
  value       = local.service_account_id
}

output "raw_dataset_id" {
  description = "BigQuery raw dataset ID (letters/numbers/underscores, start with letter/underscore)"
  value       = local.raw_dataset_id
}

output "transformed_dataset_id" {
  description = "BigQuery transformed dataset ID (letters/numbers/underscores, start with letter/underscore)"
  value       = local.transformed_dataset_id
}

output "storage_prefix" {
  description = "Storage bucket prefix (3-63 chars, lowercase letters/numbers/dots/hyphens, start/end with letter/number)"
  value       = local.storage_prefix
}

output "job_prefix" {
  description = "Cloud Run job prefix (letters/numbers/hyphens, start with letter)"
  value       = local.job_prefix
}

output "scheduler_prefix" {
  description = "Cloud Scheduler prefix (letters/numbers/underscores/hyphens, start with letter)"
  value       = local.scheduler_prefix
}