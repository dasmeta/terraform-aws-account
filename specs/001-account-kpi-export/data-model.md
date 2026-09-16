# Data Model: Weekly Account KPI Export

## Account KPI Configuration

One Terraform configuration exists per deployed AWS account.

| Field group | Meaning | Validation |
|---|---|---|
| Identity | Exporter name, CloudBrowser client ID, AWS provider ID | Positive IDs; neutral default name |
| Secret reference | Secrets Manager ARN and JSON token key names | ARN required when enabled; values never enter Terraform |
| Application source | Enablement, Grafana URL, datasource UID, uptime query, latency query | All source fields required when enabled |
| AWS sources | Independent cost and Security Hub enablement, aggregation Region | At least one source enabled overall; non-empty Region |
| Metrics | Security, cost, uptime, latency CloudBrowser metric IDs | Positive integers; established defaults 4, 12, 24, 26 |
| Scheduling | Time zone, Monday/Wednesday cron, delivery retry age and count | IANA name non-empty; Scheduler bounds enforced |
| Runtime | Timeout, memory, log retention, async handler retry settings, alarm action ARNs | Positive values within Lambda bounds; reserved concurrency fixed at one |

## Reporting Window

| Field | Type | Definition |
|---|---|---|
| `start_date` | date | Prior local Monday, inclusive |
| `end_date` | date | Current local Monday, exclusive |
| `start_utc` | datetime | Local start midnight converted to UTC |
| `end_utc` | datetime | Local end midnight converted to UTC; Grafana instant query time |
| `record_date` | datetime | Prior-week Wednesday local midnight converted to UTC |

The reporting window is derived from Lambda invocation time and configuration. Scheduler payloads
cannot override it.

## CloudBrowser Account

| Field | Type | Role |
|---|---|---|
| `id` | integer | Relation stored on every metric row |
| `accountId` | 12-digit string | Must equal the Lambda runtime AWS account |
| `client.id` | integer | Must equal configured client ID |
| `provider.id` | integer | Must equal configured AWS provider ID |

Resolution has three outcomes: exactly one account proceeds; zero accounts fail; multiple accounts
fail as a data-integrity error. The collector never creates or updates account metadata.

## Measurement

| Measurement | Source time semantics | Validation | Default metric ID |
|---|---|---|---|
| Cloud Cost | Prior complete week | Finite signed value from summed daily buckets; rounded to four decimals | 12 |
| Security Level | Wednesday execution-time snapshot associated with prior week | Finite 0–100 percentage; rounded to four decimals | 4 |
| Uptime | Prior complete week | One finite 0–100 percentage; rounded to six decimals | 24 |
| Latency (avg) | Prior complete week | One finite value at or above zero seconds; rounded to six decimals | 26 |

Application measurements form a validation pair: both must be collected and valid before either
write starts. AWS measurements remain independent.

Cost Explorer supplies daily buckets for the complete window. Each amount must be finite and use a
consistent supported unit; positive charges, zero, negative credits, and refunds are valid inputs.
An empty or incomplete Cost Explorer result is invalid rather than silently reported as zero.

Security Hub requires at least one `READY` standard subscription and filters both `Security Hub` and
`Security Hub CSPM` product names. Raw finding statuses map as follows: `FAILED` becomes Failed,
`WARNING` and `NOT_AVAILABLE` become Unknown, and `PASSED` becomes Passed. Only a nonempty canonical
`Compliance.SecurityControlId` identifies a scoreable control; a missing ID is No data and is excluded.
`GeneratorId` never supplies a fallback ID. `UNKNOWN` is not a valid raw `Compliance.Status` value.

## Metric Row

| Field | Type | Constraint |
|---|---|---|
| `metric` | integer relation | Configured ID for the measurement |
| `client` | integer relation | Configured client ID |
| `account` | integer relation | Resolved CloudBrowser account ID |
| `value` | number | Validated and deterministically rounded |
| `date` | ISO-8601 datetime | Reporting-window `record_date` |

The natural key is `(metric, client, account, date)`. Existing and submitted values compare by exact
decimal numeric equality after the submitted value has been rounded to its metric contract. No
tolerance can convert a changed value into a duplicate.

### Write State Transitions

```text
absent --POST succeeds---------------------------> created
same value --------------------------------------> skipped_duplicate
different value --------------------------------> conflict (no mutation)
multiple rows ----------------------------------> integrity_conflict (no mutation)
ambiguous POST + one equal row on reconciliation -> reconciled_created
ambiguous POST + unequal/multiple rows ----------> conflict
ambiguous POST + no row -------------------------> failed (Lambda async replay)
```

## Job Result

The handler emits and returns a structured summary containing job, AWS account ID, reporting period,
record date, and one result per enabled metric. Metric statuses are `created`, `skipped_duplicate`,
`reconciled_created`, `conflict`, `skipped`, or `failed`. Any conflict or failure raises after logging
the summary. Scheduler retries failures to deliver an invocation; Lambda asynchronous retries handle
accepted invocations whose handler fails. Exhausted events from either path enter the shared queue.
