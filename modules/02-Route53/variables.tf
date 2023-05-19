variable "domain_name" {
  type        = string
  description = "Public Domain name"
}
variable "tags" {
  description = "Tags"
  type        = map(string)
}

variable "private_domain" {
  type        = string
  description = "Private Domain name for private zone"
}

variable "vpc_id_private" {
  type        = string
  description = "VPC ID"
}
