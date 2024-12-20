# infrastructure/terraform/modules/user_resources/variables.tf
variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "user_id" {
  description = "user id from firebase auth"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}