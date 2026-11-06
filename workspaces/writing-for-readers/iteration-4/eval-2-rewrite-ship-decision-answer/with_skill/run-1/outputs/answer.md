Yes, ship 4.12 today, as long as the `coupons_v2` flag stays off in production.

**Why it is safe:** of the release's three changes, only the new coupon logic carries risk, and
it sits behind `coupons_v2`, which is off in production. The other two are a copy update on the
pricing page and a logging library bump. The release passed all 1,284 unit tests and every
integration test except one. Staging has held a normal 0.2% error rate for the last 24 hours.

**The one open risk:** `checkout_flow_test.rb` failed once on the coupon path and passed on a
re-run. It is either a flaky test or a race condition in the coupon service, which this release
changes; one re-run cannot tell them apart. With the flag off, users never reach that path.

**Next:** ship today. Before anyone turns `coupons_v2` on, find out whether that failure is a
flaky test or a race; the coupon worker, the discount service and the promo engine all touch
this code, so the check covers all three. Tell me if you want me to investigate it.
