import cf from "cloudfront";

// This fails if there is no key value store associated with the function
const honeypotKVSHandle = cf.kvs();

// https://stackoverflow.com/questions/16267339/s3-static-website-hosting-route-all-paths-to-index-html
async function handler(event) {
  if (isBot(event) || (await isCrawling(event))) {
    return {
      statusCode: 429,
      statusDescription: "Rate Limited",
    };
  }

  return routeToIndexPage(event);
}

function isBot(event) {
  const pattern = new RegExp(
    "bot|ai|voltron|gpt|google|yahoo|bing|bytespider|omgili",
  );

  return pattern.test(
    event.request.headers["user-agent"]["value"].toLowerCase(),
  );
}

// https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/example-function-key-value-pairs.html

async function isCrawling(event) {
  return await honeypotKVSHandle.exists(event.viewer.ip);
}

function routeToIndexPage(event) {
  // Check whether the URI has a file extension.
  let request = event.request;

  if (event.request.uri.includes(".")) {
    return request;
  }

  if (!event.request.uri.endsWith("/")) {
    request.uri += "/";
  }

  // Check whether the URI is missing a file name.
  if (event.request.uri.endsWith("/")) {
    request.uri += "index.html";
  }

  return request;
}
