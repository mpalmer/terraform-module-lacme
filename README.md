# L'ACME

> It's only a L'ACME certificate if it comes from the Lambda service of AWS.
> Otherwise, it's just sparkling X.509.

The purpose of L'ACME is to issue and renew SSL certificates via Let's Encrypt
(or any other ACME-using CA) using AWS Lambda functions.  The issued certificate
is stored in a DynamoDB table, and the private key can be stored (encrypted via
a KMS key) in the same table, or the whole cert+chain+key uploaded into an ACM
certificate for use in an ALB listener.

The configuration is all setup using Terraform, because it's the only sane way
to configure AWS resources.


## How?

To use L'ACME to issue and renew a certificate, you'll want to use the
Terraform module, like so:

```
module "cert" {
  source = "mpalmer/lacme"

  # You can pass in a different AWS provider here, perhaps one with
  # default_tags set to tag all the resources appropriately
  providers = {
    aws = aws
  }

  # This name is used to construct the various AWS resources used by the
  # L'ACME infrastructure.
  name = "some-cert"

  # The DNS names that you wish to issue the certificate for.  They all have
  # to be pointed at the same ALB listener for HTTP.
  certificate_names = ["www.example.com", "example.com"]

  # This is the ARN of the ALB listener that the HTTP name control verification
  # requests must come to in order for the certificate to be validated and issued.
  # It *must* be listening on port 80, and have all the names you listed in
  # certificate_names pointing to it.
  challenge_lb_listener_arn = <some ARN>

  # If you set this variable, then the private key will be stored in the
  # DynamoDB table in the `v` column under `k: "private_key"`, encrypted with
  # the KMS key you specify here and then base64-encoded.  Note that the key
  # policy for the KMS key must permit the role ARN in the module's
  # `lambda_role_arn` output to perform `kms:Encrypt`.
  kms_cmk_arn = <some KMS ARN>
}
```

If you want to use the managed certificate in an ALB listener (or anywhere else that
can use an ACM certificate), then the `acm_certificate_arn` module output will
come in handy.

If you've told L'ACME to store the (encrypted) private key in DynamoDB, you'll also
need something running in your TLS termination layer to grab the key from DynamoDB,
decrypt it with the KMS key, and store the cert/chain/key bundle in an appropriate
place on each instance.  It'll need to run on boot, and should also run at least once
per day, to ensure that renewed certificates are used in a timely fashion.

**NOTES** for your cert fetcher:

* Every certificate renewal will use a fresh private key, so ensure that your cert
  updater also fetches and decrypts the new private key as well.

* To ensure that you can never fetch a cert and different private key, the `private_key`
  item is removed before the new certificate is written, so if you try to fetch the
  private key and it is missing from DynamoDB, wait a second or two, then retry the
  fetch of both the `certificate` and `private_key` items.  If you want to be
  truly paranoid, you can acquire a lock on the `activity_lock` item; that'll
  guarantee that `certificate` and `private_key` won't change while you hold
  the lock.


### Optional Configuration

There are a couple of (very rare) cases where the following optional module parameters
may be useful.

* **`acme_directory_url`** -- The directory URL of the ACME server you wish to
  interact with.  The default is Let's Encrypt production.  If you wish to try
  against Let's Encrypt staging, or use another CA, you can use this variable
  to point somewhere else.

* **`cloudwatch_kms_key_id`** -- For the ultra-cautious amongst us, you may wish
  to encrypt your CloudWatch logs with a customer-managed key.  If so, set the
  KMS key ID of your desired key in this variable.

* **`challenge_listener_rule_priority`** -- The listener rule that intercepts
  requests to `/.well-known/acme-challenge/*` which is installed by L'ACME **must**
  have a higher priority (ie smaller number) than any listener rule that would
  handle the same requests.  The default value of this rule (42, because of course)
  should be low enough in most circumstances, however if you need to tweak the
  priority (either because you already *have* a listener rule with a priority of 42,
  or you have a covering listening rule at a higher priority than 42) then you can
  adjust the rule priority with this attribute.


## Why?

Given that AWS Certificate Manager can do all the certificate renewal magic for you
if you're terminating TLS on your ALBs, and certbot can get Let's Encrypt certs
for your EC2 instances, why is this a thing?

Well, there are occasional corner cases where these solutions won't work.  For
example:

* If you need an SSL certificate for a name, but you don't have enough
  control over DNS to setup the CNAME pointing to the ACM control validation
  record.

* You're running EC2 instances in an ASG, and the churn rate of your scaling
  group is such that getting individual certificates is rate-limit prohibitive.

* Your network policies are such that either your EC2 instances can't make
  HTTPS requests to the Internet (particularly the CA's ACME API) and/or the
  incoming HTTP validation requests won't make it to the EC2 instance running
  certbot.

There are other situations, too, where L'ACME can come in handy, no doubt.


## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for all those details.


# Licence

Unless otherwise stated, everything in this repo is covered by the following
copyright notice:

    Copyright (C) 2021  Matt Palmer <matt@hezmatt.org>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
