variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "data_location" {
  description = "BigQuery Location"
  type        = string
}

variable "clients" {
  description = "list of Client IDs"
  type        = list(string)
}

variable "client_tokens" {
  description = "map of Client IDs to their respective tokens"
  type        = map(string)
}

variable "master_sa_email" {
  description = "email of the Master Service Account"
  type        = string
}

variable "terraform_sa_key_path" {
  description = "path to the Terraform service account JSON key file"
  type        = string
}