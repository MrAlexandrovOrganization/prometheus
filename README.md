# Prometheus

Версия образа задаётся в `makefiles/versions.mk`; `make versions` показывает её.
Make экспортирует значение в Compose. CI вызывает `make config-check`.

- `make config-check` — валидация Compose; задайте тестовый `MONITORING_DATA_DIR`.
- `make up` / `make down` / `make logs` — управление стеком.

При проверках используйте синтетические настройки и checkout без `.env`.
Запускайте Compose через Make, чтобы не дублировать версию образа.

## Центральное хранилище на WSL

Prometheus принимает remote write от локального vmagent каждого из шести хостов
на `/api/v1/write`. Alloy передаёт метрики в vmagent на том же хосте.
Сборщики сами опрашивают локальные exporters и файлы `prometheus-targets`,
а vmagent сохраняет очередь в отдельном постоянном томе и досылает её после
штатного перезапуска. Размер очереди рассчитан на сутки текущего потока с запасом,
ограничение задаётся байтами, а не TTL. Центр не дублирует scrape.
Хранение явно ограничено 15 днями. Порт 9090 опубликован только на loopback;
удалённым сборщикам он доступен через Tailscale Serve, без публичного ingress.

`storage.tsdb.out_of_order_time_window: 26h` разрешает приём запоздавших samples,
когда другие хосты уже продвинули TSDB head. Это окно приёма, а не срок хранения.
Очередь старше окна может быть отвергнута; не увеличивать её срок без согласования
с приёмником и памятью TSDB. vmagent использует стандартный Prometheus remote
write protocol. Проверка replay находится в Alloy: `make test` запускает
изолированную цепочку и проверяет timestamp 23 часа назад после пересоздания
сборщиков. Полные сутки отказа и внезапное отключение питания этим не проверяются.

Перед переносом остановить старый Prometheus и скопировать весь named volume,
включая WAL и head chunks, в новый volume с тем же именем. Старый volume сохранить
для отката. Включать новый экземпляр только после завершения копирования.

`make init` выставляет `0644` только публичному версионируемому `prometheus.yml`,
чтобы non-root контейнер мог читать файл после checkout через SSH receiver с
umask 077. Приватный `.env` и права тома этим не изменяются.


## Автодеплой

После проверок push в `main` доставляет точный проверенный SHA на WSL через
SSH jump host Hostkey Russia. `make ci-deploy` запускает транспорт; `make deploy`
пересоздаёт сервис и выполняет `make smoke`. PR только проверяются. Ручной запуск
workflow доступен для main. `DEPLOY_ENABLED` управляет включением доставки.
Ключ репозитория ограничен этим проектом; `DEPLOY_SSH_KEY` хранится в Secrets,
проверенные SSH host keys — в переменной `DEPLOY_KNOWN_HOSTS`. Старые `VM_*`
secrets не используются. `.env` и named volumes остаются на хосте.

Доступ/установка receiver, блокировки, отказы и повторный запуск описаны в
[инструкции доставки Alloy](https://github.com/MrAlexandrovOrganization/alloy/blob/main/DEPLOY.md).
Для тестов использовать `make test`; `make check` также валидирует конфигурацию.

## Container names

Compose uses explicit service names without replica numbers. Set
`CONTAINER_NAME_PREFIX` (for example `dev-`) for an additional local or CI stack
on the same Docker host. Keep Compose project/service labels and volume names
unchanged; clients address services or explicit network aliases.
