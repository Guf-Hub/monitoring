.PHONY: help build rebuild up restart down stop recreate ls in_app logs images clean pure sclean docker-install ps-all volumes-all volumes-project ps-project apt-clean apt-purge init rm-all-containers create-network clean-cache docker-info

# Универсальный Makefile для управления Docker-проектами
# Использует только современный синтаксис docker compose
# Подробные комментарии к каждой цели — когда и зачем использовать

# Показать список всех доступных команд и их назначение
help:
	@echo "\nДоступные команды:"
	@echo "  create-network  — Создать внешнюю сеть app_network (запустить перед первым запуском проектов!)"
	@echo "  init            — Создать и запустить проект с нуля (полная очистка, пересборка и запуск)"
	@echo "  build           — Сборка Docker-образов без кэша (если изменили Dockerfile или зависимости)"
	@echo "  rebuild         — Полная пересборка и запуск всех сервисов (если нужно обновить всё с нуля)"
	@echo "  recreate        — Пересоздать все сервисы без остановки проекта (например, если изменили переменные окружения)"
	@echo "  up              — Запуск всех сервисов в фоне (если просто хотите запустить проект)"
	@echo "  restart         — Перезапуск всех сервисов (если нужно перезапустить без пересборки)"
	@echo "  stop            — Остановка всех сервисов (без удаления)"
	@echo "  down            — Остановка и удаление сервисов и осиротевших контейнеров (если хотите полностью остановить проект)"
	@echo "  rm-all-containers — Остановить и удалить все контейнеры Docker на сервере (ОСТОРОЖНО!)"
	@echo "  ls           	 — Список всех контейнеров проекта (включая остановленные, только из текущей папки)"
	@echo "  ps-project      — То же, что ls (контейнеры текущего проекта)"
	@echo "  ps-all          — Список всех контейнеров Docker на сервере (любых проектов)"
	@echo "  images          — Список всех образов проекта (только из текущей папки)"
	@echo "  volumes-all     — Список всех Docker-томов на сервере (всех проектов)"
	@echo "  volumes-project — Список томов, используемых текущим проектом"
	@echo "  in_app          — Вход в контейнер (по умолчанию 'app', можно задать name=имя) (для отладки внутри контейнера)"
	@echo "  logs            — Просмотр логов (name=service для конкретного сервиса, иначе все из текущего проекта)"
	@echo "  clean           — Остановка, удаление томов и временных файлов проекта (если нужно полностью очистить проект)"
	@echo "  pure            — Полная очистка Docker-системы (контейнеры, образы, тома — осторожно!)"
	@echo "  sclean      	 — Полная очистка Docker и системы Ubuntu (включая APT-кэш, только для серверов!)"
	@echo "  clean-cache     — Очистка Docker кэша"
	@echo "  apt-clean       — Только очистка системы Ubuntu (APT-кэш, не затрагивает Docker)"
	@echo "  apt-purge       — Полная очистка Ubuntu и настройка минимальной установки (только для серверов!)"
	@echo "  docker-install  — Установка или обновление Docker и Docker Compose (Linux)"
	@echo "  docker-info     — Показать подробную информацию о системе Docker (использование диска, образы, контейнеры)"


# Создать внешнюю сеть app_network (запустить перед первым запуском проектов!)
create-network:
	docker network create mango_default || true

# Создать и запустить проект с нуля (полная очистка, пересборка и запуск)
init:
	docker compose down --volumes --remove-orphans
	docker system prune -a --volumes -f
	docker network create mango_default || true
	docker compose build --no-cache
	docker compose up -d

# Сборка Docker-образов без кэша (если изменили Dockerfile или зависимости)
build:
	docker compose build --no-cache

# Полная пересборка и запуск всех сервисов (если нужно обновить всё с нуля)
rebuild:
	docker compose down --volumes --remove-orphans
	docker system prune -a --volumes -f
	docker compose up --build -d

# Пересоздать все сервисы без остановки проекта (например, если изменили переменные окружения)
recreate:
	docker compose up -d --force-recreate

# Запуск всех сервисов в фоне (обычный запуск)
up:
	docker compose up -d

# Перезапуск всех сервисов (без пересборки)
restart:
	docker compose restart

# Остановка всех сервисов (без удаления)
stop:
	docker compose stop

# Остановка и удаление сервисов и осиротевших контейнеров (полная остановка проекта)
down:
	docker compose down --remove-orphans

# Остановить и удалить все контейнеры Docker на сервере (ОСТОРОЖНО!)
rm-all-containers:
	docker rm -f $$(docker ps -aq) || true


