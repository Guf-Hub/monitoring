# Мониторинг приложений: Loki + Promtail + Prometheus + Grafana

## Состав

- **Loki** — сбор и хранение логов
- **Promtail** — агент для отправки логов в Loki (читает логи Docker и системные)
- **Prometheus** — сбор метрик
- **Grafana** — визуализация логов и метрик

## Открытые порты сервисов

- **Grafana**: `3000:3000` — веб-интерфейс для просмотра дашбордов (доступен снаружи)
- **Loki**: порт не проброшен наружу (API нужен только для Promtail и Grafana внутри сети)
- **Prometheus**: порт не проброшен наружу (веб-интерфейс только для локального доступа или через Grafana)
- **Node-exporter**: порт не проброшен наружу (метрики ОС собираются Prometheus внутри сети)
- **Promtail**: порт не проброшен (агент для сбора логов)

> **Рекомендация:** Открывайте наружу только Grafana. Остальные сервисы доступны только внутри Docker-сети для безопасности.

## Как запустить

1. Перейдите в папку monitoring:
   ```bash
   cd monitoring
   ```
2. Запустите мониторинг:
   ```bash
   docker compose up -d
   ```
3. (Рекомендуется) Установите node_exporter на сервере для сбора метрик ОС:
   ```bash
   docker run -d --name node-exporter -p 9100:9100 --net=monitoring prom/node-exporter
   ```
4. Откройте Grafana: http://<IP_СЕРВЕРА>:3000 (логин/пароль: admin/admin)

## Как это работает

- Promtail собирает логи всех контейнеров Docker и системные логи, отправляет их в Loki.
- Prometheus собирает метрики с node_exporter и других endpoint'ов.
- Grafana подключается к Loki и Prometheus для визуализации.

## Как добавить мониторинг своих приложений

- Для логов: убедитесь, что ваши приложения пишут логи в stdout/stderr (Docker) или в файлы в /var/log.
- Для метрик: добавьте endpoint /metrics в приложение (формат Prometheus) или используйте node_exporter.
- Добавьте нужные targets в prometheus.yml.

## Telegram-уведомления о состоянии сервера и сбоях

- Для отправки сводки и критических ошибок в Telegram используйте отдельный Python-скрипт (пример ниже).
- Скрипт можно запускать по cron или как отдельный сервис.

### Пример скрипта для отправки сводки в Telegram

```python
import psutil
import requests

def send_telegram(message, token, chat_id):
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = {"chat_id": chat_id, "text": message}
    requests.post(url, data=data)

def get_server_summary():
    mem = psutil.virtual_memory()
    cpu = psutil.cpu_percent(interval=1)
    disk = psutil.disk_usage('/')
    return (
        f"RAM: {mem.percent}% ({mem.used//1024//1024}MB/{mem.total//1024//1024}MB)\n"
        f"CPU: {cpu}%\n"
        f"Disk: {disk.percent}% ({disk.used//1024//1024//1024}GB/{disk.total//1024//1024//1024}GB)"
    )

if __name__ == "__main__":
    # Замените на свои значения
    TG_TOKEN = "<ваш_токен>"
    TG_CHAT_ID = "<ваш_chat_id>"
    summary = get_server_summary()
    send_telegram(f"Сводка по серверу:\n{summary}", TG_TOKEN, TG_CHAT_ID)
```

- Для критических ошибок и сбоев: добавьте отправку сообщений в Telegram в обработчики ошибок ваших приложений.
- Для автоматического оповещения о OOM Killer используйте мониторинг логов (см. выше в чате).

## Визуализация

- В Grafana добавьте источники данных Loki и Prometheus (обычно они уже настроены автоматически).
- Импортируйте дашборды для Node Exporter и Docker Monitoring (есть в Grafana.com).

## Как мониторить Python-приложения, запущенные через screen (или вне Docker)

1. **Настройте логирование приложения в файл**
   - В вашем Python-приложении укажите путь к лог-файлу, например:
     ```python
     logging.basicConfig(filename='/var/log/my_python_app.log', level=logging.INFO)
     ```
2. **Добавьте путь к лог-файлу в promtail-config.yaml**
   Пример:
   ```yaml
   scrape_configs:
     - job_name: python-apps
       static_configs:
         - targets: ["localhost"]
           labels:
             job: python-app
             __path__: /var/log/my_python_app.log
   ```
   - Можно добавить несколько файлов или маску (`/var/log/*.log`).
