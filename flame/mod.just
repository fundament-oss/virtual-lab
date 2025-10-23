_default:
    @just --list control

export VLAB_FLAME_VM_IMAGE    := "ghcr.io/metal-stack/mini-lab-vms:latest"
export VLAB_FLAME_SONIC_IMAGE := "ghcr.io/metal-stack/mini-lab-sonic:latest"

start: _obtain-role-requirements _gen-certs _control-plane _partition

_control-plane:
    # TODO: fail if spark/kubeconfig doesn't exist.
    KUBECONFIG=../spark/kubeconfig ansible-playbook \
       -i inventories/control-plane.yaml \
       control-plane_metal.playbook.yaml \
       # --extra-vars "@.extra_vars.yaml"

    KUBECONFIG=../spark/kubeconfig ansible-playbook \
        -i inventories/control-plane.yaml \
        control-plane_gardener.playbook.yaml \
        # --extra-vars "@.extra_vars.yaml"
    #
    #   - ANSIBLE_CONFIG=/mini-lab/ansible.cfg
    #   - KUBECONFIG=/mini-lab/.kubeconfig
    #   - K8S_AUTH_KUBECONFIG=/mini-lab/.kubeconfig
    #   - CI=${CI}
    #   - DOCKER_HUB_USER=${DOCKER_HUB_USER}
    #   - DOCKER_HUB_TOKEN=${DOCKER_HUB_TOKEN}
    #   - GARDENER_ENABLED=${GARDENER_ENABLED:-}
    #
    # The docker-compose mounted the helm charts, what for? find out and maybe fix my aproach
    # # volumes:
    # #   - ${HOME}/git/github.com/metal-stack/helm-charts:/helm-charts:ro

_partition: _external-network
    docker pull {{VLAB_FLAME_VM_IMAGE}}
    docker pull {{VLAB_FLAME_SONIC_IMAGE}}
    echo "TODO containerlab up"
    #	@if ! sudo $(CONTAINERLAB) --topo $(LAB_TOPOLOGY) inspect | grep -i leaf01 > /dev/null; then \
    #	# sudo --preserve-env $(CONTAINERLAB) deploy --topo $(LAB_TOPOLOGY) --reconfigure && \
    #	# ./scripts/deactivate_offloading.sh; fi
    echo "TODO ansible partition"
    # docker compose up --remove-orphans --force-recreate partition

_external-network:
    echo "TODO external_network"

# up: env gen-certs control-plane-bake partition-bake
# 	@chmod 600 files/ssh/id_rsa
# 	docker compose up --abort-on-container-failure --remove-orphans --force-recreate control-plane partition
# 	@$(MAKE)	--no-print-directory	start-machines
# # for some reason an allocated machine will not be able to phone home
# # without restarting the metal-core
# # TODO: should be investigated and fixed if possible
# 	sleep 10
# 	ssh -F files/ssh/config leaf01 'systemctl restart metal-core'
# 	ssh -F files/ssh/config leaf02 'systemctl restart metal-core'
# # TODO: for community SONiC versions > 202311 a bgp restart is needed in the virtual environment
# 	sleep 15
# 	ssh -F files/ssh/config leaf01 'systemctl restart bgp'
# 	ssh -F files/ssh/config leaf02 'systemctl restart bgp'

_obtain-role-requirements:
    #!/usr/bin/env bash
    set -euo pipefail

    METAL_STACK_RELEASE_VERSION="${METAL_STACK_RELEASE_VERSION:?Missing METAL_STACK_RELEASE_VERSION}"
    RELEASE_VECTOR_URL="https://raw.githubusercontent.com/metal-stack/releases/${METAL_STACK_RELEASE_VERSION}/release.yaml"
    OUTPUT_FILE="requirements.yaml"

    echo "Downloading release vector from ${RELEASE_VECTOR_URL} ..."
    curl -sSL "${RELEASE_VECTOR_URL}" \
      | yq -o=json '.["ansible-roles"]' \
      | jq 'to_entries | map({
          src: .value.repository,
          name: ("metal-stack." + .key),
          version: (env[(.key | ascii_upcase | gsub("-"; "_")) + "_VERSION"] // .value.version)
        })' \
      | yq -P > "$OUTPUT_FILE"

    ansible-galaxy install --ignore-errors -r requirements.yaml

# Generate TLS certificates for metal-stack components (use 'just gen-certs force' to regenerate)
_gen-certs force="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -z "{{force}}" ] && [ -f "files/certs/ca.pem" ]; then
        echo "Certificates already exist, skipping generation"
        exit 0
    fi

    echo "Generating certificates..."
    cd files/certs

    # Clean up any existing certs
    rm -f *.pem **/*.pem **/*.crt

    # Generate CA certificate
    echo "Generating CA cert"
    cfssl genkey -initca ca-csr.json | cfssljson -bare ca
    rm -f *.csr

    # Generate component certificates
    for component in grpc masterdata-api; do
        pushd $component > /dev/null
        echo "Generating $component certs"

        if [ -f "server.json" ]; then
            cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=client-server server.json | cfssljson -bare server
        fi

        if [ -f "client.json" ]; then
            cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=client client.json | cfssljson -bare client
        fi

        rm -f *.csr
        popd > /dev/null
    done

    # Generate NSQ cert with concatenated format
    pushd nsq > /dev/null
    echo "Generating nsq certs"
    cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=client-server client.json | cfssljson -bare client
    cat client.pem client-key.pem > client.crt
    rm -f *.csr
    popd > /dev/null

    echo "Certificate generation complete"
