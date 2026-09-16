#!/usr/bin/env python3
"""Check real nested Terraform module plans and mocked IAM wiring."""

import json
import subprocess
from pathlib import Path


MODULE_ROOT = Path(__file__).resolve().parents[1]
SECRET_ARN = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
ACTION_ARN = "arn:aws:sns:eu-central-1:111122223333:example-kpi-alarms"
LAMBDA_POLICY_ID = "mock-lambda-kpi-additional"
SCHEDULER_POLICY_ID = "mock-scheduler-kpi-additional"


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def resources_of_type(resources, resource_type):
    return [resource for resource in resources if resource.get("mode") == "managed" and resource["type"] == resource_type]


def single(resources, resource_type):
    selected = resources_of_type(resources, resource_type)
    require(len(selected) == 1, "Expected exactly one {} resource, found {}".format(resource_type, len(selected)))
    return selected[0]


def check_plan(plan):
    resources = plan["resource_changes"]
    function = single(resources, "aws_lambda_function")["change"]["after"]
    require(function["reserved_concurrent_executions"] == 1, "Lambda reserved concurrency drifted")
    require(function["handler"] == "handler.lambda_handler" and function["runtime"] == "python3.13", "Lambda entry point drifted")
    require(function["timeout"] == 600 and function["memory_size"] == 256, "Lambda runtime bounds drifted")
    require(function["publish"] is False and function["filename"].endswith("account-kpi-export-lambda.zip"), "Lambda package wiring drifted")
    require(all(vpc["subnet_ids"] == [] and vpc["security_group_ids"] == [] for vpc in function["vpc_config"]), "The collector must remain outside a VPC")
    environment = function["environment"][0]["variables"]
    require(set(environment) == {"CONFIG_JSON", "SECRET_ARN"} and environment["SECRET_ARN"] == SECRET_ARN, "Lambda environment or secret reference drifted")
    config = json.loads(environment["CONFIG_JSON"])
    require(set(config) == {"timezone", "cloudbrowser", "application", "cost", "security", "metrics"}, "CONFIG_JSON groups drifted")
    require(config["timezone"] == "Asia/Yerevan" and config["cloudbrowser"] == {
        "base_url": "https://app.dasmeta.com", "client_id": 42, "aws_provider_id": 1, "token_key": "cloudbrowser_api_token"
    }, "CloudBrowser runtime configuration drifted")
    require(config["application"] == {
        "enabled": True, "grafana_url": "https://grafana.example.com", "datasource_uid": "example-prometheus",
        "uptime_query": "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)",
        "latency_query": "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)",
        "token_key": "grafana_api_token"
    }, "Application runtime configuration drifted")
    require(config["cost"] == {"enabled": True} and config["security"] == {"enabled": True, "region": "eu-central-1"}, "AWS source runtime configuration drifted")
    require(config["metrics"] == {"cost": 12, "security": 4, "uptime": 24, "latency": 26}, "Metric runtime configuration drifted")

    queue = single(resources, "aws_sqs_queue")["change"]["after"]
    require(queue["sqs_managed_sse_enabled"] is True and queue["kms_master_key_id"] is None, "Failure queue encryption drifted")

    asynchronous = single(resources, "aws_lambda_function_event_invoke_config")
    async_values = asynchronous["change"]["after"]
    require(asynchronous["index"] == "unqualified_alias" and async_values["qualifier"] is None, "Lambda async configuration must be unqualified only")
    require(async_values["function_name"] == function["function_name"], "Lambda async configuration targets another function")
    require(async_values["maximum_event_age_in_seconds"] == 21600 and async_values["maximum_retry_attempts"] == 2, "Lambda async retry drifted")
    require(async_values["destination_config"][0]["on_failure"][0]["destination"] == queue["arn"], "Lambda async failure destination drifted")

    schedules = resources_of_type(resources, "aws_scheduler_schedule")
    require(len(schedules) == 2, "Application plus AWS collection must plan exactly two schedules")
    by_name = {resource["change"]["after"]["name"]: resource["change"]["after"] for resource in schedules}
    require(set(by_name) == {"account-kpi-export-monday", "account-kpi-export-wednesday"}, "Weekly schedule names drifted")
    for day, job in (("monday", "application"), ("wednesday", "aws")):
        schedule = by_name["account-kpi-export-" + day]
        target = schedule["target"][0]
        require(target["arn"] == function["arn"] and json.loads(target["input"]) == {"job": job}, "Weekly schedule target or literal payload drifted")
        require(schedule["schedule_expression_timezone"] == "Asia/Yerevan", "Scheduler timezone drifted")
        require(schedule["schedule_expression"] == "cron(0 6 ? * {} *)".format("MON" if day == "monday" else "WED"), "Weekly schedule expression drifted")
        require(target["retry_policy"] == [{"maximum_event_age_in_seconds": 86400, "maximum_retry_attempts": 2}], "Scheduler delivery retry drifted")
        require(target["dead_letter_config"] == [{"arn": queue["arn"]}], "Scheduler delivery DLQ drifted")

    alarms = resources_of_type(resources, "aws_cloudwatch_metric_alarm")
    require(len(alarms) == 2, "Expected exactly two operational alarms")
    by_metric = {resource["change"]["after"]["metric_name"]: resource["change"]["after"] for resource in alarms}
    require(set(by_metric) == {"Errors", "ApproximateNumberOfMessagesVisible"}, "Alarm metrics drifted")
    for alarm in by_metric.values():
        require(alarm["alarm_actions"] == [ACTION_ARN] and alarm["actions_enabled"] is True, "Alarm notification actions drifted")
        require(alarm["threshold"] == 0 and alarm["treat_missing_data"] == "notBreaching", "Alarm failure threshold drifted")
    require(by_metric["Errors"]["namespace"] == "AWS/Lambda" and by_metric["Errors"]["dimensions"] == {"FunctionName": function["function_name"]}, "Lambda error alarm wiring drifted")
    require(by_metric["ApproximateNumberOfMessagesVisible"]["namespace"] == "AWS/SQS" and by_metric["ApproximateNumberOfMessagesVisible"]["dimensions"] == {"QueueName": queue["name"]}, "Failure queue alarm wiring drifted")

    indexed = {resource["address"]: resource["change"]["after"] for resource in resources}
    lambda_policy = indexed["module.lambda_function.aws_iam_role_policy.additional_inline[0]"]
    require(lambda_policy["role"] == function["function_name"] and json.loads(lambda_policy["policy"])["Id"] == LAMBDA_POLICY_ID, "Lambda custom statement document is not attached to the collector role")
    scheduler_policy = indexed["module.scheduler.aws_iam_policy.additional_inline[0]"]
    require(json.loads(scheduler_policy["policy"])["Id"] == SCHEDULER_POLICY_ID, "Scheduler custom statement document is not attached")
    scheduler_attachment = indexed["module.scheduler.aws_iam_policy_attachment.additional_inline[0]"]
    require(scheduler_attachment["roles"] == ["account-kpi-export-scheduler"] and scheduler_attachment["policy_arn"] == scheduler_policy["arn"], "Scheduler custom policy attachment drifted")
    require(not any(".aws_iam_policy.lambda[" in address or ".aws_iam_policy.sqs[" in address or ".aws_iam_role_policy.async_event[" in address for address in indexed), "A broad upstream Lambda/SQS/async policy was attached")


