/* WAF

https://systemweakness.com/aws-waf-with-terraform-1dafa305c4a1
https://badshah.io/things-i-wish-i-knew-aws-waf-bot-control/

I was going to use WAF, but a few issues came up:
   * I had a hard time setting up bot protection. Out of the box, it would either count or do nothing; it wasn't clear to me how to actually block. In trying to figure that out, I discovered more, like...
   * Bot protection was relatively cheap. But ACLs for WAF (which enable Bot Protection) were a relatively high fixed cost of $5/mo + $1/rule.
   * Cloudfront's Free Tier is 10M per month. After that, the most expensive regions are $0.016/10k. So to doing things the right way:
       * Flat, Monthly ACL Cost: ACL + 1 Rule for Rate Limiting + 1 Rule for Bot protection = $7/mo.
       * Cloudfront Traffic Needed to get to $7: roughly 10M/mo.
           * (Free Tier Requests) + (Flat, Monthly ACL Cost)/(per 10k Cost of most expensive geography, South America)*(10,000) or (10M + $7/($0.016)*10k)
Instead, the cheapest solution here is likely alerting.
*/


resource "aws_cloudfront_key_value_store" "lambda_honeypot" {
  name    = "${var.repository_name}_honeypot"
  comment = "This stores IPs that have accessed the honeypot link"
}
