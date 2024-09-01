// Many resources need to exist in us-east-1, even if it's different from your typical region

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.48.0"
      configuration_aliases = [ aws, aws.us_east_1 ]
    }
  }
}
