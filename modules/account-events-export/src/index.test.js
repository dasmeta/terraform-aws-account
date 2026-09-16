const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const https = require("node:https");
const { afterEach, beforeEach, test } = require("node:test");

process.env.WEBHOOK_ENDPOINT = "https://events.example.com/webhook?accountId=example";
process.env.WEBHOOK_TIMEOUT_MS = "25";

const { handler } = require("./index");

const originalRequest = https.request;
const originalLog = console.log;
const originalError = console.error;

let requests;
let logs;

function event(id = "event-123", marker = "private-marker") {
  return {
    version: "0",
    id,
    "detail-type": "Example Event",
    source: "aws.example",
    account: "000000000000",
    time: "2026-09-15T13:00:00Z",
    region: "eu-central-1",
    resources: [],
    detail: { marker }
  };
}

function installRequestStub(resolver) {
  https.request = (options, onResponse) => {
    const listeners = {};
    const captured = {
      body: "",
      destroyed: false,
      options,
      timeout: null
    };
    requests.push(captured);

    const request = {
      destroy(error) {
        captured.destroyed = true;
        queueMicrotask(() => listeners.error?.(error));
      },
      end() {
        queueMicrotask(() => resolver({
          captured,
          fail(error) {
            listeners.error?.(error);
          },
          respond(statusCode, responseBody = "") {
            const response = new EventEmitter();
            response.statusCode = statusCode;
            onResponse(response);
            if (responseBody) {
              response.emit("data", responseBody);
            }
            response.emit("end");
          },
          triggerTimeout() {
            if (captured.timeout) {
              captured.timeout.callback();
            } else {
              listeners.error?.(new Error("request timeout was not configured"));
            }
          }
        }));
      },
      on(name, callback) {
        listeners[name] = callback;
        return request;
      },
      setTimeout(milliseconds, callback) {
        captured.timeout = { callback, milliseconds };
        return request;
      },
      write(body) {
        captured.body += body;
      }
    };

    return request;
  };
}

beforeEach(() => {
  requests = [];
  logs = [];
  console.log = (...values) => logs.push(values.join(" "));
  console.error = (...values) => logs.push(values.join(" "));
});

afterEach(() => {
  https.request = originalRequest;
  console.log = originalLog;
  console.error = originalError;
});

test("preserves the webhook payload and sends a stable idempotency key", async () => {
  installRequestStub(({ respond }) => respond(204));

  await handler(event());

  assert.equal(requests.length, 1);
  assert.equal(requests[0].options.headers["Idempotency-Key"], "event-123");
  const payload = JSON.parse(requests[0].body);
  assert.equal(payload.event.event_source, "aws.example");
  assert.equal(payload.event.event_type, "Example Event");
  assert.equal(payload.event.raw_event.id, "event-123");
});

test("rejects a non-2xx webhook response", async () => {
  installRequestStub(({ respond }) => respond(503, "private-response"));

  await assert.rejects(handler(event()), /status 503/i);
});

test("returns an SQS batch failure for a failed webhook delivery", async () => {
  installRequestStub(({ captured, respond }) => {
    const id = JSON.parse(captured.body).event.raw_event.id;
    respond(id === "event-fail" ? 429 : 200);
  });
  const sqsEvent = {
    Records: [
      { messageId: "message-ok", body: JSON.stringify(event("event-ok")) },
      { messageId: "message-fail", body: JSON.stringify(event("event-fail")) }
    ]
  };

  const result = await handler(sqsEvent);

  assert.deepEqual(result, {
    batchItemFailures: [{ itemIdentifier: "message-fail" }]
  });
});

test("returns malformed SQS records as batch failures", async () => {
  installRequestStub(({ respond }) => respond(200));

  const result = await handler({
    Records: [{ messageId: "message-invalid", body: "{invalid-json" }]
  });

  assert.deepEqual(result, {
    batchItemFailures: [{ itemIdentifier: "message-invalid" }]
  });
  assert.equal(requests.length, 0);
});

test("aborts a webhook request at the configured request timeout", async () => {
  installRequestStub(({ triggerTimeout }) => triggerTimeout());

  await assert.rejects(handler(event()), /timed out after 25ms/i);
  assert.equal(requests[0].timeout.milliseconds, 25);
  assert.equal(requests[0].destroyed, true);
});

test("logs delivery metadata without event or response bodies", async () => {
  installRequestStub(({ respond }) => respond(200, "private-response"));

  await handler(event());

  const output = logs.join("\n");
  assert.match(output, /event-123/);
  assert.match(output, /aws\.example/);
  assert.match(output, /200/);
  assert.doesNotMatch(output, /private-marker/);
  assert.doesNotMatch(output, /private-response/);
});
