import https from "https";
import { gunzip as zlibGunzip } from "zlib";
import { URL } from "url";
import { promisify } from "util";

const gunzipPromise = promisify(zlibGunzip);

const sendToGoogleChat = async (webhookUrl, message) => {
  console.log(
    `🔵 [Google Chat] Preparing to send message to: ${webhookUrl?.substring(
      0,
      50
    )}...`
  );

  const MAX_LENGTH = 4000;
  const finalMessage =
    message.length > MAX_LENGTH
      ? message.substring(0, MAX_LENGTH) + "..."
      : message;

  const postData = JSON.stringify({ text: finalMessage });
  const url = new URL(webhookUrl);

  const options = {
    hostname: url.hostname,
    path: url.pathname + url.search,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(postData),
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let responseBody = "";

      res.on("data", (chunk) => {
        responseBody += chunk;
      });

      res.on("end", () => {
        console.log(`🔵 [Google Chat] Response status: ${res.statusCode}`);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log("✅ [Google Chat] Message sent successfully");
          resolve();
        } else {
          console.error(
            `❌ [Google Chat] Failed with status ${res.statusCode}: ${responseBody}`
          );
          reject(new Error(`HTTP ${res.statusCode}: ${responseBody}`));
        }
      });
    });

    req.on("error", (error) => {
      console.error("❌ [Google Chat] Request error:", error.message);
      reject(error);
    });

    req.write(postData);
    req.end();
  });
};

// Hàm gửi toàn bộ error stack
async function sendErrorStack(errorStack) {
  const fullErrorMessage = errorStack.join("\n");
  const truncatedMessage =
    fullErrorMessage.length > 4000
      ? fullErrorMessage.substring(0, 4000) + "..."
      : fullErrorMessage;
  console.log(
    `📦 [Error Stack] Sending ${errorStack.length} lines to ERROR channel`
  );
  await sendToGoogleChat(
    process.env.GOOGLE_CHAT_ERROR_WEBHOOK,
    truncatedMessage
  );
}

// Hàm xử lý log đơn lẻ
async function processSingleLog(logMessage) {
  // SMART ERROR DETECTION - COMPREHENSIVE
  const isRealError =
    /(production\.ERROR|\.ERROR[: ]|\bERROR:|\bCRITICAL:|\bALERT:|\bEMERGENCY:|\bFatal error:|\[error\]|\[emerg\]|\[crit\]|PHP Fatal|PHP Parse|SQLSTATE|502\s|503\s|504\s)/i.test(
      logMessage
    );
  const isNginxKeepalive = /\[info\].*closed (keepalive )?connection/i.test(
    logMessage
  );
  const isError = isRealError && !isNginxKeepalive;
  const webhookUrl = isError
    ? process.env.GOOGLE_CHAT_ERROR_WEBHOOK
    : process.env.GOOGLE_CHAT_GENERAL_WEBHOOK;

  if (webhookUrl) {
    await sendToGoogleChat(webhookUrl, logMessage);
  }
}

