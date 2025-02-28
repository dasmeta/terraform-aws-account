terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws, aws.virginia]
      version               = "~> 5.0"
    }
  }
}
