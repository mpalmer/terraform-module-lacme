The tests in this directory are "active" end-to-end tests, that do Real Things
to Real AWS Resources.  This might end up costing you a few cents, or -- if
things go really wrong and you don't clean up afterwards -- a fair bit more.
**Consider yourself warned**.

In order to run the tests, you will need:

* a working `bash`;

* The AWS CLI;

* Terraform and the rest of the tools listed in `.tool-versions` in the repo root;

* An AWS account;

* Fairly broadly-scoped permissions into said AWS account, with creds for
  that role/user in the standard environment variables;

* A public Route53 DNS zone in the aforementioned AWS account that is
  appropriately delegated to (that is, public DNS queries for names in the
  zone will be handled by that zone).  This zone will have names (temporarily)
  added to it, and (staging) Let's Encrypt certificates (hopefully) issued
  for names in that zone; and

* The `TF_VAR_route53_zone_id` environment variable set to the zone ID of the above
  Route53 DNS zone.

To run each test, `cd` into the directory and run `./run`.  If everything goes
successfully, all resources created by Terraform *should* be destroyed before
the test terminates, but if the test fails, all bets are off -- we'll do what
we can, but failing tests are notoriously unpredictable.

The currently-implemented tests are:

* `001_core` -- exercises the fundamental features of the module, of
  successfully issuing a certificate.
