terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.3.0"
}

/**
 * set the following env vars so that aws provider will get authenticated before apply:

 export AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxxxxxx
 export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
*/
provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}


# set value with env variable `export TF_VAR_slack_webhook_url="https://hooks.slack.com/services/xyz/xyzop/xyzopqrst"` and `export TF_VAR_slack_channel_name="test-webhooks-channel"`
variable "slack_webhook_url" {
  type        = string
  description = "Slack webhook URL"
  default     = "https://hooks.slack.com/services/xyz/xyzop/xyzopqrst"
}

variable "slack_channel_name" {
  type        = string
  description = "Slack channel name"
  default     = "test-webhooks-channel"
}
