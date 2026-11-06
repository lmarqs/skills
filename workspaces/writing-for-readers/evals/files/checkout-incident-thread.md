# #inc-checkout thread (fictional)

**Priya (SRE lead, 09:02):** Checkout 5xx spiked from 08:40 to 08:55. What happened?

**Agent (09:10):** The spike came from the worker pods: they were OOM-killed during the 08:40
batch of invoice jobs, and checkout requests that enqueue invoices failed while the workers
restarted. Raising the worker memory limit from 512Mi to 1Gi should prevent it.

**Priya (09:31):** I checked the eviction log you linked. Only the api-server pods were
evicted, at 08:41 and 08:47; the workers never restarted. So was it the api-server, and why
did it get evicted? Also, do we still need the worker memory bump, and is it safe to deploy
4.12 this afternoon?

## What the agent has found since 09:31

- Eviction log: api-server pods evicted at 08:41 and 08:47 with reason "node memory pressure"
  on node pool `general-b`. Worker pods ran without restart all morning.
- Node `general-b-7` had the invoice batch's PDF renderer scheduled on it at 08:39; the
  renderer used 6.1 GiB on an 8 GiB node. It has no memory limit set.
- The api-server's memory request is 256Mi, so the kubelet evicts it first under pressure.
- Worker memory peaked at 410Mi of its 512Mi limit.
- Release 4.12 changes the pricing page copy and bumps the logging library. It does not touch
  the api-server, the renderer or the workers.
