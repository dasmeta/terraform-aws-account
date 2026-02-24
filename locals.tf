locals {
  sns_access_policy = {
    "Version" : "2012-10-17",
    "Id" : "__default_policy_ID",
    "Statement" : [
      # the default policy on topic, we pass it again with custom policy to not lose the default policy as custom policy overrides default
      {
        "Sid" : "__default_statement_ID",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ],
        "Resource" : "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceOwner" : "${data.aws_caller_identity.current.account_id}"
          }
        }
      },
      # allow budgets to publish to the sns topic, used for billing alerts
      {
        "Sid" : "AWSBudgets-notification-1",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "budgets.amazonaws.com"
        },
        "Action" : "SNS:Publish",
        "Resource" : "*"
      },
      # allow cloudwatch to publish to the sns topic
      {
        "Sid" : "CloudWatch-Alarms-Publish",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudwatch.amazonaws.com"
        },
        "Action" : [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ],
        "Resource" : "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}"
      },
      # allow event bridge to publish to the sns topic, needed for security hub findings rules
      {
        "Sid" : "AllowEventBridgePublish",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "events.amazonaws.com"
        },
        "Action" : "SNS:Publish",
        "Resource" : "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}"
      }
    ]
  }

  sns_access_policy_virginia = {
    "Version" : "2008-10-17",
    "Id" : "__default_policy_ID",
    "Statement" : [
      {
        "Sid" : "__default_statement_ID",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ],
        "Resource" : "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}-virginia",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceOwner" : "${data.aws_caller_identity.current.account_id}"
          }
        }
      },
      {
        "Sid" : "AWSBudgets-notification-1",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "budgets.amazonaws.com"
        },
        "Action" : "SNS:Publish",
        "Resource" : "*"
      },
      {
        "Sid" : "CloudWatch-Alarms-Publish",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudwatch.amazonaws.com"
        },
        "Action" : [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ],
        "Resource" : "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}-virginia"
      }
    ]
  }
}
