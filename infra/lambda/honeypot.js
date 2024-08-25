"use strict";

// https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/cloudfront-keyvaluestore/
// https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/cloudfront-keyvaluestore/command/GetKeyCommand/
// network calls: https://aws.amazon.com/blogs/networking-and-content-delivery/leveraging-external-data-in-lambdaedge/

require("@aws-sdk/signature-v4-crt");

const {
  CloudFrontKeyValueStoreClient,
  GetKeyCommand,
  PutKeyCommand,
  DescribeKeyValueStoreCommand,
  DeleteKeyCommand,
} = require("@aws-sdk/client-cloudfront-keyvaluestore");

const client = new CloudFrontKeyValueStoreClient();

const OneDayInMilliseconds = 24 * 60 * 60 * 1000;

// When we use Terraform to zip the lambda, this gets injected.
const KvsARN = "${kvs_arn}";

// https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-event-structure.html#lambda-event-structure-response
// https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-examples.html#lambda-examples-generated-response-examples
exports.handler = async (event, context, callback) => {
  return callback(null, await createResponse(event.Records[0].cf));
};

async function createResponse(cf) {
  const request = cf.request;
  const response = cf.response;

  const uri = request.uri.toLowerCase();

  let etag;
  try {
    etag = await getETag();
  } catch (_) {
    return response;
  }

  if (uri.startsWith("/maple/tap") || uri.endsWith(".php")) {
    response.statusDescription = "After Start / End";
    try {
      await addOrUpdateIP(etag, request.clientIp);
    } catch (err) {
      response.statusDescription = "After Start / End" + err;
      return response;
    }
    response.status = 429;
    response.statusDescription = "Too Many Requests";
    return response;
  }

  // If the IP isn't known, return
  let lastTriggeredDate;
  try {
    lastTriggeredDate = await getLastTriggeredDate(etag, request.clientIp);
  } catch (ResourceNotFoundException) {
    return response;
  }

  // If the IP is known, and 7 days have passed, remove it
  if (!wasTriggeredInTheLastXDays(lastTriggeredDate, 7)) {
    try {
      await removeIP(etag, request.clientIp);
    } catch (_) {
      return response;
    }
  }

  return response;
}

async function getETag() {
  const command = new DescribeKeyValueStoreCommand({
    KvsARN: KvsARN,
  });
  const { ETag } = await client.send(command);
  return ETag;
}

async function getLastTriggeredDate(ip) {
  const command = new GetKeyCommand({
    KvsARN: KvsARN,
    Key: ip,
  });
  const { Value } = await client.send(command);
  return Date.Parse(Value);
}

async function addOrUpdateIP(etag, ip) {
  const command = new PutKeyCommand({
    KvsARN: KvsARN,
    Key: ip,
    Value: new Date().toISOString(),
    IfMatch: etag,
  });
  await client.send(command);
}

async function removeIP(etag, ip) {
  const command = new DeleteKeyCommand({
    KvsARN: KvsARN,
    Key: ip,
    IfMatch: etag,
  });
  await client.send(command);
}

function wasTriggeredInTheLastXDays(dateTriggered, days) {
  return (dateTriggered - new Date()) / OneDayInMilliseconds <= days;
}
