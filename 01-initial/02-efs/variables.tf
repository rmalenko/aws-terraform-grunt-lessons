# variable "launch_conf" {
#   type = map(string)
# }

variable "instances_number" {
  description = "NUmber of instances"
  type        = number
  default     = 1
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_name" {
  type = string
}

variable "profile" {
  type = string
}

variable "s3_key_dir" {
  type = string
}

# None — Prevents the instances from launching into a Capacity Reservation. The instances run in On-Demand capacity.
# Open — Launches the instances into any Capacity Reservation that has matching attributes and sufficient capacity for the number of instances you selected. If there is no matching Capacity Reservation with sufficient capacity, the instance uses On-Demand capacity.
variable "capacity_reservation_preference" {
  description = "Launch instances into an existing Capacity Reservation"
  type        = string
  default     = "none"
}

# Target by ID — Launches the instances into the selected Capacity Reservation. If the selected Capacity Reservation does not have sufficient capacity for the number of instances you selected, the instance launch fails.
# Target by group — Launches the instances into any Capacity Reservation with matching attributes and available capacity in the selected Capacity Reservation group. If the selected group does not have a Capacity Reservation with matching attributes and available capacity, the instances launch into On-Demand capacity.


variable "ec2_tags" {
  default = {
    environment = "opsrnd"
    name        = "Test instance"
    managedby   = "Terraform"
  }
  description = "Additional resource tags"
  type        = map(string)
}

// Load Balancers IDs
// https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html
// The following table contains the account IDs to use in place of elb-account-id in your bucket policy.
// us-east-1 changed to us_east_1 to avoid a possible conflict

variable "us_east_1" {
  description = "US East (N. Virginia)"
  type        = string
  default     = 127311923021
}

variable "us_east_2" {
  description = "US East (Ohio)US East (Ohio)"
  type        = string
  default     = 033677994240
}

variable "us_west_1" {
  description = "US West (N. California)"
  type        = string
  default     = 027434742980
}

variable "us_west_2" {
  description = "US West (Oregon)"
  type        = string
  default     = 797873946194
}

variable "af_south_1" {
  description = "Africa (Cape Town)"
  type        = string
  default     = 098369216593
}

variable "ca_central_1" {
  description = "Canada (Central)"
  type        = string
  default     = 985666609251
}

variable "eu_central_1" {
  description = "Europe (Frankfurt)"
  type        = string
  default     = 054676820928
}

variable "eu_west_1" {
  description = "Europe (Ireland)"
  type        = string
  default     = 156460612806
}

variable "eu_west_2" {
  description = "Europe (London)"
  type        = string
  default     = 652711504416
}

variable "eu_south_1" {
  description = "Europe (Milan)"
  type        = string
  default     = 635631232127
}

variable "eu_west_3" {
  description = "Europe (Paris)"
  type        = string
  default     = 009996457667
}

variable "eu_north_1" {
  description = "Europe (Stockholm)"
  type        = string
  default     = 897822967062
}

variable "ap_east_1" {
  description = "Asia Pacific (Hong Kong)"
  type        = string
  default     = 754344448648
}

variable "ap_northeast_1" {
  description = "Asia Pacific (Tokyo)"
  type        = string
  default     = 582318560864
}

variable "ap_northeast_2" {
  description = "Asia Pacific (Seoul)"
  type        = string
  default     = "600734575887"
}

variable "ap_northeast_3" {
  description = "Asia Pacific (Osaka)"
  type        = string
  default     = 383597477331
}

variable "ap_southeast_1" {
  description = "Asia Pacific (Singapore)"
  type        = string
  default     = 114774131450
}

variable "ap_southeast_2" {
  description = "Asia Pacific (Sydney)"
  type        = string
  default     = 783225319266
}

variable "ap_south_1" {
  description = "Asia Pacific (Mumbai)"
  type        = string
  default     = 718504428378
}

variable "me_south_1" {
  description = "Middle East (Bahrain)"
  type        = string
  default     = 076674570225
}

variable "sa_east_1" {
  description = "South America (São Paulo)"
  type        = string
  default     = 507241528517
}
