# modules/bigquery_access/variables.tf
variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "user_id" {
  description = "firebase auth user id"
  type        = string
}

variable "service_account_email" {
  description = "email of the user's service account"
  type        = string
}