variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

variable "new_tenant_id" {
  description = "unique identifier for the new tenant"
  type        = string
}

variable "master_sa_email" {
  description = "email of the master service account"
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