"""Verify real child resource values from a verbose, mocked Terraform test state."""
import json
import sys
from pathlib import Path


def dictionaries(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from dictionaries(child)
    elif isinstance(value, list):
        for child in value:
            yield from dictionaries(child)


def check(path):
    events = [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]
    errors = [e for e in events if e.get("diagnostic", {}).get("severity") == "error"]
    assert not errors, "Terraform emitted an error diagnostic."
    resources = {}
    for event in events:
        if event.get("type") != "test_state":
            continue
        for value in dictionaries(event):
            address = value.get("address", "")
            if isinstance(address, str) and address.startswith("module.cloudtrail[0].") and "values" in value:
                resources[address] = value["values"]
    prefix = "module.cloudtrail[0]."
    bucket = resources[prefix + "aws_s3_bucket.s3[0]"]
    versioning = resources[prefix + "aws_s3_bucket_versioning.s3[0]"]
    lock = resources[prefix + "aws_s3_bucket_object_lock_configuration.s3[0]"]
    policy = json.loads(resources[prefix + "aws_s3_bucket_policy.s3[0]"]["policy"])
    trail = resources[prefix + "aws_cloudtrail.cloudtrail"]
    assert bucket["force_destroy"] is False, "Account did not forward force_destroy=false."
    assert versioning["versioning_configuration"][0]["status"] == "Enabled"
    retention = lock["rule"][0]["default_retention"][0]
    assert lock["object_lock_enabled"] == "Enabled"
    assert retention["mode"] == "GOVERNANCE" and retention["years"] == 5
    assert versioning["bucket"] == bucket["id"] == lock["bucket"]
    statements = {s["Sid"]: s for s in policy["Statement"]}
    deny = statements["DenyGovernanceBypassExceptEmergencyRoles"]
    assert deny["Effect"] == "Deny" and deny["Principal"] == "*"
    assert deny["Action"] == "s3:BypassGovernanceRetention"
    assert deny["Condition"]["ArnNotEquals"]["aws:PrincipalArn"] == [
        "arn:aws:iam::123456789012:role/example-audit-emergency"
    ]
    assert statements["AWSCloudTrailAclCheck"]["Principal"]["Service"] == "cloudtrail.amazonaws.com"
    assert statements["AWSCloudTrailWrite"]["Principal"]["Service"] == [
        "cloudtrail.amazonaws.com", "config.amazonaws.com"
    ]
    assert trail["enable_log_file_validation"] and trail["is_multi_region_trail"]
    assert trail["s3_bucket_name"] == "example-audit-cloud-trail-bucket"
    print("PASS: account wrapper forwards versioning, five-year Governance, forced-deletion protection and the exact bypass exception to real child resource configuration.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check_cloudtrail_protection.py <terraform-test-verbose.json>")
    check(sys.argv[1])
