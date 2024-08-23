// https://stackoverflow.com/questions/16267339/s3-static-website-hosting-route-all-paths-to-index-html

function handler(event) {
  if (isBotAgent(event) || isCrawling(event)) {
    return {
      statusCode: 429,
      statusDescription: "Rate Limited",
    };
  }

  return routeToIndexPage(event);
}

function isBotAgent(event) {
  const pattern = new RegExp(
    "bot|ai|voltron|gpt|google|yahoo|bing|bytespider|omgili",
  );

  return pattern.test(
    event.request.headers["user-agent"]["value"].toLowerCase(),
  );
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

function isKnownCrawler(event) {
  
  return event.request.uri.includes("/maple/tap")
}

function isCrawling(event) {
  if (event.request.uri.includes("/maple/tap") || await kvsHandle.get(key)) {
    // trigger lambda
    return true
  }

  return false
}


// Cloudfront func calls lambda at edge to modify cloudfront kv store

import cf from 'cloudfront';
const kvsId = "a1b2c3d4-5678-90ab-cdef-EXAMPLE11111";
const kvsHandle = cf.kvs(kvsId);


