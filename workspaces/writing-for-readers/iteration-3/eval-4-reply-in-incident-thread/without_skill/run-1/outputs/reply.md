**Agent (reply to Priya, 09:31):** You're right, and my 09:10 answer was wrong: the workers never restarted, so they didn't cause this. Here's what I see now.

**Was it the api-server?** Most likely. Its pods were evicted at 08:41 and 08:47, both inside the 08:40–08:55 spike. I haven't yet tied the 5xx responses to those pods directly (by request logs or traces), so treat this as a strong timing match, not proof.

**Why was it evicted?** The eviction log gives the reason as "node memory pressure" on node pool `general-b`. At 08:39 the invoice batch's PDF renderer was scheduled on `general-b-7` and used 6.1 GiB of that node's 8 GiB. The renderer has no memory limit, so nothing stopped it. The api-server requests only 256Mi, so under pressure the kubelet evicts it first. One gap: I've confirmed the pool, but not yet that the evicted api-server pods were on `general-b-7` itself.

**Do we still need the worker memory bump?** No. Workers peaked at 410Mi of their 512Mi limit and ran all morning without a restart. I'm withdrawing that recommendation.

What would prevent a repeat instead:
1. Set a memory limit on the PDF renderer, so it gets OOM-killed itself instead of starving the node.
2. Raise the api-server's memory request toward its real usage, so it isn't first in line for eviction.

I haven't sized either number yet; I can pull the renderer's and api-server's usage history and propose values.

**Is 4.12 safe to deploy this afternoon?** Yes, as far as this incident goes. It changes the pricing page copy and bumps the logging library; it doesn't touch the api-server, the renderer or the workers, so it neither fixes nor worsens this. The risk that remains is separate from 4.12: until the renderer has a limit, the next invoice batch can cause the same evictions.

Next I'll check which node the evicted api-server pods ran on and match the 5xx to them, and post the result here.
