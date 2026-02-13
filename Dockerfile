# Dockerfile - Angular 21
FROM node:22-slim

# Instalar Chromium para pruebas unitarias y cloudflared para tunnels
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    curl \
    ca-certificates && \
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared && \
    apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium

RUN npm install -g @angular/cli@21

# Crear usuario con UID/GID configurables (por defecto 1000)
ARG UID=1000
ARG GID=1000

RUN if [ "$GID" != "1000" ]; then groupmod -g $GID node 2>/dev/null || true; fi && \
    if [ "$UID" != "1000" ]; then usermod -u $UID node 2>/dev/null || true; fi

WORKDIR /app

# Cambiar propietario del directorio de trabajo
RUN chown -R node:node /app

COPY package*.json ./
RUN npm install

COPY . .

# Usar el usuario node en lugar de root
USER node

EXPOSE 4200

CMD ["ng", "serve", "--host", "0.0.0.0", "--poll", "2000"]
