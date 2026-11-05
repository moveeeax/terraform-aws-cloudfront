resource "aws_cloudfront_distribution" "this" {
  comment             = var.comment
  enabled             = var.enabled
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.aliases
  web_acl_id          = var.web_acl_id

  origin {
    domain_name = var.origin_domain_name
    origin_id   = var.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = var.origin_id
    viewer_protocol_policy = var.viewer_protocol_policy
    allowed_methods        = var.allowed_methods
    cached_methods         = var.cached_methods

    # Cache and origin request policies replace the deprecated
    # forwarded_values block.
    cache_policy_id          = var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id
  }

  dynamic "logging_config" {
    for_each = var.logging_config == null ? [] : [var.logging_config]

    content {
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
      include_cookies = logging_config.value.include_cookies
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # The CloudFront default certificate only covers *.cloudfront.net and pins the
  # viewer connection to a minimum of TLSv1. Serving `aliases` therefore requires
  # an ACM certificate, which is also what makes minimum_protocol_version settable.
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? null : var.minimum_protocol_version
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
      error_message = "acm_certificate_arn must be set when aliases are configured: the CloudFront default certificate cannot serve custom domain names."
    }

    precondition {
      condition     = length(setsubtract(var.cached_methods, var.allowed_methods)) == 0
      error_message = "cached_methods must be a subset of allowed_methods: CloudFront cannot cache a method it is not configured to process. Add the missing method(s) to allowed_methods, or remove them from cached_methods."
    }
  }
}
