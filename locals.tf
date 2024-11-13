locals {
  sns_access_policy = {
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
        "Resource" : "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}",
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
        "Resource" : "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.alarm_actions.topic_name}"
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
