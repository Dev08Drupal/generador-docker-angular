# Makefile para Angular con Docker

# Variables
DOCKER_COMPOSE = docker-compose
CONTAINER_NAME = angular-app
SERVICE_NAME = app

# Colores para output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help
help: ## Muestra esta ayuda
	@echo '$(YELLOW)Comandos disponibles:$(RESET)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}'

.PHONY: install
install: ## Crea nuevo proyecto (uso: make install name=mi-app v=19)
	@echo '$(GREEN)Creando proyecto Angular v$(v)...$(RESET)'
	docker run --rm -it -v $(PWD):/workspace -w /workspace $(call get_node,$(v)) sh -c "npm install -g @angular/cli@$(v) && ng new $(name) --skip-git"
	@$(MAKE) --no-print-directory setup-docker name=$(name) v=$(v)
	@echo '$(YELLOW)Proyecto creado en: ./$(name)$(RESET)'
	@echo '$(YELLOW)Entra al proyecto y ejecuta: make start$(RESET)'

.PHONY: init
init: ## Inicializa en directorio actual (uso: make init v=19)
	@echo '$(GREEN)Inicializando proyecto Angular v$(v)...$(RESET)'
	docker run --rm -it -v $(PWD):/app -w /app $(call get_node,$(v)) sh -c "npm install -g @angular/cli@$(v) && ng new temp-app --skip-git && mv temp-app/* temp-app/.* . 2>/dev/null; rm -rf temp-app"
	@echo '$(YELLOW)Proyecto inicializado. Ejecuta: make start$(RESET)'

# Función para obtener versión de Node según Angular
# Angular 8: Node 12, Angular 17: Node 20, Angular 18-21: Node 22
define get_node
$(if $(filter 8 9 10,$(1)),node:12-alpine,$(if $(filter 11 12,$(1)),node:14-alpine,$(if $(filter 13 14 15,$(1)),node:16-alpine,$(if $(filter 16 17,$(1)),node:20-alpine,node:22-alpine))))
endef

.PHONY: setup-docker
setup-docker: ## Genera archivos Docker para un proyecto existente (uso: make setup-docker name=mi-app v=17)
	@echo '$(GREEN)Generando archivos Docker para $(name) con Angular $(v)...$(RESET)'
	@mkdir -p $(name)
	@echo '# Dockerfile\nFROM $(call get_node,$(v))\nRUN npm install -g @angular/cli@$(v)\nWORKDIR /app\nCOPY package*.json ./\nRUN npm install\nCOPY . .\nEXPOSE 4200\nCMD ["ng", "serve", "--host", "0.0.0.0", "--poll", "2000"]' > $(name)/Dockerfile
	@echo 'services:\n  app:\n    build: .\n    container_name: $(name)\n    ports:\n      - "$${PORT:-4200}:4200"\n    volumes:\n      - .:/app\n      - /app/node_modules\n    environment:\n      - NG_CLI_ANALYTICS=false\n    command: ng serve --host 0.0.0.0 --poll 2000\n    stdin_open: true\n    tty: true' > $(name)/docker-compose.yml
	@echo 'node_modules\ndist\n.angular\n.git' > $(name)/.dockerignore
	@cp Makefile $(name)/Makefile 2>/dev/null || true

.PHONY: build
build: ## Construye la imagen Docker
	@echo '$(GREEN)Construyendo imagen Docker...$(RESET)'
	$(DOCKER_COMPOSE) build

.PHONY: up
up: ## Levanta los contenedores
	@echo '$(GREEN)Levantando contenedores...$(RESET)'
	$(DOCKER_COMPOSE) up -d
	@echo '$(YELLOW)Aplicación disponible en: http://localhost:4200$(RESET)'

.PHONY: start
start: build up ## Construye y levanta los contenedores

.PHONY: down
down: ## Detiene y elimina los contenedores
	@echo '$(GREEN)Deteniendo contenedores...$(RESET)'
	$(DOCKER_COMPOSE) down

.PHONY: restart
restart: down up ## Reinicia los contenedores

.PHONY: logs
logs: ## Muestra los logs (Ctrl+C para salir)
	$(DOCKER_COMPOSE) logs -f $(SERVICE_NAME)

.PHONY: shell
shell: ## Accede al shell del contenedor
	@echo '$(GREEN)Accediendo al shell...$(RESET)'
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) sh

.PHONY: bash
bash: shell ## Alias de shell

.PHONY: npm
npm: ## Ejecuta comandos npm (uso: make npm cmd="install lodash")
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) npm $(cmd)

.PHONY: ng
ng: ## Ejecuta comandos Angular CLI (uso: make ng cmd="generate component home")
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng $(cmd)

.PHONY: generate
generate: ## Alias para ng generate (uso: make generate cmd="component header")
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate $(cmd)

.PHONY: g
g: generate ## Alias corto de generate

.PHONY: component
component: ## Crea un componente (uso: make component name=header)
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate component $(name)

.PHONY: service
service: ## Crea un servicio (uso: make service name=auth)
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate service $(name)

.PHONY: module
module: ## Crea un módulo (uso: make module name=shared)
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate module $(name)

.PHONY: guard
guard: ## Crea un guard (uso: make guard name=auth)
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate guard $(name)

.PHONY: pipe
pipe: ## Crea un pipe (uso: make pipe name=capitalize)
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate pipe $(name)

.PHONY: directive
directive: ## Crea una directiva (uso: make directive name=highlight)
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng generate directive $(name)

.PHONY: test
test: ## Ejecuta los tests
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng test

.PHONY: e2e
e2e: ## Ejecuta tests e2e
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng e2e

.PHONY: lint
lint: ## Ejecuta el linter
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng lint

.PHONY: build-prod
build-prod: ## Construye para producción
	@echo '$(GREEN)Construyendo para producción...$(RESET)'
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) ng build --configuration production

.PHONY: install-deps
install-deps: ## Instala dependencias npm
	@echo '$(GREEN)Instalando dependencias...$(RESET)'
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) npm install

.PHONY: update-deps
update-deps: ## Actualiza dependencias npm
	@echo '$(GREEN)Actualizando dependencias...$(RESET)'
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) npm update

.PHONY: clean
clean: ## Limpia node_modules y caché
	@echo '$(YELLOW)Limpiando archivos temporales...$(RESET)'
	$(DOCKER_COMPOSE) exec $(SERVICE_NAME) rm -rf node_modules .angular/cache
	$(DOCKER_COMPOSE) down -v

.PHONY: ps
ps: ## Muestra el estado de los contenedores
	$(DOCKER_COMPOSE) ps

.PHONY: stats
stats: ## Muestra estadísticas de recursos
	docker stats $(CONTAINER_NAME)

.PHONY: prune
prune: ## Limpia recursos Docker no utilizados
	@echo '$(YELLOW)Limpiando recursos Docker...$(RESET)'
	docker system prune -f

.PHONY: rebuild
rebuild: down build up ## Reconstruye completamente el contenedor

.PHONY: fresh
fresh: clean rebuild ## Limpieza completa y reconstrucción

.PHONY: share
share: ## Comparte localhost con URL pública (uso: make share port=4200)
	@echo '$(GREEN)Iniciando túnel Cloudflare...$(RESET)'
	@echo '$(YELLOW)Presiona Ctrl+C para detener$(RESET)'
	@$(DOCKER_COMPOSE) exec $(SERVICE_NAME) cloudflared tunnel --url http://localhost:$(or $(port),4200)

.DEFAULT_GOAL := help