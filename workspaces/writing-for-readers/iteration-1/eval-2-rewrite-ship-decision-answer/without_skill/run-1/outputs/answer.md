**Yes, ship 4.12 today, with `coupons_v2` kept off in production.**

The only risk I found is in the new coupon logic, and that logic is behind `coupons_v2`, which is off.
Users can't reach it until someone turns the flag on.

**Before anyone turns `coupons_v2` on:** find out why `checkout_flow_test.rb` failed on the coupon
code path. It failed once in CI and passed on a re-run. That could be a flaky test, or a real race
condition in the coupon service, which this release changes. The coupon worker, discount service and
promo engine all touch this code, so a race here could show up in any of them.

What I checked:

| Check | Result |
| --- | --- |
| Unit tests | All 1,284 passed |
| Integration tests | All passed except the one coupon failure above, which passed on re-run |
| Other changes in the release | Pricing page copy update; logging library dependency bump |
| Staging error rate, last 24 hours | Stable at about 0.2%, which is normal |

The verdict depends on one assumption I did not verify: that every coupon-service change in this
release runs only when `coupons_v2` is on. If any of it runs with the flag off, the failing test
applies to today's release, and it should be investigated before shipping.
