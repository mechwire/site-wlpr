resource "aws_dynamodb_table" "wlpr_honeypot" {
  name           = "wlpr_crawler"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "IpAddress"
  range_key      = "TimeCreated"

  attribute {
    name = "IpAddress"
    type = "S"
  }

  attribute {
    name = "TimeCreated"
    type = "S"
  }

  attribute {
    name = "TimeToExist"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }
}
