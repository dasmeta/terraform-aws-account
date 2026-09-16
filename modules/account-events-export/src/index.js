const https = require("https");

const EXTERNAL_ENDPOINT = new URL(process.env.WEBHOOK_ENDPOINT);
const WEBHOOK_TIMEOUT_MS = Number.parseInt(process.env.WEBHOOK_TIMEOUT_MS || "10000", 10);

function deliveryMetadata(event, extra = {}) {
  return {
    event_id: event?.id || "unknown",
    event_source: event?.source || "unknown",
    ...extra
  };
}

function webhookPayload(event) {
  if (!event || typeof event !== "object" || !event.id) {
    throw new Error("Account event must contain a stable id");
  }

  return JSON.stringify({
    event: {
      received_time: new Date().toISOString(),
      event_source: event.source,
      event_type: event["detail-type"] || "Unknown",
      event_time: event.time,
      region: event.region,
      detail: event.detail || {},
      raw_event: event
    }
  });
}

function deliverEvent(event) {
  const postData = webhookPayload(event);
  const options = {
    hostname: EXTERNAL_ENDPOINT.hostname,
    port: EXTERNAL_ENDPOINT.port || undefined,
    path: `${EXTERNAL_ENDPOINT.pathname}${EXTERNAL_ENDPOINT.search}`,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(postData),
      "Idempotency-Key": event.id
    }
  };

  return new Promise((resolve, reject) => {
    const request = https.request(options, (response) => {
      response.on("data", () => {});
      response.on("end", () => {
        const statusCode = response.statusCode;
        if (statusCode >= 200 && statusCode < 300) {
          console.log(
            "Webhook delivery succeeded",
            JSON.stringify(deliveryMetadata(event, { status_code: statusCode }))
          );
          resolve({ statusCode });
          return;
        }

        const error = new Error(`Webhook responded with status ${statusCode}`);
        error.name = "WebhookHttpError";
        error.statusCode = statusCode;
        reject(error);
      });
    });

    request.setTimeout(WEBHOOK_TIMEOUT_MS, () => {
      const error = new Error(`Webhook request timed out after ${WEBHOOK_TIMEOUT_MS}ms`);
      error.name = "WebhookTimeoutError";
      request.destroy(error);
    });

    request.on("error", reject);
    request.write(postData);
    request.end();
  });
}

function logFailure(event, error, queueMessageId) {
  console.error(
    "Webhook delivery failed",
    JSON.stringify(deliveryMetadata(event, {
      error_type: error?.name || "Error",
      queue_message_id: queueMessageId,
      status_code: error?.statusCode
    }))
  );
}

async function handleQueuedRecords(records) {
  const batchItemFailures = [];

  for (const record of records) {
    let event;
    try {
      event = JSON.parse(record.body);
      await deliverEvent(event);
    } catch (error) {
      logFailure(event, error, record.messageId);
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  return { batchItemFailures };
}

exports.handler = async (input) => {
  if (Array.isArray(input?.Records)) {
    return handleQueuedRecords(input.Records);
  }

  try {
    return await deliverEvent(input);
  } catch (error) {
    logFailure(input, error);
    throw error;
  }
};
