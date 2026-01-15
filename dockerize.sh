#!/bin/bash
# Script para dockerizar proyectos Angular o crear nuevos
#
# Uso:
#   dockerize.sh /ruta/al/proyecto [version]  - Dockeriza proyecto existente
#   dockerize.sh new nombre-proyecto version  - Crea proyecto nuevo
#
# Instalación global (opcional):
#   sudo ln -s $(pwd)/dockerize.sh /usr/local/bin/ng-docker
#   Luego: ng-docker new mi-app 21

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Función para obtener versión de Node según Angular
get_node_version() {
    case $1 in
        8|9|10) echo "12" ;;
        11|12) echo "14" ;;
        13|14|15) echo "16" ;;
        16|17) echo "20" ;;
        *) echo "22" ;;
    esac
}

# Función para configurar allowedHosts en angular.json (para Cloudflare Tunnel)
configure_allowed_hosts() {
    local PROJECT_PATH="$1"
    local ANGULAR_JSON="$PROJECT_PATH/angular.json"

    if [ -f "$ANGULAR_JSON" ]; then
        # Usar sed para insertar allowedHosts después de "builder": "@angular/build:dev-server"
        sed -i '/"builder": "@angular\/build:dev-server"/a\          "options": {\n            "allowedHosts": [".trycloudflare.com"]\n          },' "$ANGULAR_JSON"
    fi
}

# Función para generar archivos Docker
generate_docker_files() {
    local PROJECT_PATH="$1"
    local ANGULAR_VERSION="$2"
    local NODE_VERSION=$(get_node_version "$ANGULAR_VERSION")
    local PROJECT_NAME=$(basename "$PROJECT_PATH")

    echo -e "${GREEN}Generando archivos Docker (Angular $ANGULAR_VERSION, Node $NODE_VERSION)...${NC}"

    # Dockerfile
    cat > "$PROJECT_PATH/Dockerfile" << EOF
# Dockerfile - Angular $ANGULAR_VERSION
FROM node:$NODE_VERSION-alpine

# Instalar cloudflared para compartir localhost
RUN apk add --no-cache curl && \\
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && \\
    chmod +x /usr/local/bin/cloudflared && \\
    apk del curl

RUN npm install -g @angular/cli@$ANGULAR_VERSION

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 4200

CMD ["ng", "serve", "--host", "0.0.0.0", "--poll", "2000"]
EOF

    # docker-compose.yml
    cat > "$PROJECT_PATH/docker-compose.yml" << EOF
services:
  app:
    build: .
    container_name: ${PROJECT_NAME}
    ports:
      - "\${PORT:-4200}:4200"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NG_CLI_ANALYTICS=false
    command: ng serve --host 0.0.0.0 --poll 2000
    stdin_open: true
    tty: true
EOF

    # .dockerignore
    cat > "$PROJECT_PATH/.dockerignore" << EOF
node_modules
dist
.angular
.git
.vscode
.idea
EOF

    # Makefile
    cat > "$PROJECT_PATH/Makefile" << 'MAKEFILE'
.PHONY: start up down logs shell ng npm build-prod test share help

start: ## Construye y levanta el contenedor
	docker-compose up -d --build
	@echo "App disponible en http://localhost:4200"

up: ## Levanta el contenedor
	docker-compose up -d

down: ## Detiene el contenedor
	docker-compose down

logs: ## Muestra logs
	docker-compose logs -f

shell: ## Accede al shell
	docker-compose exec app sh

ng: ## Ejecuta ng (uso: make ng cmd="generate component home")
	docker-compose exec app ng $(cmd)

npm: ## Ejecuta npm (uso: make npm cmd="install axios")
	docker-compose exec app npm $(cmd)

build-prod: ## Build de producción
	docker-compose exec app ng build --configuration production

test: ## Ejecuta tests
	docker-compose exec app ng test

share: ## Comparte localhost con URL pública
	@echo "Iniciando túnel Cloudflare..."
	docker-compose exec app cloudflared tunnel --url http://localhost:4200

help: ## Muestra ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-12s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
MAKEFILE

    echo -e "${GREEN}Archivos generados en: $PROJECT_PATH${NC}"
}

# Comando: new (crear proyecto nuevo)
if [ "$1" = "new" ]; then
    PROJECT_NAME="${2:-}"
    ANGULAR_VERSION="${3:-21}"

    if [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}Error: Especifica nombre del proyecto${NC}"
        echo "Uso: $0 new nombre-proyecto [version]"
        echo "Ejemplo: $0 new mi-app 21"
        exit 1
    fi

    NODE_VERSION=$(get_node_version "$ANGULAR_VERSION")

    echo -e "${GREEN}Creando proyecto Angular $ANGULAR_VERSION...${NC}"

    docker run --rm -it \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e NPM_CONFIG_PREFIX=/tmp/.npm-global \
        -e NPM_CONFIG_FUND=false \
        -e NPM_CONFIG_UPDATE_NOTIFIER=false \
        -v "$(pwd)":/workspace \
        -w /workspace \
        "node:$NODE_VERSION-alpine" \
        sh -c "npm install -g @angular/cli@$ANGULAR_VERSION 2>/dev/null && /tmp/.npm-global/bin/ng new $PROJECT_NAME --skip-git"

    # Configurar allowedHosts para Cloudflare Tunnel
    configure_allowed_hosts "$(pwd)/$PROJECT_NAME"

    generate_docker_files "$(pwd)/$PROJECT_NAME" "$ANGULAR_VERSION"

    echo ""
    echo -e "${YELLOW}Proyecto creado. Para iniciar:${NC}"
    echo "  cd $PROJECT_NAME"
    echo "  make start"
    exit 0
fi

# Comando: dockerizar proyecto existente
PROJECT_PATH="${1:-.}"
ANGULAR_VERSION="${2:-}"

echo -e "${GREEN}Dockerizando proyecto Angular...${NC}"

# Verificar que existe package.json
if [ ! -f "$PROJECT_PATH/package.json" ]; then
    echo -e "${RED}Error: No se encontró package.json en $PROJECT_PATH${NC}"
    exit 1
fi

# Detectar versión de Angular si no se especificó
if [ -z "$ANGULAR_VERSION" ]; then
    ANGULAR_VERSION=$(grep -o '"@angular/core": *"[^"]*"' "$PROJECT_PATH/package.json" | grep -o '[0-9]*' | head -1)
    echo -e "${YELLOW}Detectada versión de Angular: $ANGULAR_VERSION${NC}"
fi

generate_docker_files "$PROJECT_PATH" "$ANGULAR_VERSION"

echo ""
echo -e "${YELLOW}Para iniciar:${NC}"
echo "  cd $PROJECT_PATH"
echo "  make start"
echo ""
echo -e "${YELLOW}Para usar diferente puerto:${NC}"
echo "  PORT=4201 make start"
