// This is to create a "honeypot". Anyone who accesses the honeypot is a crawler. Crawlers get 429'd for a week.

data "aws_iam_policy_document" "lambda_honeypot_service_role_sts" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_honeypot_service_role_cloudfront_kvs" {
  statement {
    effect = "Allow"

    actions   = ["cloudfront-keyvaluestore:*"]
    resources = [aws_cloudfront_key_value_store.lambda_honeypot.arn]
  }
}

resource "aws_iam_role" "lambda_honeypot_service_role" {
  name               = "${var.repository_name}_lambda_service_role_honeypot"
  assume_role_policy = data.aws_iam_policy_document.lambda_honeypot_service_role_sts.json
  inline_policy {
    name   = "CloudfrontKVSAccess"
    policy = data.aws_iam_policy_document.lambda_honeypot_service_role_cloudfront_kvs.json
  }
}

data "archive_file" "lambda_honeypot" {
  type        = "zip"
  output_path = "./honeypot.zip"

  source {
    content  = templatefile("${path.cwd}/lambda/honeypot.js", { kvs_arn = aws_cloudfront_key_value_store.lambda_honeypot.arn })
    filename = "index.js"
  }
}

resource "aws_lambda_function" "lambda_honeypot" {
  filename      = data.archive_file.lambda_honeypot.output_path
  function_name = "${var.repository_name}_honeypot"
  role          = aws_iam_role.lambda_honeypot_service_role.arn
  handler       = "index.handler"

  source_code_hash = data.archive_file.lambda_honeypot.output_base64sha256

  runtime = "nodejs20.x"

  publish = true

  provider = aws.us_east_1 // Must exist in this region
}
