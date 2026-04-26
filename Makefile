SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: help up env-init env-sync ports-sync app-dir compose-up down

define UP_FUNCS
read_file_key() {
	file="$$1"
	key="$$2"
	value=""
	if [ -f "$$file" ]; then
		value="$$(sed -n "s/^$${key}=//p" "$$file" | head -n1)"
	fi
	printf '%s\n' "$$value"
}
resolve_key() {
	key="$$1"
	value="$$(read_file_key .env "$$key")"
	if [ -z "$$value" ]; then
		value="$$(read_file_key .env.example "$$key")"
	fi
	printf '%s\n' "$$value"
}
resolve_required_key() {
	key="$$1"
	value="$$(resolve_key "$$key")"
	if [ -z "$$value" ]; then
		echo "$$key vazio em .env/.env.example"
		exit 1
	fi
	printf '%s\n' "$$value"
}
resolve_host_key() {
	key="$$1"
	host_default="$$2"
	value="$$(resolve_key "$$key")"
	if [ -z "$$value" ]; then
		value="$$host_default"
	fi
	printf '%s\n' "$$value"
}
update_env_value() {
	key="$$1"
	value="$$2"
	tmp_file="$$(mktemp)"
	awk -v key="$$key" -v value="$$value" '
		BEGIN {
			found = 0
		}
		index($$0, key "=") == 1 && !found {
			print key "=" value
			found = 1
			next
		}
		{
			print
		}
		END {
			if (!found) {
				print key "=" value
			}
		}
	' .env > "$$tmp_file"
	mv "$$tmp_file" .env
}
find_free_port() {
	port="$$1"
	while :; do
		if (exec 3<>"/dev/tcp/127.0.0.1/$$port") >/dev/null 2>&1; then
			exec 3<&- 3>&-
		else
			printf '%s\n' "$$port"
			return 0
		fi
		port=$$((port + 1))
	done
}
endef

help:
	@echo "Comandos disponiveis:"
	@echo "  make help       - Mostra esta ajuda"
	@echo "  make up         - Executa a cadeia inteira e sobe os containers"
	@echo "  make env-init   - Cria .env a partir de .env.example"
	@echo "  make env-sync   - Reescreve variaveis base em .env"
	@echo "  make ports-sync - Ajusta portas livres em .env"
	@echo "  make app-dir    - Garante a pasta do app"
	@echo "  make compose-up - Sobe os containers"
	@echo "  make down       - Derruba containers e limpa .env/vendor"

up: compose-up

env-init:
	if [ ! -f .env ]; then
		cp .env.example .env
		echo ".env criado a partir de .env.example"
	else
		echo ".env ja existe, mantendo arquivo atual"
	fi

env-sync: env-init
	@$(UP_FUNCS)
	echo "Sincronizando variaveis base em .env"
	app_name="$$(resolve_required_key APP_NAME)"
	app_env="$$(resolve_required_key APP_ENV)"
	db_host="$$(resolve_required_key DB_HOST)"
	db_database="$$(resolve_required_key DB_DATABASE)"
	db_root_password="$$(resolve_required_key DB_ROOT_PASSWORD)"
	host_uid="$$(id -u)"
	host_gid="$$(id -g)"
	local_uid="$$(resolve_host_key LOCAL_UID "$$host_uid")"
	local_gid="$$(resolve_host_key LOCAL_GID "$$host_gid")"
	update_env_value APP_NAME "$$app_name"
	update_env_value APP_ENV "$$app_env"
	update_env_value DB_HOST "$$db_host"
	update_env_value DB_DATABASE "$$db_database"
	update_env_value DB_ROOT_PASSWORD "$$db_root_password"
	update_env_value LOCAL_UID "$$local_uid"
	update_env_value LOCAL_GID "$$local_gid"

ports-sync: env-sync
	@$(UP_FUNCS)
	echo "Ajustando portas livres em .env"
	host_base_port="$$(resolve_required_key HOST_PORT)"
	db_base_port="$$(resolve_required_key DB_PORT)"
	host_port="$$(find_free_port "$$host_base_port")"
	db_port="$$(find_free_port "$$db_base_port")"
	update_env_value HOST_PORT "$$host_port"
	update_env_value DB_PORT "$$db_port"
	echo "Portas escolhidas: HOST_PORT=$$host_port DB_PORT=$$db_port"

app-dir: ports-sync
	@$(UP_FUNCS)
	app_name="$$(resolve_required_key APP_NAME)"
	echo "Garantindo pasta do app em $$app_name"
	if [ -n "$$app_name" ] && [ -d "$$app_name" ] && [ -z "$$(find "$$app_name" -mindepth 1 -print -quit)" ] && [ ! -w "$$app_name" ]; then
		rm -rf "$$app_name"
		echo "pasta $$app_name vazia e sem permissao; recriada"
	fi
	if [ -n "$$app_name" ]; then
		mkdir -p "$$app_name"
	fi

compose-up: app-dir
	docker compose up -d --build

down:
	docker compose down --rmi all --volumes --remove-orphans
	if [ -f .env ]; then
		rm .env
		echo ".env removido"
	fi
	if [ -d vendor ]; then
		rm -rf vendor
		echo "vendor removido"
	fi