3. **Перезапустите promtail**
   ```sh
   make restart
   # или
   docker compose restart promtail
   ```
4. **В Grafana**
   - В разделе Explore выберите источник данных Loki.
   - Фильтруйте логи по label `job="python-app"` или по имени файла.

## Дашборды Grafana

- В папке monitoring/grafana-dashboards/ будут примеры json-дэшбордов:
  - **server-monitoring.json** — мониторинг ОС (CPU, RAM, диск, сеть)
  - **app-logs.json** — просмотр логов приложений (Loki)
  - **app-metrics.json** — метрики приложений (Prometheus)
- Можно использовать один дашборд с фильтрами по сервисам или несколько отдельных.

## Как применить изменения в docker-compose.yaml

- После изменения портов или конфигурации:
  ```sh
  make up
  # или если сервисы уже запущены
  make restart
  ```
- Для полной пересборки:
  ```sh
  make build
  make up
  # или
  make init
  ```

## Управление мониторингом

## Сети

Создание необходимых сетей (выполнить один раз):

```bash
docker network create monitoring
docker network create mango_default
docker network create player_default
```

## Запуск всех сервисов

### 1. Подготовка

```bash
# Остановить все сервисы, если они запущены
cd /home/monitoring
docker compose down
docker compose -f grafana-compose.yaml down

# Удалить старые сети, если они есть
docker network rm monitoring mango_default player_default || true

# Создать сети заново
docker network create monitoring
docker network create mango_default
docker network create player_default
```

### 2. Запуск основного мониторинга

```bash
# Запустить Loki, Prometheus, Alertmanager
docker compose up -d

# Проверить статус
docker compose ps

# Проверить логи
docker compose logs -f
```

### 3. Запуск Grafana

```bash
# Запустить Grafana
docker compose -f grafana-compose.yaml up -d

# Проверить статус
docker compose -f grafana-compose.yaml ps

# Проверить логи
docker compose -f grafana-compose.yaml logs -f
```

### 4. Проверка работоспособности

```bash
# Проверить доступность сервисов
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
curl http://localhost:3100/ready       # Loki
curl http://localhost:9093/-/healthy   # Alertmanager

# Открыть Grafana в браузере
# http://<IP_СЕРВЕРА>:3000
# Логин: admin
# Пароль: admin
```

### 5. Настройка Grafana

1. При первом входе измените пароль администратора
2. Проверьте, что источники данных (Loki и Prometheus) подключены
3. Импортируйте дашборды из папки `grafana-dashboards/`

### Автоматический запуск

Для автоматического запуска всех сервисов можно использовать скрипт:

```bash
#!/bin/bash
cd /home/monitoring

# Остановка и удаление
docker compose down
docker compose -f grafana-compose.yaml down
docker network rm monitoring mango_default player_default || true

# Создание сетей
docker network create monitoring
docker network create mango_default
docker network create player_default

# Запуск сервисов
docker compose up -d
docker compose -f grafana-compose.yaml up -d

# Проверка статуса
echo "Проверка статуса сервисов..."
docker compose ps
docker compose -f grafana-compose.yaml ps

echo "Мониторинг запущен!"
echo "Grafana доступна по адресу: http://<IP_СЕРВЕРА>:3000"
```

Сохраните скрипт как `monitoring/start.sh` и сделайте его исполняемым:

```bash
chmod +x start.sh
```

## Управление сервисами

### Проверка статуса

```bash
# Основной мониторинг
docker compose ps

# Grafana
docker compose -f grafana-compose.yaml ps
```

### Просмотр логов

```bash
# Основной мониторинг
docker compose logs -f

# Grafana
docker compose -f grafana-compose.yaml logs -f
```

### Остановка сервисов

```bash
# Основной мониторинг
docker compose down

# Grafana
docker compose -f grafana-compose.yaml down
```

### Перезапуск сервисов

```bash
# Основной мониторинг
docker compose restart

# Grafana
docker compose -f grafana-compose.yaml restart
```

## Обслуживание

### Удаление всех данных (включая тома)

> ⚠️ **Внимание!** Это удалит все настройки и данные

