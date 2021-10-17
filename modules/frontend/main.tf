data "aws_region" "current" {
}

resource "aws_s3_bucket" "bucket" {
  force_destroy = "true"
}

locals {
  # Maps file extensions to mime types
  # Need to add more if needed
  mime_type_mappings = {
    html = "text/html",
    js   = "text/javascript",
    mjs  = "text/javascript",
    css  = "text/css"
  }
}

resource "aws_s3_bucket_object" "frontend_object" {
  for_each = fileset("${path.module}/assets", "*")
  key      = each.value
  source   = "${path.module}/assets/${each.value}"
  bucket   = aws_s3_bucket.bucket.bucket

  etag          = filemd5("${path.module}/assets/${each.value}")
  content_type  = local.mime_type_mappings[concat(regexall("\\.([^\\.]*)$", each.value), [[""]])[0][0]]
  cache_control = "no-store, max-age=0"
}

resource "aws_s3_bucket_object" "frontend_config" {
  key     = "config.js"
  content = <<EOF
export const cognitoUserPoolId = "${var.cognito_user_pool_id}";
export const cognitoClientId = "${var.cognito_client_id}";
export const backendUrl = "${var.backend_url}"
export const region = "${data.aws_region.current.name}"
EOF
  bucket  = aws_s3_bucket.bucket.bucket

  content_type  = "text/javascript"
  cache_control = "no-store, max-age=0"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "s3"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.OAI.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "OAI_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.OAI.iam_arn]
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "OAI" {
}