def state_resources(state):
    resources = []

    def visit(module):
        resources.extend(module.get("resources", []))
        for child in module.get("child_modules", []):
            visit(child)

    visit(state["root_module"])
    return {resource["address"]: resource["values"] for resource in resources}


def normalized_statements(document):
    return sorted((statement["effect"], tuple(sorted(statement["actions"])), tuple(sorted(statement["resources"]))) for statement in document["statement"])


def check_iam_state(state, aws_enabled):
    resources = state_resources(state)
    function_arn = resources["module.lambda_function.aws_lambda_function.this[0]"]["arn"]
    queue_arn = resources["module.failure_queue.aws_sqs_queue.this[0]"]["arn"]
    expected_lambda = [
        ("Allow", ("secretsmanager:GetSecretValue",), (SECRET_ARN,)),
        ("Allow", ("sqs:SendMessage",), (queue_arn,)),
    ]
    if aws_enabled:
        expected_lambda.extend([
            ("Allow", ("ce:GetCostAndUsage",), ("*",)),
            ("Allow", ("securityhub:GetEnabledStandards", "securityhub:GetFindings"), ("*",)),
        ])
    lambda_document = resources["module.lambda_function.data.aws_iam_policy_document.additional_inline[0]"]
    require(normalized_statements(lambda_document) == sorted(expected_lambda), "Actual Lambda module IAM statement inputs drifted")
    scheduler_document = resources["module.scheduler.data.aws_iam_policy_document.additional_inline[0]"]
    require(normalized_statements(scheduler_document) == sorted([
        ("Allow", ("lambda:InvokeFunction",), (function_arn,)),
        ("Allow", ("sqs:SendMessage",), (queue_arn,)),
    ]), "Actual Scheduler module IAM statement inputs drifted")


def main():
    require('version = ">= 5.98.0, < 7.0"' in (MODULE_ROOT / "versions.tf").read_text(), "Child AWS provider floor drifted")
    require('version = ">= 5.98.0, < 7.0"' in (MODULE_ROOT / "examples/basic/versions.tf").read_text(), "Direct example AWS provider floor drifted")
    result = subprocess.run([
        "terraform", "-chdir=" + str(MODULE_ROOT), "test", "-filter=tests/account_kpi_export.tftest.hcl", "-json", "-verbose"
    ], capture_output=True, text=True)
    events = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    errors = [event["diagnostic"]["summary"] + ": " + event["diagnostic"]["detail"] for event in events
              if event.get("type") == "diagnostic" and event["diagnostic"]["severity"] == "error"]
    require(result.returncode == 0, "Terraform native tests failed:\n" + "\n".join(errors) + result.stderr)
    plans = {event["@testrun"]: event["test_plan"] for event in events if event.get("type") == "test_plan"}
    states = {event["@testrun"]: event["test_state"] for event in events if event.get("type") == "test_state"}
    check_plan(plans["application_and_aws_contract"])
    check_iam_state(states["infrastructure_contract_state"], aws_enabled=True)
    check_iam_state(states["application_only_infrastructure_state"], aws_enabled=False)
    print("Terraform infrastructure JSON contract passed: real nested plan resources and exact attached IAM document inputs.")


if __name__ == "__main__":
    main()
