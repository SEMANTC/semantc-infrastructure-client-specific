# modules/bigquery_access/main.tf
# GRANT ACCESS TO RAW DATASET TABLES
resource "google_bigquery_dataset_iam_member" "raw_data_access" {
  project    = var.project_id
  dataset_id = "raw_data"
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.service_account_email}"

  condition {
    title       = "user_tables_access"
    description = "access to tables starting with user id"
    expression  = "resource.name.extract(\"projects/${var.project_id}/datasets/raw_data/tables/(.+)\").matches(\"^${var.user_id}__.*\")"
  }
}

# GRANT ACCESS TO TRANSFORMED DATASET TABLES
resource "google_bigquery_dataset_iam_member" "transformed_data_access" {
  project    = var.project_id
  dataset_id = "transformed_data"
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.service_account_email}"

  condition {
    title       = "user_tables_access"
    description = "access to tables starting with user id"
    expression  = "resource.name.extract(\"projects/${var.project_id}/datasets/transformed_data/tables/(.+)\").matches(\"^${var.user_id}__.*\")"
  }
}