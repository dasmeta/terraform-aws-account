# Tasks: Security Hub CSPM routing and corrective remediation

## Phase 1: Setup

- [X] T001 Bootstrap `.specify/` and create `specs/001-security-hub-cspm-routing/spec.md`.
- [X] T002 Record design, evidence limits, and verification in `specs/001-security-hub-cspm-routing/plan.md` and supporting files.

## Phase 2: Foundation

- [X] T003 Confirm current monitoring module outputs and root input compatibility in `security-hub.tf`, `variables.tf`, and `outputs.tf`.

## Phase 3: User Story 1 — Safe alert routing

- [X] T004 [US1] Add native tests for existing disabled/shared/dedicated notification modes in `tests/security-hub-cspm.tftest.hcl`.
- [X] T005 [US1] Expose effective route identifiers and close ambiguous topic configuration in `security-hub.tf` and `outputs.tf`.

## Phase 4: User Story 2 — Corrective remediation

- [X] T006 [US2] Add native default and opt-in safety tests in `tests/security-hub-cspm.tftest.hcl`.
- [X] T007 [US2] Add grouped optional workflows and validation in `variables.tf`.
- [X] T008 [US2] Implement exact finding rules, invocation IAM, retries, failure queues, execution failure visibility in `security-hub-remediation.tf`.
- [X] T009 [US2] Add sanitized route and failure outputs in `outputs.tf`.

## Phase 5: User Story 3 — Usage and evidence

- [X] T010 [US3] Add a neutral runnable example in `examples/security-hub-remediation/0-setup.tf` and `1-example.tf`.
- [X] T011 [US3] Document controls, live evidence gaps, safe rollout and rollback in `README.md`.

## Phase 6: Validation

- [X] T012 Run format, init, validate, focused native tests, and `git diff --check`; record results in `specs/001-security-hub-cspm-routing/quickstart.md`.

**Dependencies**: T003 before US1/US2; US2 design before example; T012 after all changes. Tasks within one Terraform file run sequentially.
