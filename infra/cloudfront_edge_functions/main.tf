// Many resources need to exist in us-east-1, even if it's different from your typical region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
