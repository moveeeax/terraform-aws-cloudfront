variable "comment" {
  description = "Comment describing the distribution."
  type        = string
  default     = "Managed by Terraform"
}

variable "enabled" {
  description = "Whether the distribution is enabled to accept traffic."
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "Object returned when a viewer requests the root URL."
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "Price class controlling which edge locations serve the distribution."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_class must be one of PriceClass_All, PriceClass_200 or PriceClass_100."
  }
}

variable "origin_domain_name" {
  description = "DNS domain name of the origin, for example an S3 bucket or custom host."
  type        = string
}

variable "origin_id" {
  description = "Unique identifier for the origin within the distribution."
  type        = string
  default     = "default-origin"
}

variable "viewer_protocol_policy" {
  description = "Protocol policy viewers must use to access content. Defaults to redirect-to-https so plain HTTP requests are never served."
  type        = string
  default     = "redirect-to-https"

  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be one of allow-all, https-only or redirect-to-https."
  }
}

variable "allowed_methods" {
  description = "HTTP methods CloudFront processes and forwards to the origin."
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "cached_methods" {
  description = "HTTP methods for which CloudFront caches responses."
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "aliases" {
  description = "Alternate domain names (CNAMEs) served by the distribution."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate in us-east-1 used to serve `aliases` over HTTPS. Required whenever `aliases` is non-empty; when null the CloudFront default certificate is used, which only covers the *.cloudfront.net domain name."
  type        = string
  default     = null
}

variable "minimum_protocol_version" {
  description = "Minimum TLS version viewers may negotiate. Only applies when `acm_certificate_arn` is set; the CloudFront default certificate always allows TLSv1."
  type        = string
  default     = "TLSv1.2_2021"

  validation {
    condition     = contains(["TLSv1.2_2018", "TLSv1.2_2019", "TLSv1.2_2021"], var.minimum_protocol_version)
    error_message = "minimum_protocol_version must be one of TLSv1.2_2018, TLSv1.2_2019 or TLSv1.2_2021. TLSv1 and TLSv1.1 are no longer considered secure."
  }
}

variable "logging_config" {
  description = "Standard access logging for the distribution. `bucket` is the bucket domain name, for example my-logs.s3.amazonaws.com. Set to null to disable logging."
  type = object({
    bucket          = string
    prefix          = optional(string, "")
    include_cookies = optional(bool, false)
  })
  default = null
}

variable "web_acl_id" {
  description = "ID or ARN of the WAF web ACL to associate with the distribution. Use the ARN for WAFv2 web ACLs, which must live in us-east-1. Null leaves the distribution unprotected by WAF."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the distribution."
  type        = map(string)
  default     = {}
}
