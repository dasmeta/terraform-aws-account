#!/usr/bin/env python3
"""Check the enabled root wrapper's real nested Terraform plans."""

import json
import subprocess
from pathlib import Path


TEST_ROOT = Path(__file__).resolve().parent
ROOT_MODULE = TEST_ROOT.parents[1]
TEST_FILE = "account_kpi_export.tftest.hcl"
SECRET_ARN = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
CUSTOM_ACTION_ARN = "arn:aws:sns:eu-central-1:111122223333:example-custom-kpi-alarms"
ACCOUNT_ACTION_ARN = "arn:aws:sns:eu-central-1:111122223333:example-account-alarms"
KPI_PREFIX = "module.this.module.account_kpi_export[0]."
UPTIME_QUERY = (
    '100 * sum(increase(nginx_ingress_controller_requests{status!~"5..", '
    'namespace="production", ingress=~"api|web"}[$__account_kpi_window] @ '
    '$__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_requests'
    '{namespace="production", ingress=~"api|web"}[$__account_kpi_window] @ '
    '$__account_kpi_end_seconds))'
)
LATENCY_QUERY = (
    'sum(increase(nginx_ingress_controller_request_duration_seconds_sum{status=~'
    '"2..|3..", namespace="production", ingress=~"api|web"}'
    '[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase('
    'nginx_ingress_controller_request_duration_seconds_count{status=~"2..|3..", '
    'namespace="production", ingress=~"api|web"}[$__account_kpi_window] @ '
    '$__account_kpi_end_seconds))'
)
OUTPUT_KEYS = {
    "lambda_function_arn",
    "lambda_function_name",
    "schedule_arns",
    "failure_queue_arn",
    "failure_queue_url",
    "alarm_arns",
}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def resources_of_type(plan, resource_type, kpi_only=True):
    resources = [
        resource
        for resource in plan["resource_changes"]
        if resource.get("mode") == "managed"
        and resource["type"] == resource_type
        and (not kpi_only or resource["address"].startswith(KPI_PREFIX))
    ]
    return resources


def single(plan, resource_type):
    selected = resources_of_type(plan, resource_type)
    require(
        len(selected) == 1,
        "Expected exactly one nested KPI {} resource, found {}".format(
            resource_type, len(selected)
        ),
    )
    return selected[0]["change"]["after"]


def output_keys(change):
    after = change.get("after")
    unknown = change.get("after_unknown")
    keys = set(after) if isinstance(after, dict) else set()
    keys.update(unknown if isinstance(unknown, dict) else {})
    return keys


