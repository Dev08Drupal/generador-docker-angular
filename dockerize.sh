#!/bin/bash
# Script para dockerizar proyectos Angular o crear nuevos
#
# Uso:
#   dockerize.sh /ruta/al/proyecto [version]  - Dockeriza proyecto existente
#   dockerize.sh new nombre-proyecto [version] - Crea proyecto nuevo con Angular CLI
#   dockerize.sh vite nombre-proyecto         - Crea proyecto nuevo con Vite + Angular
#
# Instalación global (opcional):
#   sudo ln -s $(pwd)/dockerize.sh /usr/local/bin/ng-docker
#   Luego: ng-docker new mi-app

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Obtiene la versión mayor de Angular desde npm (requiere Docker)
resolve_latest_angular_version() {
    echo -e "${YELLOW}Consultando última versión de Angular CLI en npm...${NC}" >&2
    local ver
    ver=$(docker run --rm node:lts-slim npm view @angular/cli version 2>/dev/null | tr -d '\r' | tail -1)
    if [ -z "$ver" ]; then
        echo -e "${RED}No se pudo obtener la versión de Angular. Usando 20 por defecto.${NC}" >&2
        echo "20"
    else
        # Extrae solo el major (ej: "20.1.2" → "20")
        echo "$ver" | cut -d. -f1
    fi
}

# Obtiene la versión de Node compatible con la versión mayor de Angular
get_node_version() {
    local major="$1"
    if   [ "$major" -le 10 ] 2>/dev/null; then echo "12"
    elif [ "$major" -le 12 ] 2>/dev/null; then echo "14"
    elif [ "$major" -le 15 ] 2>/dev/null; then echo "16"
    elif [ "$major" -le 17 ] 2>/dev/null; then echo "20"
    elif [ "$major" -le 21 ] 2>/dev/null; then echo "22"
    else
        # Angular 22+ requiere Node 24+ (Node 22.x del registry no cumple el parche mínimo)
        echo "24"
    fi
}

# Detecta versión Angular desde package.json del proyecto
detect_angular_version_from_package() {
    local pkg="$1/package.json"
    if [ -f "$pkg" ]; then
        grep -o '"@angular/core": *"[^"]*"' "$pkg" | grep -oE '[0-9]+' | head -1
    fi
}

# Configura allowedHosts en angular.json (para Cloudflare Tunnel)
configure_allowed_hosts() {
    local PROJECT_PATH="$1"
    local ANGULAR_JSON="$PROJECT_PATH/angular.json"

    if [ -f "$ANGULAR_JSON" ]; then
        sed -i '/"builder": "@angular\/build:dev-server"/a\          "options": {\n            "allowedHosts": [".trycloudflare.com"]\n          },' "$ANGULAR_JSON"
    fi
}

# Genera archivos Docker para proyectos Vite
generate_vite_docker_files() {
    local PROJECT_PATH="$1"
    local PROJECT_NAME=$(basename "$PROJECT_PATH")

    echo -e "${GREEN}Generando archivos Docker para Vite...${NC}"

    cat > "$PROJECT_PATH/Dockerfile" << 'EOF'
FROM node:lts-slim

# Instalar cloudflared para compartir localhost
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared && \
    apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000

RUN if [ "$GID" != "1000" ]; then groupmod -g $GID node 2>/dev/null || true; fi && \
    if [ "$UID" != "1000" ]; then usermod -u $UID node 2>/dev/null || true; fi

WORKDIR /app
RUN chown -R node:node /app

COPY package*.json ./
RUN npm install

COPY . .

USER node

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
EOF

    cat > "$PROJECT_PATH/docker-compose.yml" << EOF
services:
  app:
    build:
      context: .
      args:
        UID: \${UID:-1000}
        GID: \${GID:-1000}
    container_name: ${PROJECT_NAME}
    mem_limit: 4g
    ports:
      - "\${PORT:-5173}:5173"
    volumes:
      - .:/app
    command: npm run dev -- --host 0.0.0.0
    stdin_open: true
    tty: true
EOF

    cat > "$PROJECT_PATH/.dockerignore" << 'EOF'
# node_modules  # Comentado para usar node_modules del repo local
dist
.git
.vscode
.idea
EOF

    cat > "$PROJECT_PATH/Makefile" << 'MAKEFILE'
.PHONY: start up down logs shell npm npm-install build test share help

start: ## Construye y levanta el contenedor
	docker-compose up -d --build
	@echo "App disponible en http://localhost:5173"

up: ## Levanta el contenedor
	docker-compose up -d

down: ## Detiene el contenedor
	docker-compose down

logs: ## Muestra logs
	docker-compose logs -f

shell: ## Accede al shell
	docker-compose exec app sh

npm: ## Ejecuta npm (uso: make npm cmd="install axios")
	docker-compose exec app npm $(cmd)

npm-install: ## Instala dependencias en node_modules local
	@echo "Instalando dependencias en node_modules local..."
	@docker-compose run --rm app npm install
	@echo "Dependencias instaladas en ./node_modules"

build: ## Build de producción
	docker-compose exec app npm run build

test: ## Ejecuta tests
	docker-compose exec app npm test

share: ## Comparte localhost con URL pública
	@echo "Iniciando túnel Cloudflare..."
	docker-compose exec app cloudflared tunnel --url http://localhost:5173

help: ## Muestra ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-12s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
MAKEFILE

    echo -e "${GREEN}Archivos generados en: $PROJECT_PATH${NC}"
}

