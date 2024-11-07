# modules/bigquery_access/variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "user_id" {
  description = "Firebase Auth user ID"
  type        = string
}

variable "service_account_email" {
  description = "Email of the user's service account"
  type        = string
}