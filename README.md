# terraform-aws-cloudfront

Terraform module that manages an [Amazon
CloudFront](https://aws.amazon.com/cloudfront/) distribution. It creates a
single distribution in front of a custom origin with sensible caching and
HTTPS defaults, exposing the distribution domain name for DNS aliasing.

Defaults are chosen to be safe: viewers are redirected to HTTPS, CloudFront
reaches the origin over `https-only` with TLSv1.2, and a custom certificate
negotiates `TLSv1.2_2021` or better.

## Usage

```hcl
module "cloudfront" {
  source = "github.com/moveeeax/terraform-aws-cloudfront"

  origin_domain_name = "assets.example.com"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Custom domain, access logs and WAF

```hcl
module "cloudfront" {
  source = "github.com/moveeeax/terraform-aws-cloudfront"

  origin_domain_name = "assets.example.com"

  # aliases require an ACM certificate in us-east-1 — the CloudFront default
  # certificate only covers *.cloudfront.net.
  aliases             = ["cdn.example.com"]
  acm_certificate_arn = aws_acm_certificate.cdn.arn

  logging_config = {
    bucket = aws_s3_bucket.logs.bucket_domain_name
    prefix = "cloudfront/"
  }

  web_acl_id = aws_wafv2_web_acl.cdn.arn

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.0   |

## Inputs

| Name                     | Description                                             | Type           | Default                | Required |
|--------------------------|---------------------------------------------------------|----------------|------------------------|:--------:|
| `comment`                | Comment describing the distribution.                    | `string`       | `"Managed by Terraform"` | no     |
| `enabled`                | Whether the distribution accepts traffic.               | `bool`         | `true`                 |    no    |
| `default_root_object`    | Object returned for the root URL.                       | `string`       | `"index.html"`         |    no    |
| `price_class`            | Price class controlling edge locations.                 | `string`       | `"PriceClass_100"`     |    no    |
| `origin_domain_name`     | DNS domain name of the origin.                          | `string`       | n/a                    |   yes    |
| `origin_id`              | Unique identifier for the origin.                       | `string`       | `"default-origin"`     |    no    |
| `viewer_protocol_policy` | Protocol policy viewers must use.                       | `string`       | `"redirect-to-https"`  |    no    |
| `allowed_methods`        | HTTP methods CloudFront processes.                      | `list(string)` | `["GET", "HEAD"]`      |    no    |
| `cached_methods`         | HTTP methods CloudFront caches.                         | `list(string)` | `["GET", "HEAD"]`      |    no    |
| `aliases`                | Alternate domain names served. Requires `acm_certificate_arn`. | `list(string)` | `[]`            |    no    |
| `acm_certificate_arn`    | ACM certificate (us-east-1) used to serve `aliases`.    | `string`       | `null`                 |    no    |
| `minimum_protocol_version` | Minimum TLS version viewers may negotiate. Applies only with `acm_certificate_arn`. | `string` | `"TLSv1.2_2021"` | no |
| `logging_config`         | Standard access logging: `bucket`, `prefix`, `include_cookies`. | `object`  | `null`                 |    no    |
| `web_acl_id`             | WAF web ACL to associate (ARN for WAFv2, us-east-1).    | `string`       | `null`                 |    no    |
| `tags`                   | Tags applied to the distribution.                       | `map(string)`  | `{}`                   |    no    |

## Outputs

| Name             | Description                                        |
|------------------|----------------------------------------------------|
| `id`             | ID of the distribution.                            |
| `arn`            | ARN of the distribution.                           |
| `domain_name`    | Domain name assigned to the distribution.          |
| `hosted_zone_id` | Route 53 hosted zone ID for aliasing.              |
| `status`         | Current status of the distribution.                |

## Tests

The module ships a `terraform test` suite backed by a mocked AWS provider, so it
runs with no credentials and no network:

```sh
terraform init -backend=false
terraform test
```

`mock_provider` requires Terraform (or OpenTofu) >= 1.7 — a test-only
requirement; the module itself still supports >= 1.5.

## License

[MIT](LICENSE)
