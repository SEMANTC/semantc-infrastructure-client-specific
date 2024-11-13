# infrastructure/terraform/modules/user_id_helper/outputs.tf
output "service_account_id" {
  description = "service account id (6-30 chars, lowercase letters/numbers/hyphens, start with letter)"
  value       = local.service_account_id
}

output "raw_dataset_id" {
  description = "bigquery raw dataset id (letters/numbers/underscores, start with letter/underscore)"
  value       = local.raw_dataset_id
}

output "transformed_dataset_id" {
  description = "bigquery transformed dataset id (letters/numbers/underscores, start with letter/underscore)"
  value       = local.transformed_dataset_id
}

output "storage_prefix" {
  description = "storage bucket prefix (3-63 chars, lowercase letters/numbers/dots/hyphens, start/end with letter/number)"
  value       = local.storage_prefix
}

output "job_prefix" {
  description = "cloud run job prefix (letters/numbers/hyphens, start with letter)"
  value       = local.job_prefix
}

output "scheduler_prefix" {
  description = "cloud scheduler prefix (letters/numbers/underscores/hyphens, start with letter)"
  value       = local.scheduler_prefix
}