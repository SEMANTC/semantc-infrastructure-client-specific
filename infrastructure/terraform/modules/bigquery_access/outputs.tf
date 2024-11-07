# modules/bigquery_access/outputs.tf
output "raw_dataset_access" {
  description = "IAM binding for raw dataset access"
  value       = google_bigquery_dataset_iam_member.raw_data_access.role
}

output "transformed_dataset_access" {
  description = "IAM binding for transformed dataset access"
  value       = google_bigquery_dataset_iam_member.transformed_data_access.role
}