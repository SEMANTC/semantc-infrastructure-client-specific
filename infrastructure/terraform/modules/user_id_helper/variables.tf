# infrastructure/terraform/modules/user_id_helper/variables.tf
variable "user_id" {
  description = "original user id to be standardized"
  type        = string
}