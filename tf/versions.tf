
terraform {
  required_version = ">= 0.12"

  backend "s3" {
    # bucket = "hello-pong-state-bucket"
    # key    = "eks/terraform.tfstate"
    region = "us-east-2"
  }
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}
