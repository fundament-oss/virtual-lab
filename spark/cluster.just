# TODO: inline back into spark/mod.just? Is it useful to have the `cluster` submodule? Probably spark is simple enough to keep it flat?
# But also; align UX with control an delivery modules.

_default:
    @just --list spark cluster

# TODO: if we go for instantiating, then "vlab-${id}-spark" or smth.
# TODO: Is `vlab-` a good prefix? Want it to be short, and also applicable in all virtualization tools and layers (k3d, containerlab)
cluster_name := "vlab-spark"

# Start the k3d cluster, create the cluster if it doesn't exist yet.
start:
    #!/usr/bin/env bash
    CLUSTER_EXISTS=$(k3d cluster list "{{cluster_name}}" --no-headers | wc -l | xargs)
    if [ $CLUSTER_EXISTS -eq 0 ]; then
            k3d cluster create "{{cluster_name}}" --config k3d.yaml
    else
            k3d cluster start "{{cluster_name}}"
    fi
    k3d kubeconfig get "{{cluster_name}}" > kubeconfig

# Stop the k3d cluster
stop:
    k3d cluster stop "{{cluster_name}}"

# Delete the k3d cluster
delete:
    k3d cluster delete "{{cluster_name}}" --config k3d.yaml # TODO: pass this the kubeconfig as well so it can cleanup (we'll cleanup as well, but if we make k3d happy about cleaning up itself then it wont give a warning..)

# Run kubectl against the spark cluster
kubectl *ARGS:
    # TODO: add detection whether cluster is started.
    @KUBECONFIG=./kubeconfig kubectl {{ARGS}}

# Run k9s against the boostrap cluster
k9s *ARGS:
    # TODO: add detection whether cluster is started.
    @KUBECONFIG=./kubeconfig k9s {{ARGS}}

# TODO: maybe instead have a `just spark cluster kubecontext <ARGS>` that can be used to run kubectl/k9s/helm/whatever.
# Or just have everyone expect spark/kubeconfig to be the kubeconfig for the spark cluster.
