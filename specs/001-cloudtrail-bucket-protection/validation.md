# Validation — 2026-10-20

- Root account initialized against the immutable child revision 8f95be9054514e0dcfaccda8c9c88c7f881dca2b (CloudTrail PR371), with AWS5.100.0 and existing dependency versions.
- Terraform validate passed with the AWS/default+virginia provider configuration supplied by a temporary consumer context. The module requires those aliases from its caller; no provider configuration is committed into the module itself.
- Focused native AWS-mocked runs: disabled defaults and protected CloudTrail both passed. The mocked fixture supplies a valid policy ARN for the unrelated default MFA attachment; no AWS APIs were called.
- Resource-state checker passed: actual child state has force_destroy=false, Enabled versioning, Enabled GOVERNANCE retention for 1827 days (covering five calendar years), preserved service delivery statements and the exact exception role. Thus omitting the forwarded object would fail verification.
- Independent read-only review found no blocking issues in wrapper code, examples, state checker or the Sela role-output/workspace link.
- Provider caches/lockfiles, simulated test state and temporary provider configuration remain uncommitted. The global all-files commit wrapper is avoided after equivalent scoped checks, as it reformats unrelated documentation.
- Live existing-state zero-replacement planning, real delivery/IAM verification, supported dependency releases and exact production approval remain deployment gates. No cloud apply or release performed.

A final native run with the temporary consumer provider file removed also passed: 2 passed,0 failed. The resource-state checker passed against that fresh verbose state. Native test mocks supply required aliases themselves; the caller context is needed only for standalone terraform validate.

Published dependency PRs: https://github.com/dasmeta/terraform-aws-modules/pull/371 and https://github.com/dasmeta/terraform-aws-account/pull/67. Sela source and regenerated account Terraform are published in MR !183 at 21de61e381ff5c8cd71640ac46c43387cc7164af. The consumer pins the tested immutable code commits; this follow-up changes documentation only. All source-implementation tasks are complete; merge/release and production deployment gates remain outstanding.

## Calendar-duration correction
The wrapper now exposes optional governance_retention_days and pins the day-capable child revision. Protected examples/tests request 1827 days. The independent checker requires actual child days=1827 and years unset, so dropping the day field cannot silently pass. Child validation and 16 native mocked tests passed; a Gregorian 400-year-cycle check found a maximum five-year anniversary span of 1827 days. No AWS APIs or infrastructure apply.

Current correction verification: root validation with consumer provider aliases passed; both native mocked runs passed (2/2), and the independent resource-state checker passed against the verbose state. Independent read-only review found no blockers. Scoped pre-commit checks passed.