# Genera archivos Docker para proyectos Angular
generate_docker_files() {
    local PROJECT_PATH="$1"
    local ANGULAR_VERSION="$2"
    local NODE_VERSION=$(get_node_version "$ANGULAR_VERSION")
    local PROJECT_NAME=$(basename "$PROJECT_PATH")

    echo -e "${GREEN}Generando archivos Docker (Angular $ANGULAR_VERSION, Node $NODE_VERSION)...${NC}"

    cat > "$PROJECT_PATH/Dockerfile" << EOF
# Dockerfile - Angular $ANGULAR_VERSION
FROM node:$NODE_VERSION-slim

# Instalar Chromium para pruebas unitarias y cloudflared para tunnels
RUN apt-get update && apt-get install -y --no-install-recommends \\
    chromium \\
    curl \\
    ca-certificates && \\
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && \\
    chmod +x /usr/local/bin/cloudflared && \\
    apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium

RUN npm install -g @angular/cli@$ANGULAR_VERSION

ARG UID=1000
ARG GID=1000

RUN if [ "\$GID" != "1000" ]; then groupmod -g \$GID node 2>/dev/null || true; fi && \\
    if [ "\$UID" != "1000" ]; then usermod -u \$UID node 2>/dev/null || true; fi

WORKDIR /app
RUN chown -R node:node /app

COPY package*.json ./
RUN npm install

COPY . .

USER node

EXPOSE 4200

CMD ["ng", "serve", "--host", "0.0.0.0", "--poll", "2000"]
EOF

    cat > "$PROJECT_PATH/docker-compose.yml" << EOF
services:
  app:
    build:
      context: .
      args:
        UID: \${UID:-1000}
        GID: \${GID:-1000}
    container_name: ${PROJECT_NAME}
    mem_limit: 4g
    ports:
      - "\${PORT:-4200}:4200"
    volumes:
      - .:/app
    environment:
      - NG_CLI_ANALYTICS=false
    command: ng serve --host 0.0.0.0 --poll 2000
    stdin_open: true
    tty: true
EOF

    cat > "$PROJECT_PATH/.dockerignore" << 'EOF'
# node_modules  # Comentado para usar node_modules del repo local
dist
.angular
.git
.vscode
.idea
coverage
e2e
EOF

    cat > "$PROJECT_PATH/Makefile" << 'MAKEFILE'
.PHONY: start up down logs shell ng npm npm-install build build-prod test test-headless share help

start: ## Construye y levanta el contenedor
	docker-compose up -d --build
	@echo "App disponible en http://localhost:4200"

up: ## Levanta el contenedor
	docker-compose up -d
	@echo "Aplicación disponible en: http://localhost:4200"

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

npm-install: ## Instala dependencias en node_modules local
	@echo "Instalando dependencias en node_modules local..."
	@docker-compose run --rm app npm install
	@echo "Dependencias instaladas en ./node_modules"

build: ## Build de desarrollo
	docker-compose exec app ng build

build-prod: ## Build de producción
	docker-compose exec app ng build --configuration production

test: ## Ejecuta tests (watch mode, headless)
	docker-compose exec app ng test --browsers=ChromeHeadless

test-headless: ## Ejecuta tests una vez (CI mode, headless)
	docker-compose run --rm app ng test --watch=false --browsers=ChromeHeadless

share: ## Comparte localhost con URL pública
	@echo "Iniciando túnel Cloudflare..."
	docker-compose exec app cloudflared tunnel --url http://localhost:4200

help: ## Muestra ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-12s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
MAKEFILE

    echo -e "${GREEN}Archivos generados en: $PROJECT_PATH${NC}"
}

