# infrastructure/terraform/modules/bigquery_access/main.tf
module "user_id" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

# CREATE USER-SPECIFIC AUTHORIZED VIEWS
resource "google_bigquery_dataset" "user_views" {
  dataset_id    = "${module.user_id.bigquery_name}_views"
  friendly_name = "views for user ${var.user_id}"
  description   = "contains authorized views to user's tables"
  location      = "US"
  project       = var.project_id
}

# CREATE VIEW FOR RAW DATA
resource "google_bigquery_table" "raw_data_view" {
  dataset_id = google_bigquery_dataset.user_views.dataset_id
  table_id   = "raw_data_view"
  project    = var.project_id
  deletion_protection = false

  view {
    query = <<EOF
    SELECT * 
    FROM (
      SELECT *
      FROM `${var.project_id}.raw_data.INFORMATION_SCHEMA.TABLES`
      WHERE table_name LIKE '${module.user_id.bigquery_name}_%'
      LIMIT 0
    )
    EOF
    use_legacy_sql = false
  }
}

# CREATE VIEW FOR TRANSFORMED DATA
resource "google_bigquery_table" "transformed_data_view" {
  dataset_id = google_bigquery_dataset.user_views.dataset_id
  table_id   = "transformed_data_view"
  project    = var.project_id
  deletion_protection = false

  view {
    query = <<EOF
    SELECT * 
    FROM (
      SELECT *
      FROM `${var.project_id}.transformed_data.INFORMATION_SCHEMA.TABLES`
      WHERE table_name LIKE '${module.user_id.bigquery_name}_%'
      LIMIT 0
    )
    EOF
    use_legacy_sql = false
  }
}

# GRANT USER'S SERVICE ACCOUNT ACCESS TO THE VIEWS ONLY
resource "google_bigquery_dataset_iam_member" "user_views_access" {
  dataset_id = google_bigquery_dataset.user_views.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.service_account_email}"
}

# GRANT ACCESS TO SOURCE DATASETS
resource "google_bigquery_dataset_iam_member" "raw_data_access" {
  dataset_id = "raw_data"
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.service_account_email}"
}

resource "google_bigquery_dataset_iam_member" "transformed_data_access" {
  dataset_id = "transformed_data"
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.service_account_email}"
}