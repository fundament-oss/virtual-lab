# virtual-lab

Hard fork of metal-stack/mini-lab. Will try to emulate/aproach the ideas of [MEP-18](https://metal-stack.io/docs/mep-18-autonomous-control-plane/) and eventually adding Fundament on top of that, while also using different tools (k3d, mise, just). To start, I moved everything to a subdirectory _mini-lab and slowly adding back in stuff to the root as needed. Done this way to start with a clean directory while also properly retaining git history and authorship of the original mini-lab.

I changed the name from `mini-lab` to `virtual-lab` to have a clear distinction when talking and thinking about them. Also because with MEP-18 I'm not sure you can call this 'mini' any longer... Oh and I maybe want to add some settings to allow for virtual partitions with a lot of nodes, I didn't get Framework Desktop at 128GB to self-host LLMs..

## Work in progress

Development has only just started, not nearly finished. Don't try to use this.

## Requirements

- docker
- docker compose
- [mise](https://mise.jdx.dev/getting-started.html)

## Initial setup

Run `mise trust` and `mise install` to trust and install the tools from `mise.toml`.

This lab uses [containerlab](https://containerlab.dev/). It's common to configure _TODO sshd config instructions_.

## Running the virtual-lab

Run `just help` to get introduced to the available commands in this lab. Run `just eveything` to start the virtual-lab completely.

## Layers

It's probably not helping that I'm using different terms than MEP-18. I had a hard time wrapping my head around the naming and the grouping of objects and just wanted to get some unique names that don't conflict with any other terminology or technology that is used.

- **spark**: The spark-layer is a simple 3-node k8s cluster which runs the control-planes for the flame-layer. MEP-18 calls this "K3s Standalone" and "Initial Cluster". The spark layer is not auto-healing.
- **flame**: The flame layer is an auto-healing metal partition that has it's control-planes (metal-stack and gardener) running on the spark cluster. The flame partition will run control-planes for the fire layer. MEP-18 calls this: "Initial Partition", "Target Cluster for metal-stack" and "Target cluster for Gardener".
- **fire**: Fire comprises of the control-planes and partitions for the actual workload clusters that are delivered to tenants. The control-planes for the fire layer run on top of the flame partition.

## Random thoughts

These are not helping Keeping It Simple, so I'll just write them down here and maybe they're fun to look at later...

### Cyclic Autonomous Control Plane

If there were two flame partitions, then they could manage and auto-heal eachother. The spark cluster would only be needed during initial setup or disaster recovery of the flame partitions. In practice, the control-planes for the fire layer would probably be ran on one of the two flame partitions. So the other flame partition can be very small and is just used to keep the first flame partition running.

1. Setup spark (which can be a single server w/ k3s or even the operator's laptop?)
1. Start control-planes for flameA-partition on spark
1. Start control-planes for flameB-partition on flameA-partition
1. Migrate control-plane for flameA-partition from spark to flameB-partition
1. Dismantle spark
1. Spin up control-planes for fire on flameA-partition

Second-day operations now manage all the hardware in the same way; no exception for running spark anymore. This is great, as long as everything keeps running......... If the flames go out... ..... Yeah... Hmm... This may be a terrible idea.

### Bonfire

Like `just fire`, but configured to be run from a diferent machine than the one where the flame is started. Allows others to join the fun! Just the partition that joins an existing fire controlplane? Or will it get it's own controlplane?
