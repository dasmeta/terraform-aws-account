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



// import https from "https";
// import { CostExplorerClient, GetCostAndUsageCommand } from "@aws-sdk/client-cost-explorer";
// import { format, subDays, addDays } from 'date-fns';

// // Initialize the AWS Cost Explorer client, the Cost Explorer API is typically accessed in us-east-1 for global billing data
// const ceClient = new CostExplorerClient({ region: "us-east-1" });

// export const handler = async (event, context) => {
//   console.log({ event: JSON.stringify(event), context: JSON.stringify(context) });

//   const accountId = context.invokedFunctionArn.split(':')[4];
//   const WEBHOOK_ENDPOINT = process.env.WEBHOOK_ENDPOINT; // Get from environment variables

//   if (!WEBHOOK_ENDPOINT) {
//     console.error("WEBHOOK_ENDPOINT environment variable is not set.");
//     return {
//       statusCode: 500,
//       body: JSON.stringify('Configuration error: WEBHOOK_ENDPOINT is not set.'),
//     };
//   }

//   // Split host and path if the endpoint includes a path (common for webhooks)
//   let hostname;
//   let path = '/'; // Default path if none specified

//   try {
//     const url = new URL(WEBHOOK_ENDPOINT);
//     hostname = url.hostname;
//     path = url.pathname + url.search; // Include query parameters if any
//     if (path === '') { // Ensure path is at least '/'
//       path = '/';
//     }
//   } catch (e) {
//     console.error(`Invalid WEBHOOK_ENDPOINT URL: ${WEBHOOK_ENDPOINT}`, e);
//     return {
//       statusCode: 500,
//       body: JSON.stringify(`Invalid WEBHOOK_ENDPOINT URL: ${WEBHOOK_ENDPOINT}`),
//     };
//   }

//   const costData = await getCosts(event);

//   const postData = JSON.stringify({
//     ...costData,
//     accountId,
//     timestamp: new Date().toISOString()
//   });

//   const options = {
//     hostname: hostname,
//     port: 443,
//     path: path,
//     method: 'POST',
//     headers: {
//       'Content-Type': 'application/json',
//       'Content-Length': Buffer.byteLength(postData)
//     }
//   };

//   return new Promise((resolve, reject) => {
//     const req = https.request(options, (res) => {
//       let buffer = '';
//       console.log(`Webhook response status: ${res.statusCode}`);
//       console.log(`Webhook response headers: ${JSON.stringify(res.headers)}`);

//       res.on('data', (chunk) => {
//         buffer += chunk;
//       });

//       res.on('end', () => {
//         resolve({
//           statusCode: res.statusCode,
//           body: buffer
//         });
//       });
//     });

//     req.on('error', (e) => {
//       console.error(`Problem with webhook request: ${e.message}`);
//       reject(e.message);
//     });

//     req.write(postData);
//     req.end(); // End the request, sending the data
//   });
// };

// const getCosts = async (event) => {
//   const today = new Date(); // Current date and time (in UTC on Lambda, unless specified otherwise)

//   const twoDaysBefore = subDays(today, 2);
//   const threeDaysBefore = subDays(today, 3);
//   const startDatePrevious = format(threeDaysBefore, 'yyyy-MM-dd');
//   const endDatePrevious = format(twoDaysBefore, 'yyyy-MM-dd'); // End date is exclusive

//   const queryStartDate = startDatePrevious;
//   const queryEndDate = endDatePrevious;

//   try {
//     const input = {
//       TimePeriod: {
//         Start: queryStartDate,
//         End: queryEndDate
//       },
//       Granularity: 'DAILY',
//       Metrics: ['UnblendedCost'],
//     };

//     const command = new GetCostAndUsageCommand(input);
//     const response = await ceClient.send(command);

//     let totalCost = 0.0;
//     let currency = null
//     const resultsByTime = response.ResultsByTime;

//     if (resultsByTime && resultsByTime.length > 0) {
//       for (const resultForPeriod of resultsByTime) {
//         const timePeriod = resultForPeriod.TimePeriod;
//         const totalAmount = resultForPeriod.Total.UnblendedCost.Amount;
//         const totalUnit = resultForPeriod.Total.UnblendedCost.Unit;

//         totalCost += parseFloat(totalAmount);
//         currency = totalUnit
//       }
//     }

//     console.log(`Total cost for the queried period (${queryStartDate} to ${queryEndDate}): ${totalCost} ${currency}`);

//     return {
//       success: true,
//       message: `Successfully retrieved cost data for ${queryStartDate}`,
//       cost: totalCost,
//       value: totalCost,
//       currency,
//       date: queryStartDate
//     };

//   } catch (error) {
//     console.error(`Error fetching cost data: ${error.message}`);
//     return {
//       success: false,
//       message: `Failed to retrieve cost data: ${error.message}`,
//     };
//   }
// };
