# Dockerfile
FROM node:22-alpine

# Instalar Angular CLI globalmente (última versión LTS: 21.x)
RUN npm install -g @angular/cli@21

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias (si existen)
COPY package*.json ./

# Instalar dependencias (si package.json existe)
RUN if [ -f package.json ]; then npm install; fi

# Copiar el resto del código
COPY . .

# Exponer puerto
EXPOSE 4200

# Comando por defecto
CMD ["ng", "serve", "--host", "0.0.0.0", "--poll", "2000"]