variable "client_id" {
  description = "unique identifier for the client"
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
  description = "email of the master Service Account"
  type        = string
}

variable "image_ingestion" {
  description = "container image for the data ingestion job"
  type        = string
}

variable "image_transformation" {
  description = "container image for the data transformation job"
  type        = string
}