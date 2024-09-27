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

variable "master_sa_email" {
  description = "Email of the master service account"
  type        = string
}

variable "image_ingestion" {
  description = "Container image for the data ingestion job"
  type        = string
}

variable "image_transformation" {
  description = "Container image for the data transformation job"
  type        = string
}