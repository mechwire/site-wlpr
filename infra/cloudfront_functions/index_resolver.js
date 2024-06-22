// https://stackoverflow.com/questions/16267339/s3-static-website-hosting-route-all-paths-to-index-html
function handler(event) {
  var userAgent = event.request.headers["user-agent"];

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
