# CloudBrowser API Contract

All requests use `Authorization: Bearer <runtime token>`, `Accept: application/json`, bounded timeout,
and JSON content type for writes. The base URL defaults to `https://app.dasmeta.com` and is configurable.

## Resolve AWS Account

```http
GET /api/accounts
  ?filters[accountId][$eq]={runtime_account_id}
  &filters[client][id][$eq]={client_id}
  &filters[provider][id][$eq]={aws_provider_id}
  &populate[0]=provider
  &populate[1]=client
  &pagination[pageSize]=2
```

Exactly one result is required. The implementation accepts both Strapi v4 `attributes` envelopes and
flat entity objects while validating the returned account, client, and provider IDs.

## Find Existing Metric Row

```http
GET /api/metric-datas
  ?filters[metric][id][$eq]={metric_id}
  &filters[client][id][$eq]={client_id}
  &filters[account][id][$eq]={account_id}
  &filters[date][$eq]={record_date}
  &pagination[pageSize]=2
```

Zero results permit creation. One numerically equal value is an idempotent skip. Equality uses exact
decimal numeric comparison against the submitted metric-specific rounded value, with no tolerance.
One changed value or two results is a conflict and never triggers an automatic update.

## Create Metric Row

```http
POST /api/metric-datas
```

```json
{
  "data": {
    "metric": 12,
    "client": 42,
    "account": 101,
    "value": 123.4567,
    "date": "2026-09-09T20:00:00.000Z"
  }
}
```

IDs and values above are generic examples. HTTP 2xx is success. Authentication, validation, and
permanent 4xx responses fail immediately. The client never retries POST in place. A network error,
HTTP 429, or HTTP 5xx makes the POST outcome ambiguous and triggers one immediate natural-key GET:

- one row with the submitted value returns `reconciled_created`;
- one row with another value or multiple rows raises a conflict;
- zero rows re-raises the write failure so Lambda asynchronous retry can replay the job.

Safe GET requests use bounded retry for network errors, 429, and 5xx. The Lambda has reserved
concurrency one per account, which serializes schedule delivery and manual collector replays.
