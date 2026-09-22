# Canonical Account KPI Queries Implementation Plan

> Execute test-first in the isolated `fix/canonical-kpi-queries` worktree.

**Goal:** Let account configuration select the corrected NGINX uptime and average-latency definitions with one scoped filter and no copied query strings.

**Architecture:** Add one optional attribute to the existing root/child application object. The child module validates canonical versus override mode and always serializes explicit raw PromQL to the unchanged Lambda handler.

**Tech Stack:** Terraform HCL/native tests, existing Python collector, Grafana Prometheus proxy.

## Task 1: Lock configuration behavior

Write tests for exact canonical query generation, complete raw-pair compatibility, empty canonical settings, and partial raw pairs. Run them first and confirm failure because `metric_filter` is not accepted/generated yet.

## Task 2: Extend the grouped input safely

Add optional `metric_filter` to root and child types. Validation accepts either a non-empty filter with zero raw queries or a complete placeholder-bearing raw pair. Forward the field root-to-child.

## Task 3: Generate runtime queries

Normalize the filter, construct the uptime non-5xx/all expression and 2xx/3xx weighted latency expression with exact-window placeholders, and select the complete raw pair when supplied. Keep serialized `source_type` as `prometheus`.

## Task 4: Document and verify

Update neutral examples and READMEs, format Terraform, run child/root tests and the existing 90-test Python suite, and inspect the diff for no handler, package, IAM, schedule, or metric-ID changes.