# ── Comando: vite ──────────────────────────────────────────────────────────────
if [ "$1" = "vite" ]; then
    PROJECT_NAME="${2:-}"

    if [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}Error: Especifica nombre del proyecto${NC}"
        echo "Uso: $0 vite nombre-proyecto"
        exit 1
    fi

    echo -e "${GREEN}Creando proyecto con Vite (node:lts-slim)...${NC}"
    echo -e "${YELLOW}Selecciona el framework y variante cuando se te pregunte${NC}"
    echo ""

    docker run --rm -it \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e NPM_CONFIG_FUND=false \
        -e NPM_CONFIG_UPDATE_NOTIFIER=false \
        -v "$(pwd)":/workspace \
        -w /workspace \
        node:lts-slim \
        sh -c "npm create vite@latest $PROJECT_NAME"

    generate_vite_docker_files "$(pwd)/$PROJECT_NAME"

    echo ""
    echo -e "${YELLOW}Proyecto Vite creado. Para iniciar:${NC}"
    echo "  cd $PROJECT_NAME"
    echo "  make start"
    echo -e "${YELLOW}App disponible en: http://localhost:5173${NC}"
    exit 0
fi

# ── Comando: new ───────────────────────────────────────────────────────────────
if [ "$1" = "new" ]; then
    PROJECT_NAME="${2:-}"
    ANGULAR_VERSION="${3:-latest}"

    if [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}Error: Especifica nombre del proyecto${NC}"
        echo "Uso: $0 new nombre-proyecto [version]"
        echo "Ejemplo: $0 new mi-app        # usa la última versión"
        echo "Ejemplo: $0 new mi-app 18     # fuerza Angular 18"
        exit 1
    fi

    # Resolver "latest" → número de versión mayor
    if [ "$ANGULAR_VERSION" = "latest" ]; then
        ANGULAR_VERSION=$(resolve_latest_angular_version)
        echo -e "${GREEN}Usando Angular $ANGULAR_VERSION (última disponible)${NC}"
    fi

    NODE_VERSION=$(get_node_version "$ANGULAR_VERSION")

    echo -e "${GREEN}Creando proyecto Angular $ANGULAR_VERSION con Node $NODE_VERSION...${NC}"

    docker run --rm -it \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e NPM_CONFIG_PREFIX=/tmp/.npm-global \
        -e NPM_CONFIG_FUND=false \
        -e NPM_CONFIG_UPDATE_NOTIFIER=false \
        -v "$(pwd)":/workspace \
        -w /workspace \
        "node:$NODE_VERSION-slim" \
        sh -c "npm install -g @angular/cli@$ANGULAR_VERSION 2>/dev/null && /tmp/.npm-global/bin/ng new $PROJECT_NAME --skip-git"

    configure_allowed_hosts "$(pwd)/$PROJECT_NAME"
    generate_docker_files "$(pwd)/$PROJECT_NAME" "$ANGULAR_VERSION"

    echo ""
    echo -e "${YELLOW}Proyecto creado. Para iniciar:${NC}"
    echo "  cd $PROJECT_NAME"
    echo "  make start"
    exit 0
fi

# ── Dockerizar proyecto existente ──────────────────────────────────────────────
PROJECT_PATH="${1:-.}"
ANGULAR_VERSION="${2:-}"

echo -e "${GREEN}Dockerizando proyecto Angular...${NC}"

if [ ! -f "$PROJECT_PATH/package.json" ]; then
    echo -e "${RED}Error: No se encontró package.json en $PROJECT_PATH${NC}"
    exit 1
fi

if [ -z "$ANGULAR_VERSION" ]; then
    ANGULAR_VERSION=$(detect_angular_version_from_package "$PROJECT_PATH")
    if [ -z "$ANGULAR_VERSION" ]; then
        echo -e "${YELLOW}No se detectó versión Angular. Obteniendo la última...${NC}"
        ANGULAR_VERSION=$(resolve_latest_angular_version)
    else
        echo -e "${YELLOW}Detectada versión de Angular: $ANGULAR_VERSION${NC}"
    fi
fi

generate_docker_files "$PROJECT_PATH" "$ANGULAR_VERSION"

echo ""
echo -e "${YELLOW}Para iniciar:${NC}"
echo "  cd $PROJECT_PATH"
echo "  make start"
echo ""
echo -e "${YELLOW}Para usar diferente puerto:${NC}"
echo "  PORT=4201 make start"