```bash
docker compose down -v
docker compose -f grafana-compose.yaml down -v
```

### Обновление конфигурации

После изменения конфигурационных файлов:

```bash
# Основной мониторинг
docker compose down
docker compose up -d

# Grafana
docker compose -f grafana-compose.yaml down
docker compose -f grafana-compose.yaml up -d
```

## Проверка доступности

Проверка работоспособности сервисов:

```bash
# Grafana
curl http://localhost:3000/api/health

# Prometheus
curl http://localhost:9090/-/healthy

# Loki
curl http://localhost:3100/ready

# Alertmanager
curl http://localhost:9093/-/healthy
```

## Структура проекта

```
monitoring/
├── docker-compose.yaml      # Основной мониторинг
├── grafana-compose.yaml     # Grafana
├── grafana-dashboards/      # Дашборды (импортируются вручную)
├── grafana-provisioning/    # Конфигурация Grafana
│   ├── datasources/        # Источники данных (Loki, Prometheus)
│   └── dashboards/         # Конфигурация автозагрузки дашбордов
├── prometheus.yml          # Конфигурация Prometheus
├── promtail-config.yaml    # Конфигурация Promtail
├── loki-config.yaml        # Конфигурация Loki
└── alertmanager.yml        # Конфигурация Alertmanager
```

## Настройка Grafana

### 1. Первый вход

1. Откройте http://<IP_СЕРВЕРА>:3000
2. Войдите с учетными данными по умолчанию:
   - Логин: `admin`
   - Пароль: `admin`
3. При первом входе обязательно измените пароль администратора

### 2. Источники данных

Источники данных (Loki и Prometheus) должны подключиться автоматически через `grafana-provisioning/datasources/`.
Если этого не произошло, добавьте их вручную:

1. Перейдите в Configuration → Data Sources
2. Нажмите "Add data source"
3. Добавьте Loki:
   - Type: `Loki`
   - URL: `http://loki:3100`
   - Access: `Server (default)`
4. Добавьте Prometheus:
   - Type: `Prometheus`
   - URL: `http://prometheus:9090`
   - Access: `Server (default)`

### 3. Импорт дашбордов

Дашборды из папки `grafana-dashboards/` нужно импортировать вручную:

1. Перейдите в Dashboards → Import
2. Нажмите "Upload JSON file"
3. Выберите файлы из папки `grafana-dashboards/`:
   - `server-monitoring.json` - мониторинг ОС
   - `app-logs.json` - логи приложений
   - `app-metrics.json` - метрики приложений
4. Для каждого дашборда:
   - Выберите соответствующий источник данных (Loki или Prometheus)
   - Нажмите "Import"

### 4. Проверка работоспособности

1. Откройте импортированные дашборды
2. Проверьте, что данные отображаются:
   - В дашборде логов должны быть видны логи контейнеров
   - В дашборде метрик должны отображаться метрики Prometheus
   - В дашборде сервера должны быть видны системные метрики

---

**Вопросы и помощь:**
Пишите в Telegram или GitHub Issues!

## Запуск приложений

### 1. Проверка мониторинга

Перед запуском приложений убедитесь, что мониторинг работает:

```bash
# Проверить статус всех сервисов
docker compose ps
docker compose -f grafana-compose.yaml ps

# Проверить доступность Grafana
curl http://localhost:3000/api/health
```

### 2. Запуск приложений

После запуска мониторинга можно запускать приложения:

```bash
# Перейти в директорию проекта
cd /home/mango

# Остановить все контейнеры, если они запущены
docker compose down

# Запустить приложения
docker compose up -d

# Проверить статус
docker compose ps
```

### 3. Проверка логов

После запуска приложений проверьте, что логи поступают в Grafana:

