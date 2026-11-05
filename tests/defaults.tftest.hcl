# Test-only requirement: `mock_provider` needs Terraform >= 1.7 (or OpenTofu >= 1.7).
# The module itself still supports the required_version declared in versions.tf.
mock_provider "aws" {}

variables {
  origin_domain_name = "assets.example.com"
}

run "defaults_are_secure" {
  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).cache_policy_id == "658327ea-f89d-4fab-a63d-7e88639e58f6"
    error_message = "The default cache behavior must use the managed CachingOptimized cache policy instead of the deprecated forwarded_values."
  }

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

run "rejects_invalid_allowed_methods" {
  # Variable validation trips during plan.
  command = plan

  variables {
    allowed_methods = ["GET", "HEAD", "TRACE"]
  }

  expect_failures = [var.allowed_methods]
}

run "rejects_invalid_cached_methods" {
  # Variable validation trips during plan.
  command = plan

  variables {
    cached_methods = ["GET", "HEAD", "OPTIONS", "PUT"]
  }

  expect_failures = [var.cached_methods]
}

run "rejects_cached_methods_not_subset_of_allowed_methods" {
  # Both values are individually valid combinations, but CloudFront cannot
  # cache a method it isn't configured to process. The guard is a resource
  # precondition, so it trips during plan.
  command = plan

  variables {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
  }

  expect_failures = [aws_cloudfront_distribution.this]
}

run "accepts_cached_methods_that_are_a_strict_subset" {
  variables {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).cached_methods == toset(["GET", "HEAD"])
    error_message = "cached_methods must be honored when it is a proper subset of a wider allowed_methods."
  }
}

run "rejects_empty_origin_domain_name" {
  # Variable validation trips during plan.
  command = plan

  variables {
    origin_domain_name = "   "
  }

  expect_failures = [var.origin_domain_name]
}

run "rejects_empty_origin_id" {
  # Variable validation trips during plan.
  command = plan

  variables {
    origin_id = ""
  }

  expect_failures = [var.origin_id]
}

run "all_optional_features_combined" {
  # Round-1 tests exercised aliases+cert and logging+WAF as separate pairs.
  # A real consumer turning on every optional feature at once is the
  # combination most likely to expose an interaction bug between them.
  variables {
    aliases                  = ["cdn.example.com"]
    acm_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    minimum_protocol_version = "TLSv1.2_2018"
    web_acl_id               = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/example/00000000-0000-0000-0000-000000000000"
    logging_config = {
      bucket          = "example-logs.s3.amazonaws.com"
      prefix          = "cloudfront/"
      include_cookies = true
    }
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).minimum_protocol_version == "TLSv1.2_2018"
    error_message = "The non-default minimum_protocol_version must still be honored when combined with logging and WAF."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.logging_config).include_cookies == true
    error_message = "include_cookies must be honored when combined with aliases and a WAF web ACL."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.web_acl_id == var.web_acl_id
    error_message = "web_acl_id must be honored when combined with aliases and logging."
  }
}

run "creates_without_aliases" {
  # First half of an update-in-place scenario: stand up the distribution
  # with its defaults, matching a first `terraform apply` in the field.
  command = apply
}

run "adds_alias_and_certificate_in_place" {
  # Second half: an existing distribution gaining a custom domain and
  # certificate later, the way a real consumer would evolve their config.
  # This reuses the state produced by "creates_without_aliases" above, so it
  # exercises the update path rather than a fresh create.
  command = apply

  variables {
    aliases             = ["cdn.example.com"]
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).cloudfront_default_certificate == false
    error_message = "Updating an existing distribution to add aliases must switch it off the default certificate."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.aliases == toset(["cdn.example.com"])
    error_message = "Updating an existing distribution must apply the new alias."
  }
}

run "custom_cache_and_origin_request_policies" {
  variables {
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).cache_policy_id == "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    error_message = "cache_policy_id must be passed through to the default cache behavior."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).origin_request_policy_id == "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
    error_message = "origin_request_policy_id must be passed through to the default cache behavior."
  }
}

run "blank_origin_request_policy_is_rejected" {
  command = plan

  variables {
    origin_request_policy_id = "  "
  }

  expect_failures = [var.origin_request_policy_id]
}

