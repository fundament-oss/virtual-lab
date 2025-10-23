
help:
    @echo '\
    Welcome to virtual-lab. To start everything everywhere all at once, run `just everything`. \
    '
    @just --list

export METAL_STACK_RELEASE_VERSION := "develop" # From: inventories/group_vars/all/images.yaml, should maybe be in a global config or instantiation?

init:
    docker network inspect vlab-spark >/dev/null 2>&1 || docker network create vlab-spark


# Docker registry proxies
mod proxy-registries
# The spark-layer
mod spark
# The flame-layer
mod flame
# The fire-layer
# mod fire

# Start the complete virtual-lab
everything:
    just proxy-registries start
    just spark start
    just flame start
    # just flame start
    # just fire start