1. Откройте Grafana (http://<IP_СЕРВЕРА>:3000)
2. Перейдите в раздел Explore
3. Выберите источник данных Loki
4. В поле запроса введите:
   ```
   {container_name=~"mango.*|player.*"}
   ```
5. Должны появиться логи ваших приложений

### 4. Проверка метрик

Проверьте, что метрики приложений собираются:

1. В Grafana перейдите в раздел Explore
2. Выберите источник данных Prometheus
3. В поле запроса введите:
   ```
   up{job="mango"}
   ```
4. Должны отобразиться метрики ваших приложений

### 5. Настройка алертов (опционально)

Если нужно настроить алерты:

1. В Grafana перейдите в Alerting → Alert Rules
2. Создайте новые правила для:
   - Отсутствия логов более 5 минут
   - Высокой нагрузки на CPU/RAM
   - Ошибок в логах
3. Настройте уведомления через Alertmanager

### Порядок запуска при перезапуске сервера

1. Запустить мониторинг:
   ```bash
   cd /home/monitoring
   ./start.sh
   ```
2. Дождаться полного запуска всех сервисов
3. Проверить доступность Grafana
4. Запустить приложения:
   ```bash
   cd /home/mango
   docker compose up -d
   ```
5. Проверить логи и метрики в Grafana

## Первый запуск мониторинга

### 1. Подготовка системы

```bash
# Установить Docker и Docker Compose, если еще не установлены
sudo apt update
sudo apt install docker.io docker-compose

# Добавить текущего пользователя в группу docker
sudo usermod -aG docker $USER
# Перезайти в систему или выполнить:
newgrp docker

# Создать необходимые директории
sudo mkdir -p /home/monitoring/grafana-data
sudo mkdir -p /home/monitoring/loki-data
sudo mkdir -p /home/monitoring/prometheus-data

# Установить права
sudo chown -R $USER:$USER /home/monitoring
```

### 2. Клонирование репозитория

```bash
# Перейти в домашнюю директорию
cd /home

# Клонировать репозиторий
git clone <url_репозитория> monitoring

# Перейти в директорию мониторинга
cd monitoring
```

### 3. Настройка конфигурации

1. Проверить настройки в файлах:

   - `docker-compose.yaml` - порты и тома
   - `grafana-compose.yaml` - настройки Grafana
   - `prometheus.yml` - цели для сбора метрик
   - `loki-config.yaml` - настройки Loki
   - `promtail-config.yaml` - настройки сбора логов

2. При необходимости изменить пароли в `grafana-compose.yaml`:
   ```yaml
   environment:
     GF_SECURITY_ADMIN_PASSWORD: ваш_новый_пароль
   ```

### 4. Запуск мониторинга

```bash
# Создать сети Docker
docker network create monitoring
docker network create mango_default
docker network create player_default

# Запустить основной мониторинг
docker compose up -d

# Проверить статус
docker compose ps

# Проверить логи
docker compose logs -f
```

### 5. Запуск Grafana

```bash
# Запустить Grafana
docker compose -f grafana-compose.yaml up -d

# Проверить статус
docker compose -f grafana-compose.yaml ps

# Проверить логи
docker compose -f grafana-compose.yaml logs -f
```

### 6. Первичная настройка Grafana

1. Открыть Grafana в браузере: http://<IP_СЕРВЕРА>:3000
2. Войти с учетными данными по умолчанию:
   - Логин: `admin`
   - Пароль: `admin` (или тот, что указали в конфигурации)
3. Сменить пароль администратора
4. Проверить подключение источников данных:
   - Configuration → Data Sources
   - Должны быть видны Loki и Prometheus
5. Импортировать дашборды:
   - Dashboards → Import
   - Загрузить JSON-файлы из `grafana-dashboards/`

### 7. Проверка работоспособности

```bash
# Проверить доступность сервисов
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
curl http://localhost:3100/ready       # Loki
curl http://localhost:9093/-/healthy   # Alertmanager

# Проверить логи всех сервисов
docker compose logs -f
docker compose -f grafana-compose.yaml logs -f
```

### 8. Настройка автозапуска (опционально)

```bash
# Создать systemd сервис для мониторинга
sudo nano /etc/systemd/system/monitoring.service

# Добавить содержимое:
[Unit]
Description=Monitoring Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/monitoring
ExecStart=/bin/bash -c 'docker compose up -d && docker compose -f grafana-compose.yaml up -d'
ExecStop=/bin/bash -c 'docker compose down && docker compose -f grafana-compose.yaml down'

[Install]
WantedBy=multi-user.target

# Включить автозапуск
sudo systemctl enable monitoring.service
sudo systemctl start monitoring.service
```

### 9. Следующие шаги

1. Настроить алерты в Grafana
2. Добавить дополнительные дашборды
3. Настроить резервное копирование данных
4. Запустить приложения и проверить сбор логов/метрик
