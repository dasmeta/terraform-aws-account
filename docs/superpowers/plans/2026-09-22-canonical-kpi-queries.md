# Canonical Account KPI Queries Implementation Plan

> Execute test-first in the isolated `fix/canonical-kpi-queries` worktree.

**Goal:** Let account configuration select the corrected NGINX uptime and average-latency definitions with one scoped filter and no copied query strings.

**Architecture:** Add explicit optional profile attributes to the existing root/child application object. The child module validates profile versus raw mode and always serializes explicit raw PromQL to the unchanged Lambda handler.

**Tech Stack:** Terraform HCL/native tests, existing Python collector, Grafana Prometheus proxy.

## Task 1: Lock configuration behavior

Write tests for exact profile query generation, complete raw-pair compatibility, filter-only input, unknown profiles, profile-plus-raw input, empty settings, and partial raw pairs. Run new review-correction tests first and confirm they fail while a metric filter still implicitly selects NGINX.

## Task 2: Extend the grouped input safely

Add optional `query_profile` and `metric_filter` to root and child types. Validation accepts either the explicit `nginx_ingress` profile with a non-empty filter and zero raw queries, or a complete placeholder-bearing raw pair with no profile/filter. Forward the fields root-to-child.

## Task 3: Generate runtime queries

Normalize the profile/filter, construct the uptime non-5xx/all expression and 2xx/3xx weighted average-latency expression with exact-window placeholders, and generate those expressions only for the explicit NGINX profile. Keep serialized `source_type` as `prometheus`.

## Task 4: Document and verify

Update neutral examples and READMEs, format Terraform, run child/root tests and the existing 90-test Python suite, and inspect the diff for no handler, package, IAM, schedule, or metric-ID changes.
