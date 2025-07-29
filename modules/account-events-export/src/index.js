const https = require("https");
const url = require("url");

const EXTERNAL_ENDPOINT = process.env.WEBHOOK_ENDPOINT;

exports.handler = async (event) => {
  const startTime = Date.now();
  console.log("Event received:", JSON.stringify(event, null, 2));

  // Ensure `detail` is included and correctly formatted
  const eventData = {
    received_time: new Date(startTime).toISOString(),
    event_source: event.source,
    event_type: event["detail-type"] || "Unknown",
    event_time: event.time,
    region: event.region,
    detail: event.detail || {},
    raw_event: event
  };

  // n8n prefers an array structure or `body` wrapped objects
  const postData = JSON.stringify({
    event: eventData // Wrap in `event` key for better parsing
  });

  const parsedUrl = url.parse(EXTERNAL_ENDPOINT);

  const options = {
    hostname: parsedUrl.hostname,
    path: parsedUrl.path || "/",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let responseBody = "";
      res.on("data", (chunk) => {
        responseBody += chunk;
      });

      res.on("end", () => {
        console.log("Webhook response:", responseBody);
        resolve({
          statusCode: res.statusCode,
          body: responseBody
        });
      });
    });

    req.on("error", (error) => {
      console.error("Error:", error);
      reject(error);
    });

    req.write(postData);
    req.end();
  });
};
