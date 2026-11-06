**Agent (reply to Priya, 09:31):** Yes, it was the api-server. My 09:10 answer was wrong: the workers were not OOM-killed and never restarted.

**Why the api-server was evicted:** node pool `general-b` ran out of memory. At 08:39 the invoice batch's PDF renderer was scheduled on node `general-b-7` and grew to 6.1 GiB of the node's 8 GiB; the renderer has no memory limit. The api-server requests only 256Mi, so under node memory pressure the kubelet evicts it first, at 08:41 and again at 08:47. One gap: the eviction log names the pool, not the node, so I have not confirmed the evicted api-server pods were on `general-b-7` itself.

**Worker memory bump:** not needed. Worker memory peaked at 410Mi of its 512Mi limit, so I withdraw the 512Mi to 1Gi change I proposed at 09:10.

**4.12 this afternoon:** safe with respect to this incident. It changes the pricing page copy and bumps the logging library, and touches none of the api-server, the renderer or the workers. It also does not fix the cause: the renderer still has no memory limit, so the next invoice batch can evict the api-server again whether or not 4.12 ships.

**Next:** I propose two changes before the next invoice batch: a memory limit on the PDF renderer, and a higher memory request for the api-server. Tell me whether to open them.
