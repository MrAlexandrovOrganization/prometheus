DOCKER_COMPOSE = docker compose
DOCKER ?= docker
NET = prometheus-net

-include .env
export
include versions.mk

up: init
	$(DOCKER_COMPOSE) up -d

init: network directories

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

.PHONY: up down logs init network directories

.PHONY: versions config-check
versions:
	@$(foreach v,$(VERSION_VARS),printf '%s=%s\n' '$(v)' '$($(v))';)
config-check:
	$(DOCKER_COMPOSE) --env-file /dev/null config --quiet --no-env-resolution
