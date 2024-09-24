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

variable "service_account_email" {
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