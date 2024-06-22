// https://stackoverflow.com/questions/16267339/s3-static-website-hosting-route-all-paths-to-index-html
export function handler(event) {
    const pattern = new RegExp("bot|ai|voltron|gpt|google|yahoo|bing|bytespider|omgili");

    let request = event.request;

    if (pattern.test(request.headers["user-agent"]["value"].toLowerCase())) {
        return {
            statusCode: 429,
        }
    }
    return request;
}
