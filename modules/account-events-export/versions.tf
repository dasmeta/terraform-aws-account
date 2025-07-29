terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # configuration_aliases = [aws.second_region] # usually the account-events-export have need to collect also global/Virginia/us-east-1 region events like route53 and cloudwatch, so usually we have need for second region events collection, NOTE: the second region can be other than Virginia when we use this submodule in separate from account module
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
