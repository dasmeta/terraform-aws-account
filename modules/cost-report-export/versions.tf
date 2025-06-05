terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # configuration_aliases = [aws.virginia] # the cost reports service is global and only available in us-east-1 currently
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
