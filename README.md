# Angular Dockerizado

Entorno de desarrollo Angular completamente dockerizado. No requiere instalar Node.js ni Angular CLI en tu sistema.

## Requisitos

- Docker
- Docker Compose
- Make (opcional)

## Instalación Global (Recomendado)

Para usar el comando `ng-docker` desde cualquier ubicación, debes crear un enlace simbólico:

```bash
# Desde la carpeta del proyecto generador-docker-angular ejecuta:
cd /ruta/a/generador-docker-angular
sudo ln -s $(pwd)/dockerize.sh /usr/local/bin/ng-docker

# Ahora puedes usarlo desde cualquier carpeta:
ng-docker new mi-proyecto 21
ng-docker /ruta/a/proyecto-existente
```

> **Nota:** El enlace simbólico solo se crea una vez. Después podrás usar `ng-docker` desde cualquier directorio.

## Inicio Rápido

### Opción 1: Usando el script (desde cualquier lugar)

```bash
# Crear proyecto nuevo
ng-docker new mi-app 21

# Dockerizar proyecto existente
ng-docker /ruta/a/mi-proyecto
```

### Opción 2: Usando Make (desde esta carpeta)

```bash
# Crear proyecto en directorio actual
make init v=21

# Crear proyecto en subdirectorio
make install name=mi-app v=21
```

### Levantar el proyecto

```bash
cd mi-app
make start

# Abrir en navegador
http://localhost:4200
```

## Uso del Script ng-docker

### Crear proyecto nuevo (Angular CLI)

```bash
# Sintaxis: ng-docker new <nombre> <version>
ng-docker new mi-app 21        # Angular 21 (LTS actual)
ng-docker new legacy-app 8     # Angular 8
ng-docker new otro-proyecto 17 # Angular 17
```

### Crear proyecto con Vite (más ligero)

```bash
# Sintaxis: ng-docker vite <nombre>
ng-docker vite mi-app
```

Esto crea un proyecto Angular usando el template oficial de Vite (`npm create vite@latest` con `angular-ts`). Es más ligero y rápido que Angular CLI.

| Característica | `ng-docker new` | `ng-docker vite` |
|----------------|-----------------|------------------|
| Puerto | 4200 | 5173 |
| Bundler | Webpack/esbuild | Vite |
| Setup | Completo | Mínimo |
| Angular CLI | Sí | No |
| Tamaño | Mayor | Menor |

### Dockerizar proyecto existente

```bash
# Detecta versión automáticamente del package.json
ng-docker /home/usuario/proyectos/mi-proyecto-angular

# Especificar versión manualmente
ng-docker /ruta/al/proyecto 17
```

El script genera automáticamente:
- `Dockerfile` (con Node compatible)
- `docker-compose.yml`
- `.dockerignore`
- `Makefile`

## Múltiples Proyectos Simultáneos

Cada proyecto puede correr en un puerto diferente:

```bash
# Terminal 1 - Puerto 4200 (default)
cd proyecto-angular-21
make start

# Terminal 2 - Puerto 4201
cd proyecto-angular-17
PORT=4201 make start

# Terminal 3 - Puerto 4202
cd proyecto-legacy-8
PORT=4202 make start
```

## Compatibilidad de Versiones

| Angular | Node | Ejemplo |
|---------|------|---------|
| 8-10 | 12 | `ng-docker new app 8` |
| 11-12 | 14 | `ng-docker new app 12` |
| 13-15 | 16 | `ng-docker new app 15` |
| 16-17 | 20 | `ng-docker new app 17` |
| 18-21 | 22 | `ng-docker new app 21` |

## Comandos Make (dentro del proyecto)

### Contenedor

| Comando | Descripción |
|---------|-------------|
| `make start` | Construye y levanta el contenedor |
| `make up` | Levanta sin reconstruir |
| `make down` | Detiene el contenedor |
| `make logs` | Muestra logs en tiempo real |
| `make shell` | Accede al shell del contenedor |
| `make share` | Comparte localhost con URL pública |

### Angular CLI

```bash
# Generar componente
make ng cmd="generate component home"

# Generar servicio
make ng cmd="generate service api"

# Cualquier comando ng
make ng cmd="add @angular/material"
```

### NPM

```bash
# Instalar dependencia
make npm cmd="install axios"

# Instalar dev dependency
make npm cmd="install -D prettier"
```

### Build y Test

| Comando | Descripción |
|---------|-------------|
| `make test` | Ejecuta tests unitarios |
| `make build-prod` | Build de producción |

## Ejemplo Completo

```bash
# 1. Crear proyecto desde cualquier carpeta
cd ~/proyectos
ng-docker new mi-tienda 21

# 2. Entrar y levantar
cd mi-tienda
make start

# 3. Desarrollar (hot reload automático)
# Edita archivos en src/

# 4. Crear componentes
make ng cmd="generate component header"
make ng cmd="generate service products"

# 5. Instalar librerías
make npm cmd="install @angular/material"

# 6. Entrar al shell para comandos complejos
make shell
> ng add @angular/material
> exit

# 7. Detener
make down
```

## Estructura de Proyecto Generado

```
mi-proyecto/
├── Dockerfile          # Node + Angular CLI
├── docker-compose.yml  # Configuración del contenedor
├── Makefile           # Comandos simplificados
├── .dockerignore      # Exclusiones para Docker
├── src/               # Código Angular
├── package.json
└── angular.json
```

## Compartir tu localhost (Cloudflare Tunnel)

Comparte tu proyecto local con cualquier persona en segundos, con una URL pública HTTPS. Sin registro ni costo.

`cloudflared` viene incluido en el contenedor Docker, no necesitas instalar nada adicional.

### Uso

```bash
# Asegúrate de tener el proyecto corriendo
make start

# En otra terminal, comparte tu localhost
make share
```

Obtendrás una URL como `https://random-name.trycloudflare.com` que puedes compartir.

### Compartir en puerto diferente

```bash
# Si tu proyecto corre en otro puerto
make share port=4201
```

### Configuración de allowedHosts

Los proyectos creados con `ng-docker` ya vienen configurados para funcionar con Cloudflare Tunnel.

Si tienes un proyecto existente y ves el error `"Blocked request. This host is not allowed"`, agrega esta configuración en tu `angular.json`:

```json
{
  "serve": {
    "builder": "@angular/build:dev-server",
    "options": {
      "allowedHosts": [".trycloudflare.com"]
    }
  }
}
```

Luego reinicia el contenedor:

```bash
make down
make start
```

## Notas

- Hot reload funciona automáticamente
- `node_modules` vive en volumen Docker (mejor rendimiento)
- No necesitas Node.js instalado en WSL2
- Cada proyecto es independiente con su propia versión
- Usa `make share` para compartir tu localhost con una URL pública
