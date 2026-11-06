Yes, it was the api-server. My 09:10 answer was wrong: the workers were not OOM-killed and ran all morning without a restart.

**Why the api-server was evicted:** the invoice batch's PDF renderer was scheduled on node `general-b-7` at 08:39 and grew to 6.1 GiB of the node's 8 GiB, because it has no memory limit. Under that node memory pressure, the kubelet evicted the api-server pods at 08:41 and 08:47; their 256Mi memory request puts them first in line for eviction.

**Worker memory bump:** not needed. Workers peaked at 410Mi of their 512Mi limit, so I withdraw that recommendation.

**4.12 this afternoon:** safe as far as this incident goes. It changes the pricing page copy and the logging library, and touches neither the api-server, the renderer nor the workers. It also does not fix the cause, so the next invoice batch can evict the api-server again.

**Next:** set a memory limit on the PDF renderer and raise the api-server's memory request, before the next invoice batch. Should I open both changes?
