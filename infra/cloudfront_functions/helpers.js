export function isBot(event) {
  const pattern = new RegExp(
    "bot|ai|voltron|gpt|google|yahoo|bing|bytespider|omgili",
  );

  let request = event.request;

  return pattern.test(request.headers["user-agent"]["value"].toLowerCase());
}

export function routeToIndexPage(event) {
  // Check whether the URI has a file extension.
  if (uri.includes(".")) {
    return request;
  }

  if (!uri.endsWith("/")) {
    request.uri += "/";
  }

  // Check whether the URI is missing a file name.
  if (uri.endsWith("/")) {
    request.uri += "index.html";
  }

  return request;
}
