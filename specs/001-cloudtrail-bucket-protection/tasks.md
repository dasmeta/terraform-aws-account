# Tasks: Account CloudTrail protection

## Setup and foundation
- [x] T001 Inspect account1.7.0/main and existing CloudTrail input/dependency; query CloudBrowser and create isolated checkout.
- [x] T002 Execute specification/planning and record compatibility/dependency boundaries in spec.md, plan.md and research.md.

## User Story 2: Wrapper support
- [x] T003 [US2] Add optional grouped cloudtrail.bucket_protection fields in variables.tf, preserving all defaults; forward them in cloudtrail.tf.
- [x] T004 [US2] Pin the tested child immutable revision in cloudtrail.tf for review; do not invent a release version.
- [x] T005 [US2] Add independent example in examples/cloudtrail-bucket-protection/ and focused mocked passthrough/behavior verification; update README.md.
- [x] T006 [US2] Initialize and validate the wrapper against the child and run bounded offline verification; record limitations without pretending an existing-state AWS plan exists.

## Delivery
- [x] T007 Obtain read-only review, publish a draft dependency PR and record tests/revisions in validation.md.
- [x] T008 Update Sela YAML and regenerate _terraform from the supported wrapper revision; verify all three requested settings and existing retention/dev changes remain intact.

## Dependencies and strategy
T001→T002→T003→T004→T005→T006→T007→T008. Child support must be tested/published before its immutable pin is usable. Root account init may need many unrelated modules; keep validation bounded to the changed wrapper contract and real child behavior if unrelated baseline issues block full validation, reporting the exact limit. No cloud apply, shared merge or release.

## Calendar-duration review correction
- [x] R001 Add optional day retention and mutually exclusive unit validation; preserve existing year-based consumers.
- [x] R002 Update examples, native mocked tests and account resource-state verification for 1827 days.
- [ ] R003 Validate, publish dependency revisions, regenerate Sela Terraform and update evidence.
