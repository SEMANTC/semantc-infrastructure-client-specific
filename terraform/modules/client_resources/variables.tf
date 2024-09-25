variable "client_id" {
  description = "Unique identifier for the client"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "data_location" {
  description = "Location for BigQuery datasets"
  type        = string
}

variable "client_token" {
  description = "Token for the client (e.g., Xero API token)"
  type        = string
}

variable "master_sa_email" {
  description = "email of the master service account"
  type        = string
}