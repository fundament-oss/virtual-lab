_default:
    @just --list proxy-registries

start:
    docker compose up --detach

stop:
    docker compose down
