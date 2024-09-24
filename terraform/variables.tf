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
  default     = "US"
}

variable "clients" {
  description = "List of client IDs"
  type        = list(string)
}