def check_shared_contract(plan):
    output = plan["output_changes"]["account_kpi_export"]
    require(output_keys(output) == OUTPUT_KEYS, "Root exporter output shape drifted")

    function = single(plan, "aws_lambda_function")
    require(function["function_name"] == "example-kpi-export", "Lambda name was not forwarded")
    require(
        function["handler"] == "handler.lambda_handler"
        and function["runtime"] == "python3.13",
        "Lambda runtime entry point drifted",
    )
    require(
        function["timeout"] == 420
        and function["memory_size"] == 512
        and function["reserved_concurrent_executions"] == 1,
        "Non-default Lambda runtime settings were not forwarded",
    )
    require(function["publish"] is False, "The unaliased Lambda must not publish unused versions")
    require(
        function["tracing_config"] == [{"mode": "PassThrough"}],
        "The enabled root exporter must keep Lambda X-Ray tracing disabled",
    )
    environment = function["environment"][0]["variables"]
    require(
        environment["SECRET_ARN"] == SECRET_ARN,
        "Lambda secret reference drifted",
    )
    config = json.loads(environment["CONFIG_JSON"])
    require(
        config
        == {
            "timezone": "Europe/Zurich",
            "cloudbrowser": {
                "base_url": "https://cloudbrowser.example.com",
                "client_id": 42,
                "aws_provider_id": 77,
                "token_key": "example_cloudbrowser_token",
            },
            "application": {
                "enabled": True,
                "source_type": "prometheus",
                "grafana_url": "https://grafana.example.com",
                "datasource_uid": "example-prometheus",
                "uptime_query": UPTIME_QUERY,
                "latency_query": LATENCY_QUERY,
                "token_key": "example_grafana_token",
            },
            "cost": {"enabled": True},
            "security": {"enabled": False, "region": "eu-west-1"},
            "metrics": {
                "security": 104,
                "cost": 112,
                "uptime": 124,
                "latency": 126,
            },
        },
        "Non-default root settings were not forwarded into CONFIG_JSON",
    )

    log_group = single(plan, "aws_cloudwatch_log_group")
    require(log_group["retention_in_days"] == 60, "Log retention was not forwarded")

    queue = single(plan, "aws_sqs_queue")
    asynchronous = single(plan, "aws_lambda_function_event_invoke_config")
    require(
        asynchronous["maximum_event_age_in_seconds"] == 10800
        and asynchronous["maximum_retry_attempts"] == 1,
        "Lambda asynchronous retry settings were not forwarded",
    )
    require(
        asynchronous["destination_config"][0]["on_failure"][0]["destination"]
        == queue["arn"],
        "Lambda asynchronous failures must use the shared queue",
    )

    schedules = resources_of_type(plan, "aws_scheduler_schedule")
    require(
        len(schedules) == 2,
        "Application plus AWS root configuration must plan two schedules",
    )
    schedules_by_name = {
        item["change"]["after"]["name"]: item["change"]["after"]
        for item in schedules
    }
    schedule = schedules_by_name["example-kpi-export-wednesday"]
    target = schedule["target"][0]
    require(
        schedule["name"] == "example-kpi-export-wednesday"
        and schedule["schedule_expression"] == "cron(15 7 ? * WED *)"
        and schedule["schedule_expression_timezone"] == "Europe/Zurich",
        "Wednesday schedule name, expression, or timezone was not forwarded",
    )
    require(
        json.loads(target["input"]) == {"job": "aws"}
        and target["retry_policy"]
        == [{"maximum_event_age_in_seconds": 7200, "maximum_retry_attempts": 5}]
        and target["dead_letter_config"] == [{"arn": queue["arn"]}],
        "Wednesday schedule payload, retry policy, or DLQ drifted",
    )
    monday = schedules_by_name["example-kpi-export-monday"]
    monday_target = monday["target"][0]
    require(
        monday["schedule_expression"] == "cron(15 7 ? * MON *)"
        and monday["schedule_expression_timezone"] == "Europe/Zurich"
        and json.loads(monday_target["input"]) == {"job": "application"},
        "Monday application schedule was not forwarded",
    )

    alarms = resources_of_type(plan, "aws_cloudwatch_metric_alarm")
    require(len(alarms) == 2, "Enabled root exporter must plan exactly two KPI alarms")
    metrics = {alarm["change"]["after"]["metric_name"] for alarm in alarms}
    require(
        metrics == {"Errors", "ApproximateNumberOfMessagesVisible"},
        "KPI alarm metrics drifted",
    )
    return alarms


def check_actions(plan, expected_actions, expect_account_topic):
    alarms = check_shared_contract(plan)
    for alarm in alarms:
        actual_actions = alarm["change"]["after"]["alarm_actions"]
        require(
            len(actual_actions) == len(expected_actions)
            and set(actual_actions) == set(expected_actions),
            "KPI alarm actions were not merged and deduplicated exactly",
        )
    topics = resources_of_type(plan, "aws_sns_topic", kpi_only=False)
    require(
        len(topics) == (1 if expect_account_topic else 0),
        "Account alarm topic enablement drifted",
    )
    if topics:
        require(
            topics[0]["change"]["after"]["name"] == "example-account-alarms",
            "Unexpected account alarm topic planned",
        )


def main():
    require(
        "timeout                            = optional(number, 600)"
        in (ROOT_MODULE / "variables.tf").read_text(),
        "Root Lambda timeout default drifted",
    )
    result = subprocess.run(
        [
            "terraform",
            "-chdir=" + str(TEST_ROOT),
            "test",
            "-filter=" + TEST_FILE,
            "-json",
            "-verbose",
        ],
        capture_output=True,
        text=True,
    )
    events = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    errors = [
        event["diagnostic"]["summary"] + ": " + event["diagnostic"]["detail"]
        for event in events
        if event.get("type") == "diagnostic"
        and event["diagnostic"]["severity"] == "error"
    ]
    require(
        result.returncode == 0,
        "Terraform enabled-root tests failed:\n" + "\n".join(errors) + result.stderr,
    )
    plans = {
        event["@testrun"]: event["test_plan"]
        for event in events
        if event.get("type") == "test_plan"
    }
    require(
        set(plans) == {"custom_alarm_actions_only", "account_alarm_topic_is_merged"},
        "Expected both enabled-root plan results",
    )
    check_actions(plans["custom_alarm_actions_only"], [CUSTOM_ACTION_ARN], False)
    check_actions(
        plans["account_alarm_topic_is_merged"],
        [CUSTOM_ACTION_ARN, ACCOUNT_ACTION_ARN],
        True,
    )
    print(
        "Enabled root Terraform JSON contract passed: real nested resources, "
        "non-default forwarding, output shape, and exact alarm actions."
    )


if __name__ == "__main__":
    main()