# Список всех контейнеров проекта (включая остановленные, только из текущей папки)
ls:
	docker compose ps -a

# То же, что list (контейнеры текущего проекта)
ps-project:
	docker compose ps -a

# Список всех контейнеров Docker на сервере (любых проектов)
ps-all:
	docker ps -a

# Список всех образов проекта (только из текущей папки)
images:
	docker compose images

# Показать подробную информацию о системе Docker (использование диска, образы, контейнеры)
docker-info:
	docker system df -v | cat

# Список всех Docker-томов на сервере (всех проектов)
volumes-all:
	docker volume ls

# Список томов, используемых текущим проектом
volumes-project:
	docker compose volume ls

# Вход в контейнер (по умолчанию 'app', можно задать name=имя)
in_app:
	@if [ -n "$(name)" ]; then \
		docker compose exec $(name) bash; \
	else \
		docker compose exec app bash; \
	fi

# Просмотр логов (name=service для конкретного сервиса, иначе все из текущего проекта)
logs:
	@if [ -n "$(name)" ]; then \
		docker compose logs -f $(name); \
	else \
		docker compose logs -f; \
	fi

# Остановка, удаление томов и временных файлов проекта (полная очистка проекта)
clean:
	docker compose down -v
	rm -rf data/* cookies/* __pycache__ .pytest_cache || true
	find . -type d -name __pycache__ -exec rm -rf {} +

# Полная очистка Docker-системы (контейнеры, образы, тома — осторожно!)
pure:
	docker compose down --volumes --remove-orphans
	docker system prune -a --volumes -f

# Полная очистка Docker и системы Ubuntu (включая APT-кэш, только для серверов!)
sclean:
	docker compose down --volumes --remove-orphans
	docker stop $$(docker ps -aq) 2>/dev/null || true
	docker rm $$(docker ps -aq) 2>/dev/null || true
	docker rmi -f $$(docker images -aq) 2>/dev/null || true
	docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	docker network prune -f
	docker system prune -a --volumes -f
	sudo apt-get autoremove -y
	sudo apt-get clean

# Очистка Docker кэша
clean-cache:
	docker builder prune -f
	docker system prune -f

# Полная очистка системы Ubuntu (APT-кэш, не затрагивает Docker)
apt-clean:
	sudo apt-get autoremove -y
	sudo apt-get clean

# Полная очистка системы Ubuntu и настройка минимальной установки (только для серверов!)
apt-purge:
	@echo "Создаем резервную копию списка пакетов..."
	@mkdir -p backup
	@dpkg --get-selections > backup/packages-backup-$$(date +%Y%m%d-%H%M%S).txt
	@echo "Список пакетов сохранен в backup/packages-backup-*.txt"
	@echo "Начинаем безопасную очистку системы..."
	sudo apt-get update
	# Сохраняем список важных пакетов
	sudo apt-mark showmanual > backup/manual-packages-$$(date +%Y%m%d-%H%M%S).txt
	# Очищаем только автоматически установленные пакеты
	sudo apt-get autoremove --purge -y
	sudo apt-get clean
	sudo apt-get autoclean
	# Восстанавливаем важные пакеты
	@if [ -f backup/manual-packages-*.txt ]; then \
		echo "Восстанавливаем важные пакеты..."; \
		cat backup/manual-packages-*.txt | xargs -r sudo apt-mark manual; \
	fi
	# Безопасное обновление
	sudo apt-get update
	sudo apt-get upgrade -y
	# Очистка кэша и логов
	sudo rm -rf /var/lib/apt/lists/*
	sudo rm -rf /var/cache/apt/*
	sudo journalctl --vacuum-time=1d
	# Очистка только старых логов (старше 7 дней)
	sudo find /var/log -type f -name "*.gz" -mtime +7 -delete
	sudo find /var/log -type f -name "*.[09]" -mtime +7 -delete
	sudo find /var/log -type f -name "*.log" -mtime +7 -exec truncate -s 0 {} \;
	# Очистка только старых временных файлов
	sudo find /tmp -type f -atime +7 -delete
	sudo find /var/tmp -type f -atime +7 -delete
	@echo "Очистка завершена. Список пакетов сохранен в backup/"
	@echo "Для восстановления пакетов используйте:"
	@echo "  cat backup/packages-backup-*.txt | sudo dpkg --set-selections"
	@echo "  sudo apt-get dselect-upgrade"

# Обновление Docker и Docker Compose (Linux)
docker-install:
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io
	sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	docker --version
