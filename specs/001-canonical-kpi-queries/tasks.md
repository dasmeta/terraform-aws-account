# Tasks: Canonical Application KPI Queries

**Input**: Design documents from `specs/001-canonical-kpi-queries/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/application-query-contract.md`

## Phase 1: Contract Tests

- [x] T001 [US1] Add a failing canonical generation run to `modules/account-kpi-export/tests/account_kpi_export.tftest.hcl`
- [x] T002 [P] [US2] Add failing child validation runs for empty and partial query modes in `modules/account-kpi-export/tests/account_kpi_export.tftest.hcl`
- [x] T003 [P] [US1] Update root enabled-fixture expectations in `tests/account-kpi-export-enabled/1-example.tf` and `tests/account-kpi-export-enabled/account_kpi_export.tftest.hcl`
- [x] T004 [US1] Run targeted Terraform tests and capture the expected red state

## Phase 2: User Story 1 - Configure canonical application KPIs (Priority: P1)

**Independent Test**: Canonical input produces exact explicit runtime queries and the existing application schedule.

- [x] T005 [US1] Add optional root `metric_filter` and mode validation in `variables.tf`
- [x] T006 [US1] Verify the existing whole-object forwarding in `account-kpi-export.tf` carries the optional field without a separate mapping
- [x] T007 [US1] Add optional child `metric_filter` and mode validation in `modules/account-kpi-export/variables.tf`
- [x] T008 [US1] Generate canonical queries with raw-pair precedence in `modules/account-kpi-export/locals.tf`
- [x] T009 [US1] Run canonical and legacy contract tests to green

## Phase 3: User Story 2 - Prevent ambiguous query configuration (Priority: P2)

**Independent Test**: Empty and one-query Prometheus application configurations fail at both public boundaries.

- [x] T010 [US2] Add root validation coverage to `tests/account-kpi-export-url-validation.tftest.hcl`
- [x] T011 [US2] Run root and child negative tests to green

## Phase 4: Documentation and Verification

- [x] T012 [P] Update canonical configuration examples in `README.md` and `tests/account-kpi-export-enabled/1-example.tf`
- [x] T013 [P] Document the optional field in the root README (the child module has no standalone README)
- [x] T014 Run `terraform fmt -recursive` and `terraform fmt -check -recursive`
- [x] T015 Run targeted Terraform tests and `python3 -W error::ResourceWarning -m unittest discover -s modules/account-kpi-export/tests -p 'test_*.py'`
- [x] T016 Inspect the final diff for backward compatibility, no customer identifiers, no new metric IDs, and no Lambda/package changes

## Dependencies and Execution Order

- T001-T003 precede T004; T004 must show the expected red state.
- T005-T008 implement the minimum canonical flow; T009 gates negative cases.
- T010-T011 complete validation behavior.
- T012-T016 follow green functional tests.
