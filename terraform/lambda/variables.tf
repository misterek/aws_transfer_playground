
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

# Unlike the other example, exclude the ssh key.  That's the responsibility of the labmda function.
variable "sftp_users" {
  description = "A map of users to be created"
  type = map(object({
    bucket_name    = string
    home_directory = string
  }))
  default = {}
}
