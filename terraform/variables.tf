
variable "hostname" {
  description = "The custom hostname for the SFTP server"
  type        = string
  default     = "sftp.example.com"
}

variable "route53_zone_name" {
  description = "The name of the Route 53 hosted zone"
  type        = string
  default     = "example.com"
}

variable "sftp_users" {
  description = "A map of users to be created"
  type = map(object({
    bucket_name    = string
    home_directory = string
    ssh_key        = string
  }))
  default = {}
}