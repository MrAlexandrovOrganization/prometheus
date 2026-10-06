# Prometheus

Версия образа задаётся в `versions.mk`; `make versions` показывает её.
Make экспортирует значение в Compose. CI вызывает `make config-check`.

- `make config-check` — валидация Compose; задайте тестовый `MONITORING_DATA_DIR`.
- `make up` / `make down` / `make logs` — управление стеком.

При проверках используйте синтетические настройки и checkout без `.env`.
Запускайте Compose через Make, чтобы не дублировать версию образа.

## Caddy

Job `caddy` опрашивает `caddy-metrics:9180/metrics` каждые 15 секунд через
отдельную внутреннюю external-сеть `caddy-metrics-net`, которой владеет Compose
`infra/network/caddy`. Перед первым запуском Prometheus должен быть поднят Caddy.
Приложения не используют эту сеть для ingress. Caddy не подключён к общей
`prometheus-net`. Порт метрик не опубликован на VM, Caddy admin API остаётся локальным.

Проверка: `up{job="caddy"}`; HTTP-коды есть на
`caddy_http_request_duration_seconds_count`, задержки — на соответствующей
гистограмме. Запросы проверены также через datasource proxy Grafana.
Изменение prometheus.yml валидировать `promtool check config`, затем применять
SIGHUP к Prometheus. Изменения Compose-сетей должны быть применены отдельно.
