# infrastructure/terraform/modules/bigquery_access/outputs.tf
output "user_views_dataset" {
  description = "the id of the user's views dataset"
  value       = google_bigquery_dataset.user_views.dataset_id
}

output "raw_data_view_id" {
  description = "the id of the user's raw data view"
  value       = google_bigquery_table.raw_data_view.table_id
}

output "transformed_data_view_id" {
  description = "the id of the user's transformed data view"
  value       = google_bigquery_table.transformed_data_view.table_id
}