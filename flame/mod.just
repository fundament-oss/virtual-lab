_default:
    @just --list control

export VLAB_FLAME_VM_IMAGE    := "ghcr.io/metal-stack/mini-lab-vms:latest"
export VLAB_FLAME_SONIC_IMAGE := "ghcr.io/metal-stack/mini-lab-sonic:latest"

start: _obtain-role-requirements _prefetch_docker_images
    ansible-playbook \
       -i inventories/control-plane.yaml \
       control-plane.playbook.yaml \
       # --extra-vars "@.extra_vars.yaml"
    # TODO: start control partition (containerlab + ansible playbook)

    # image: ghcr.io/metal-stack/metal-deployment-base:${DEPLOYMENT_BASE_IMAGE_TAG}
    # container_name: deploy-control-plane
    # volumes:
    #   - /var/run/docker.sock:/var/run/docker.sock:z
    #   - .:/mini-lab
    #   # for developing role dependencies
    #   # TODO: make this a switch
    #   # - ${HOME}/.ansible/roles/ansible-common:/root/.ansible/roles/ansible-common:ro
    #   # - ${HOME}/.ansible/roles/metal-roles:/root/.ansible/roles/metal-roles:ro
    #   # - ${HOME}/.ansible/roles/metal-ansible-modules:/root/.ansible/roles/metal-ansible-modules:ro
    #   # - ${HOME}/git/github.com/metal-stack/helm-charts:/helm-charts:ro
    # environment:
    #   - ANSIBLE_CONFIG=/mini-lab/ansible.cfg
    #   - KUBECONFIG=/mini-lab/.kubeconfig
    #   - K8S_AUTH_KUBECONFIG=/mini-lab/.kubeconfig
    #   - CI=${CI}
    #   - DOCKER_HUB_USER=${DOCKER_HUB_USER}
    #   - DOCKER_HUB_TOKEN=${DOCKER_HUB_TOKEN}
    #   - GARDENER_ENABLED=${GARDENER_ENABLED:-}
    # network_mode: host
    # working_dir: /mini-lab
    # entrypoint:
    #   - /bin/bash
    #   - -ce
    #   - |
    #     ansible-playbook \
    #       -i inventories/control-plane.yaml \
    #       obtain_role_requirements.yaml
    #     ansible-galaxy install --ignore-errors -r requirements.yaml




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
# 	sleep 10
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
          name: .key,
          version: (env[(.key | ascii_upcase | gsub("-"; "_")) + "_VERSION"] // .value.version)
        })' \
      | yq -P > "$OUTPUT_FILE"

    ansible-galaxy install --ignore-errors -r requirements.yaml

_prefetch_docker_images:
    docker pull {{VLAB_FLAME_VM_IMAGE}}
    docker pull {{VLAB_FLAME_SONIC_IMAGE}}
