**Agent (reply to Priya):** You're right, and my 09:10 message was wrong. The workers were never OOM-killed. The 5xx came from the api-server, which was evicted at 08:41 and 08:47.

**Why the api-server was evicted:** the invoice batch's PDF renderer was scheduled on node `general-b-7` at 08:39 and used 6.1 GiB of the node's 8 GiB. The renderer has no memory limit, so nothing stopped it. That put the `general-b` pool under node memory pressure. The api-server requests only 256Mi, so under pressure the kubelet evicts it first. One gap: the eviction log gives the node pool, not the node, so I haven't yet confirmed the evicted api-server pods were on `general-b-7` itself.

**Worker memory bump:** not needed. Worker memory peaked at 410Mi of its 512Mi limit and the workers ran without a restart all morning. Please drop the 512Mi to 1Gi change I proposed.

**4.12 this afternoon:** it's safe as far as this incident goes. It changes the pricing page copy and bumps the logging library, and touches none of the api-server, the renderer or the workers. It also doesn't fix anything: the next invoice batch can evict the api-server again until the renderer is limited.

**Proposed fix, not yet applied:**
1. Set a memory limit on the PDF renderer so it can't take over a node.
2. Raise the api-server's memory request above 256Mi so it isn't first in line for eviction.

Next I'll confirm which node the evicted api-server pods were on. Tell me whether you want the two fixes before the next invoice batch or bundled with 4.12.
