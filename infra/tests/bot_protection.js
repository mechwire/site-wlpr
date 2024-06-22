import { test } from "uvu";
import * as assert from 'uvu/assert';
import { handler } from "../cloudfront_functions/bot_protection.js";

// https://www.foundationwebdev.com/2023/11/which-web-crawlers-are-associated-with-ai-crawlers/
const agents = [ "GoogleBot", "voltron", "CCBot", "ChatGPT-User", "GPTBot", "Google-Extended", "anthropic-ai", "ClaudeBot", "Omgilibot", "Omgili", "FacebookBot", "Diffbot", "Bytespider", "ImagesiftBot", "cohere-ai", "GoogleOther", "ImagesiftBot", "PerplexityBot"];

test("handler", () => {
	assert.type(handler, "function");

	for (let agent of agents) {
		assert.is(handler({
			"request": {
				"headers": {
					"user-agent": {
						"value": agent,
					}
				}
			}

		}).statusCode, 429);
	}
});

test.run();