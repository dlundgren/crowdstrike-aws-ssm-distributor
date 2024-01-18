variable "aws_resources_prefix" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "share_with_account_ids" {
  type    = list(string)
  default = []
}