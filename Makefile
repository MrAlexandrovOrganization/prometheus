DOCKER_COMPOSE_BASE = docker compose --project-directory "$(CURDIR)"
include makefiles/compose.mk
DOCKER_COMPOSE = docker compose --project-directory "$(CURDIR)" $(COMPOSE_FLAGS)
DOCKER ?= docker
NET = prometheus-net

-include .env
export
include makefiles/versions.mk

up: init
	$(DOCKER_COMPOSE) up -d

init: network config-permissions

# The restricted SSH receiver uses umask 077. Only this public tracked config
# must be readable by the container's nobody user; private .env stays untouched.
config-permissions:
	chmod 0644 prometheus.yml

network:
	@if $(DOCKER) network inspect $(NET) >/dev/null 2>&1; then \
		echo "network $(NET) already exists"; \
	else \
		$(DOCKER) network create $(NET) --opt com.docker.network.driver.mtu=1376; \
	fi

directories:
	@mkdir -p $(MONITORING_DATA_DIR)/prometheus-targets

down:
	$(DOCKER_COMPOSE) down

logs:
	$(DOCKER_COMPOSE) logs -f

.PHONY: up down logs init network directories config-permissions

.PHONY: versions config-check
versions:
	@$(foreach v,$(VERSION_VARS),printf '%s=%s\n' '$(v)' '$($(v))';)
config-check:
	$(DOCKER_COMPOSE) --env-file /dev/null config --quiet --no-env-resolution
	$(DOCKER) run --rm --network none --entrypoint sh -i prom/prometheus:$(PROMETHEUS_VERSION) -c 'cat > /tmp/prometheus.yml; promtool check config /tmp/prometheus.yml' < prometheus.yml

.PHONY: check
check: config-check test

include makefiles/ci-deploy.mk

# Read-only validation of every tracked Compose combination, without runtime secrets.
.PHONY: compose-layout-check
compose-layout-check:
	$(DOCKER_COMPOSE_BASE) --env-file /dev/null -f compose/docker-compose.yml --profile '*' config --no-interpolate --no-env-resolution --quiet

check: compose-layout-check
