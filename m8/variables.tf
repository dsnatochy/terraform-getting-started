#### VARIABLES #########
# Not needed if credentials are passed as env variables
# variable "aws_access_key" {}
# variable "aws_secret_key" {}
variable "AWS_ACCESS_KEY_ID" {
  type = string
}
variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "us-east-1"
}
variable "network_address_space" {
  type = map(string)
}

variable "instance_size" {
  type = map(string)
}

variable "subnet_count" {
  type = map(number)
}
variable "instance_count" {
  type = map(number)
}

# variable "subnet1_address_space" {
#   default = "10.1.0.0/24"
# }

# variable "subnet2_address_space" {
#   default = "10.1.1.0/24"
# }

variable "bucket_name_prefix" {}
variable "billing_code_tag" {}
variable "environment_tag" {}

variable "arm_subscription_id" {}
variable "arm_principal" {}
variable "arm_password" {}
variable "tenant_id" {}
variable "dns_zone_name" {}
variable "dns_resource_group" {}


# variable "cidr" {
#   type = map(string)
#   default = {
#     development = "10.0.0.0/16"
#     uat = "10.1.0.0/16"
#     production = "10.2.0.0/16"
#   }
# }

####### LOCALS ###############
locals {
  env_name = lower(terraform.workspace)  # "default" by default
  common_tags = {
    BillingCode = var.billing_code_tag
    Environment = local.env_name
  }

  s3_bucket_name = "${var.bucket_name_prefix}-${local.env_name}-${random_integer.rand.result}"
}