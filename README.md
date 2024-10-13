
# AWS Transfer Playground

This repo contains a few examples that are just me learning and playing around with a b.

AWS Transfer is both kind of cool, and kind of a pain.

There's lots of different ways to set it up, but I'm going to walk through just a few that I want to explore.

## Fully Managed

This will be fully, 100% managed by AWS.  It will have:

* Public endpoint. This disalllows attaching a SG to it.
* Only support SFTP
* AWS Manages users. This limits you to _only_ keys.

## Fully Managed, Private

Same as above but with an endpoint in a VPC. This allows attaching a SG for whitelisting IP's.

## Lambda for Authentication (Secrets)

If you want to allow people to use passwords, you need to handle it yourself.  Essentailly, Transfer calls a Lambda, and that Lambda can do whatever you want it to.

In this case, it'll use AWS Secret Manager.  This could get expensive, but in a playground environemnt it's not a huge deal.

## API Gateway -> WAF -> Lambda

One of the downfalls of the previous is that, as far as I know, there is no limit to login attempts.  Each login attempt invokes the Lambda.  So... that could get expenisve.

One way around this (maybe the only way?) is to have AWS Transfer use an API Gateway, and have that API gateway call a Lambda.  In this instance, the only advantage, that I know of, is that you can attach a WAF to it.  Of course, if you already have an API Gateway that you use, this could slide right in.

## API Gateway -> WAF -> An Application

I'm not 100% sure this will work yet, however, I think you could avoid the Lambda altogether and have the API Gateway just call your applicaiton to manage users.