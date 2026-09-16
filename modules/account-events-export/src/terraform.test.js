const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

function read(relativePath) {
  return fs.readFileSync(path.resolve(__dirname, relativePath), "utf8");
}

test("alerts through the account notification topics when a failed event reaches the DLQ", () => {
  const moduleMain = read("../main.tf");
  const rootMain = read("../../../account-events-export.tf");

  assert.match(moduleMain, /resource "aws_cloudwatch_metric_alarm" "failed_event_queue"/);
  assert.match(moduleMain, /metric_name\s*=\s*"ApproximateNumberOfMessagesVisible"/);
  assert.match(moduleMain, /threshold\s*=\s*1/);
  assert.match(moduleMain, /alarm_actions\s*=\s*var\.dlq_alarm_actions/);
  assert.match(moduleMain, /QueueName\s*=\s*module\.event_queue\.dead_letter_queue_name/);

  assert.match(rootMain, /dlq_alarm_actions\s*=\s*var\.alarm_actions\.enabled/);
  assert.match(rootMain, /dlq_alarm_actions\s*=\s*var\.alarm_actions_virginia\.enabled/);
});

test("defaults to a bounded retry budget that survives a multi-hour webhook outage", () => {
  const moduleVariables = read("../variables.tf");
  const rootVariables = read("../../../variables.tf");

  for (const variables of [moduleVariables, rootVariables]) {
    assert.match(variables, /max_receive_count\s*=\s*optional\(number,\s*100\)/);
    assert.match(variables, /about 2\.5 hours with the default 90-second visibility timeout/i);
  }

  assert.match(
    moduleVariables,
    /max_receive_count\s*>=\s*5\s*&&\s*var\.delivery\.max_receive_count\s*<=\s*1000/
  );
});

test("documents both terminal-failure origins sharing the failed-event queue", () => {
  const outputs = read("../outputs.tf");

  assert.match(
    outputs,
    /receives both EventBridge target failures and webhook-delivery redrives/i
  );
});

test("keeps dependency locks in Terraform Cloud configuration uploads", () => {
  const terraformIgnore = read("../../../.terraformignore");

  assert.doesNotMatch(terraformIgnore, /^\.terraform\.lock\.hcl$/m);
});