export const handler = async (event) => {
  console.log("🎯 [Handler] Lambda invoked");
  console.log("📦 [Handler] Event keys:", Object.keys(event));

  try {
    // Check if this is a CloudWatch Logs event
    if (!event.awslogs || !event.awslogs.data) {
      console.log(
        "❌ [Handler] NOT a CloudWatch Logs event. Event type:",
        typeof event
      );
      console.log(
        "📋 [Handler] Event sample:",
        JSON.stringify(event).substring(0, 500)
      );
      return { statusCode: 200, body: "Not CloudWatch event" };
    }

    console.log("🔍 [Handler] Processing CloudWatch Logs event");

    // Decompress log data
    console.log(
      "📦 [Handler] Base64 payload length:",
      event.awslogs.data.length
    );
    const payload = Buffer.from(event.awslogs.data, "base64");
    console.log("📊 [Handler] Decoded payload length:", payload.length);

    const decompressed = await gunzipPromise(payload);
    console.log(
      "✅ [Handler] Successfully decompressed, length:",
      decompressed.length
    );

    const logData = JSON.parse(decompressed.toString());
    console.log("🎯 [Handler] Log data type:", logData.messageType);
    console.log("📝 [Handler] Log group:", logData.logGroup);
    console.log(
      "🔢 [Handler] Number of log events:",
      logData.logEvents?.length || 0
    );

    if (!logData.logEvents || logData.logEvents.length === 0) {
      console.log("⚠️ [Handler] No log events found in the payload");
      return { statusCode: 200, body: "No log events" };
    }

    // Xử lý log events với stack trace grouping
    console.log(
      "🔄 [Handler] Starting to process log events with stack trace grouping..."
    );
    let processedCount = 0;
    let sentCount = 0;
    let errorCount = 0;

    let currentErrorStack = [];
    let processingError = false;

    for (const logEvent of logData.logEvents) {
      processedCount++;
      const logMessage = logEvent.message;
      console.log(
        `📄 [Handler] Processing event ${processedCount}:`,
        logMessage.substring(0, 200) + "..."
      );

      // Detect error line và stack trace
      // Detect error line với exclusion
      const isRealErrorLine =
        /(production\.ERROR|\.ERROR[: ]|\bERROR:|\bCRITICAL:|\bALERT:|\bEMERGENCY:)/i.test(
          logMessage
        );
      const isNginxKeepalive = /\[info\].*closed (keepalive )?connection/i.test(
        logMessage
      );
      const isErrorLine = isRealErrorLine && !isNginxKeepalive;
      const isStackTrace =
        logMessage.startsWith("Stack trace:") ||
        logMessage.startsWith("#") ||
        logMessage.includes("vendor/") ||
        logMessage.includes("/var/www/") ||
        logMessage.trim() === "";

      if (isErrorLine) {
        console.log(
          `🎯 [Handler] Found ERROR line: ${logMessage.substring(0, 100)}`
        );

        // Nếu đang xử lý error stack trước đó, gửi đi
        if (currentErrorStack.length > 0) {
          console.log(
            `📦 [Handler] Sending previous error stack with ${currentErrorStack.length} lines`
          );
          try {
            await sendErrorStack(currentErrorStack);
            sentCount++;
          } catch (err) {
            errorCount++;
            console.error(
              `❌ [Handler] Failed to send error stack:`,
              err.message
            );
          }
          currentErrorStack = [];
        }
        // Bắt đầu error stack mới
        currentErrorStack.push(logMessage);
        processingError = true;
        console.log(`🆕 [Handler] Started new error stack`);
      } else if (processingError && isStackTrace) {
        // Thêm stack trace vào error hiện tại
        currentErrorStack.push(logMessage);
        console.log(`📎 [Handler] Added stack trace line to current error`);
      } else {
        // Nếu đang xử lý error stack, gửi đi trước
        if (currentErrorStack.length > 0) {
          console.log(
            `📦 [Handler] Sending completed error stack with ${currentErrorStack.length} lines`
          );
          try {
            await sendErrorStack(currentErrorStack);
            sentCount++;
          } catch (err) {
            errorCount++;
            console.error(
              `❌ [Handler] Failed to send error stack:`,
              err.message
            );
          }
          currentErrorStack = [];
          processingError = false;
        }
        // Xử lý log bình thường
        console.log(`🔧 [Handler] Processing as single log`);
        try {
          await processSingleLog(logMessage);
          sentCount++;
          console.log(`✅ [Handler] Successfully sent single log`);
        } catch (err) {
          errorCount++;
          console.error(`❌ [Handler] Failed to send single log:`, err.message);
        }
      }
    }

    // Xử lý error stack cuối cùng (nếu còn)
    if (currentErrorStack.length > 0) {
      console.log(
        `📦 [Handler] Sending final error stack with ${currentErrorStack.length} lines`
      );
      try {
        await sendErrorStack(currentErrorStack);
        sentCount++;
      } catch (err) {
        errorCount++;
        console.error(
          `❌ [Handler] Failed to send final error stack:`,
          err.message
        );
      }
    }

    console.log(
      `📊 [Handler] Processing completed: ${processedCount} total, ${sentCount} sent, ${errorCount} errors`
    );
    return {
      statusCode: errorCount === 0 ? 200 : 207,
      body: JSON.stringify({
        processed: processedCount,
        sent: sentCount,
        errors: errorCount,
      }),
    };
  } catch (error) {
    console.error("💥 [Handler] Unhandled error:", error);
    console.error("💥 [Handler] Error stack:", error.stack);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: error.message,
        stack: error.stack,
      }),
    };
  }
};
