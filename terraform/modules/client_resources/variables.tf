variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "new_client_id" {
  description = "Unique identifier for the new client"
  type        = string
}

variable "new_client_token" {
  description = "Token for the new client"
  type        = string
}

variable "master_sa_email" {
  description = "Email of the master service account"
  type        = string
}

variable "data_location" {
  description = "Location for data storage services"
  type        = string
}