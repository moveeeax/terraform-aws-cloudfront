# Test-only requirement: `mock_provider` needs Terraform >= 1.7 (or OpenTofu >= 1.7).
# The module itself still supports the required_version declared in versions.tf.
mock_provider "aws" {}

variables {
  origin_domain_name = "assets.example.com"
}

run "defaults_are_secure" {
  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).viewer_protocol_policy == "redirect-to-https"
    error_message = "Viewers must be redirected to HTTPS by default, never served over plain HTTP."
  }

  assert {
    condition     = one(one(aws_cloudfront_distribution.this.origin).custom_origin_config).origin_protocol_policy == "https-only"
    error_message = "CloudFront must talk to the origin over HTTPS only."
  }

  assert {
    condition     = one(one(aws_cloudfront_distribution.this.origin).custom_origin_config).origin_ssl_protocols == toset(["TLSv1.2"])
    error_message = "The origin connection must be pinned to TLSv1.2."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).cloudfront_default_certificate == true
    error_message = "Without an ACM certificate the distribution must fall back to the CloudFront default certificate."
  }
}

run "acm_certificate_pins_modern_tls" {
  variables {
    aliases             = ["cdn.example.com"]
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).minimum_protocol_version == "TLSv1.2_2021"
    error_message = "Custom certificates must negotiate TLSv1.2_2021 or better; TLSv1 and TLSv1.1 are dead."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).ssl_support_method == "sni-only"
    error_message = "Custom certificates must be served with SNI rather than a dedicated IP."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).cloudfront_default_certificate == false
    error_message = "The default certificate must be disabled once an ACM certificate is supplied."
  }
}

run "aliases_without_certificate_are_rejected" {
  # The guard is a resource precondition, so it trips during plan.
  command = plan

  variables {
    aliases = ["cdn.example.com"]
  }

  expect_failures = [aws_cloudfront_distribution.this]
}

run "logging_and_waf_are_wired_through" {
  variables {
    web_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/example/00000000-0000-0000-0000-000000000000"
    logging_config = {
      bucket = "example-logs.s3.amazonaws.com"
      prefix = "cloudfront/"
    }
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.logging_config).bucket == "example-logs.s3.amazonaws.com"
    error_message = "Access logging must be configured when logging_config is supplied."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.logging_config).include_cookies == false
    error_message = "Access logs must not include cookies unless explicitly requested."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.web_acl_id == var.web_acl_id
    error_message = "The distribution must be associated with the supplied WAF web ACL."
  }
}

run "logging_is_absent_by_default" {
  assert {
    condition     = length(aws_cloudfront_distribution.this.logging_config) == 0
    error_message = "No logging_config block should be emitted when logging_config is null."
  }
}

run "rejects_insecure_minimum_protocol_version" {
  # Variable validation trips during plan.
  command = plan

  variables {
    minimum_protocol_version = "TLSv1.1_2016"
  }

  expect_failures = [var.minimum_protocol_version]
}

run "rejects_invalid_viewer_protocol_policy" {
  # Variable validation trips during plan.
  command = plan

  variables {
    viewer_protocol_policy = "https-onlyy"
  }

  expect_failures = [var.viewer_protocol_policy]
}

run "rejects_invalid_price_class" {
  # Variable validation trips during plan.
  command = plan

  variables {
    price_class = "PriceClass_50"
  }

  expect_failures = [var.price_class]
}
