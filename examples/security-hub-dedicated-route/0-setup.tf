terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

variable "security_slack_webhook_url" {
  type        = string
  sensitive   = true
  description = "Incoming Slack webhook bound to the owned security-alerts channel"
}

variable "on_call_webhook_url" {
  type        = string
  sensitive   = true
  description = "Existing incident-management webhook for finding acknowledgement"
}

variable "delivery_failure_topic_arn" {
  type        = string
  description = "Existing separate SNS escalation topic in this account and Region"
}

variable "delivery_failure_runbook_url" {
  type        = string
  description = "HTTPS drain and replay procedure for failed finding delivery"
}

variable "security_owner" {
  type        = string
  description = "Team accountable for Security Hub findings and delivery failures"
}
