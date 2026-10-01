const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

function read(relativePath) {
  return fs.readFileSync(path.resolve(__dirname, relativePath), "utf8");
}

test("creates default FreeStorageSpace alarms for discovered RDS instances", () => {
  const variables = read("variables.tf");
  const alarms = read("rds-free-storage-alarms.tf");

  assert.match(variables, /variable "rds_free_storage_alarms"/);
  assert.match(variables, /enabled\s+=\s+optional\(bool, true\)/);
  assert.match(variables, /threshold\s+=\s+optional\(number, 10737418240\)/);
  assert.match(alarms, /data\.aws_db_instances\.rds_free_storage\[0\]\.instance_identifiers/);
  assert.match(alarms, /metric_name\s+=\s+"FreeStorageSpace"/);
  assert.match(alarms, /namespace\s+=\s+"AWS\/RDS"/);
  assert.match(alarms, /DBInstanceIdentifier\s+=\s+each\.key/);
  assert.match(alarms, /resource "aws_cloudwatch_metric_alarm" "rds_free_storage_virginia"/);
});
