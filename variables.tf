variable "zone_id" {
  type        = string
  description = "An ID of the root Route53 zone for creating sub-domains"
}

variable "domain" {
  type        = string
  description = "A domain for mapping"
}

variable "cluster_name" {
  type        = string
  description = "A name of the cluster"
}

variable "tags" {
  type        = map(string)
  description = "A set of tags"
  default     = {}
}

variable "invite_template" {
  type        = map(string)
  description = "A template for the invite email with credentials"
  default = {
    email_message = <<EOT
Your Swiss Army Kube username is {username} and temporary password is {####}.
EOT
    email_subject = "Your Swiss Army Kube temporary password"
    sms_message   = "Your Swiss Army Kube username is {username} and temporary password is {####}"
  }
}


variable "enable_cloudtrail_logging" {
  type        = bool
  description = "Enable cloudtrail by changing this to true"
  default     = false
}
