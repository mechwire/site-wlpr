---
title: Making a secure-enough blog-writing page
createdDt: 2024-05-29
publishedDt: 2024-05-29
updatedDt: 2024-05-30
description: "Integrating Github Actions, Terraform, and AWS"
tags: ["infra", "terraform", "github", "github.actions"]
---


## Making a blog backend


* Use Dynamodb. because costs and it is a document.
* Fit a specific schema


DynamoDB
https://aws.amazon.com/blogs/database/implementing-version-control-using-amazon-dynamodb/
table: blog_posts
* Key is UUID
* Partition key is updatedAt
* structure:
* title, created, updated, published, contentUpdatedDt, content, description, tags


table: in theory, every post has an active draft...
* make a diff of the blog post
* key is also UUID


* What if we save published versions of each?






* DNS payment considerations
* 

One of the things I wanted was the ability to write posts in a clean UI, wherever I was. My initial thought was "can we restrict this via IP or MAC address or Device ID" but it didn't seem tenable for reasons:

## Requirements

1. The page should only be accessible via a obscure URL, where it's obscure due to the probability of guessing.
    a. Accessing the page and making changes should create a new entry 
2. The page should be accessible via a semantic ID, e.g. "apple banana orange" not "asd89s9f 3hkj342 sas90df8".
3. The 


### Development Process


Inspirations:
* Cryptography! a la seed phrases.
* Bitwarden




Instead, I decided to some liberties using obfuscation and probability. Put another way, what if I randomly generate the URL I can write to? If there are more than a certain number of failures, we can simply change the ID.

UUIDs fit the bill perfectly for security-through-obfuscation, and the entropy for UUID v4 is high. Still, UUIDs are difficult to type and remember, as they are case-sensitive and not English words.

The other requirement I had was a semantic ID. I enjoy going to coffee shops and frequently, my brain finishes processing an inconsistency. I would like to make the note where it's most relevant, which is the post itself.

To generate a semantic ID, I looked at a few packages, but it wasn't clear to me how high I could expect the entropy to be, and the packages were quite old. Once I realized it was just a matter of probability, I just had to make my own.

First, the source of words:
* Pokemon. There are 151 alone in Gen 1.
* Varying length. 


What about passkeys or an actual auth server?
* I don't want to accept writes.


How secure does it need to be?
This is a variation of the link-shortener architecture issue. I reviewed it via ByteByteGo, but a few issues remain:
* Only a handful of links should ever exist
* ByteByteGo optimizes or no-collisions, which is part of my issue, but primarily I want to reduce the risk of someone getting it right + someone spamming me and me paying for costs.
* Versioning scheme. Let's say someone gets it right and they make changes to a post. What should happen?






Probability-wise, 
