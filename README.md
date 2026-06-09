# Angular Dockerizado

Entorno de desarrollo Angular completamente dockerizado. No requiere instalar Node.js ni Angular CLI en tu sistema.

## Requisitos

- Docker
- Docker Compose
- Make (opcional)

## Instalación Global (Recomendado)

Para usar el comando `ng-docker` desde cualquier ubicación, crea un enlace simbólico:

```bash
cd /ruta/a/generador-docker-angular
sudo ln -s $(pwd)/dockerize.sh /usr/local/bin/ng-docker

# Ahora puedes usarlo desde cualquier carpeta:
ng-docker new mi-proyecto
```

> El enlace simbólico solo se crea una vez.

## Inicio Rápido

### Opción 1: Script (desde cualquier lugar)

```bash
# Crear proyecto con la última versión de Angular (recomendado)
ng-docker new mi-app

# Crear proyecto con versión específica
ng-docker new mi-app 18

# Dockerizar proyecto existente
ng-docker /ruta/a/mi-proyecto
```

### Opción 2: Make (desde esta carpeta)

```bash
# Última versión de Angular (detecta automáticamente)
make install name=mi-app
make init

# Versión específica
make install name=mi-app v=18
make init v=18
```

### Levantar el proyecto

```bash
cd mi-app
make start

# Abrir en navegador
http://localhost:4200
```

## Detección automática de versiones

Cuando no se especifica versión, `ng-docker` consulta automáticamente el registro de npm para obtener la **última versión estable de Angular CLI** al momento de ejecutar el comando, y selecciona la imagen de Node.js compatible.

```bash
ng-docker new mi-app
# → Consultando última versión de Angular CLI en npm...
# → Usando Angular 22 (última disponible)
# → Creando proyecto Angular 22 con Node 24...
```

No es necesario saber qué versión usar; el generador lo resuelve por ti.

## Uso del Script ng-docker

### Crear proyecto nuevo (Angular CLI)

```bash
# Última versión (recomendado)
ng-docker new mi-app

# Versión específica
ng-docker new legacy-app 8
ng-docker new otro-proyecto 17
```

### Crear proyecto con Vite (interactivo)

```bash
ng-docker vite mi-app
```

Ejecuta `npm create vite@latest` de forma interactiva. Puedes elegir framework (Vanilla, Vue, React, Svelte…) y variante (JavaScript o TypeScript).

| Característica | `ng-docker new` | `ng-docker vite` |
|----------------|-----------------|------------------|
| Puerto | 4200 | 5173 |
| Bundler | esbuild | Vite |
| Framework | Angular | Cualquiera |
| Setup | Completo | Mínimo |

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

## Compatibilidad de Versiones

| Angular | Node | Imagen Docker | Notas |
|---------|------|---------------|-------|
| 8–10 | 12 | `node:12-slim` | |
| 11–12 | 14 | `node:14-slim` | |
| 13–15 | 16 | `node:16-slim` | |
| 16–17 | 20 | `node:20-slim` | |
| 18–21 | 22 | `node:22-slim` | |
| 22+ | 24 | `node:24-slim` | Ver nota abajo |

> **Angular 22+ requiere Node 24:** Angular 22 exige Node v22.22.3 como mínimo, pero la imagen `node:22-slim` disponible en Docker Hub trae v22.22.0. Para evitar este error se usa `node:24-slim`, que supera ese requisito holgadamente.
>
> Síntoma del error:
> ```
> Node.js version v22.22.0 detected.
> The Angular CLI requires a minimum Node.js version of v22.22.3 or v24.15.0 or v26.0.0.
> ```

## Características del Entorno Docker

### Imagen base Debian Slim

Se usa `node:XX-slim` (Debian) en lugar de Alpine para compatibilidad con Chromium y dependencias nativas.

### Usuario no-root

El contenedor ejecuta como usuario `node` en lugar de `root`. El UID/GID es configurable:

```bash
UID=1001 GID=1001 make start
```

### node_modules local

Los `node_modules` se comparten entre el host y el contenedor mediante el volumen montado. Esto permite que tu IDE tenga acceso completo a las dependencias para autocompletado e IntelliSense.

```bash
make npm-install
```

### Tests Headless con Chromium

Chromium viene preinstalado para ejecutar tests unitarios en modo headless.

```bash
make test           # watch mode
make test-headless  # una sola vez (CI)
```

### Límite de memoria

Cada contenedor tiene un límite de 4 GB de RAM configurado en `docker-compose.yml`.

## Múltiples Proyectos Simultáneos

```bash
cd proyecto-a && make start          # puerto 4200
cd proyecto-b && PORT=4201 make start
cd proyecto-c && PORT=4202 make start
```

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
make ng cmd="generate component home"
make ng cmd="generate service api"
make ng cmd="add @angular/material"
```

### NPM

```bash
make npm cmd="install axios"
make npm cmd="install -D prettier"
make npm-install   # instala en node_modules local
```

### Build y Test

| Comando | Descripción |
|---------|-------------|
| `make test` | Tests en watch mode (headless) |
| `make test-headless` | Tests una sola vez (CI mode) |
| `make build` | Build de desarrollo |
| `make build-prod` | Build de producción |

## Ejemplo Completo

```bash
# 1. Crear proyecto (detecta la última versión de Angular automáticamente)
cd ~/proyectos
ng-docker new mi-tienda

# 2. Entrar y levantar
cd mi-tienda
make start

# 3. Crear componentes y servicios
make ng cmd="generate component header"
make ng cmd="generate service products"

# 4. Instalar librerías
make npm cmd="install @angular/material"

# 5. Ejecutar tests
make test

# 6. Build de producción
make build-prod

# 7. Detener
make down
```

## Estructura de Proyecto Generado

```
mi-proyecto/
├── Dockerfile          # Node + Angular CLI + Chromium
├── docker-compose.yml  # Configuración del contenedor
├── Makefile            # Comandos simplificados
├── .dockerignore       # Exclusiones para Docker
├── src/                # Código Angular
├── package.json
└── angular.json        # Con allowedHosts para Cloudflare Tunnel
```

## Compartir tu localhost (Cloudflare Tunnel)

`cloudflared` viene incluido en el contenedor. No necesitas instalar nada adicional.

```bash
make start   # proyecto corriendo
make share   # obtén una URL pública HTTPS
```

Obtendrás una URL como `https://random-name.trycloudflare.com`.

```bash
# Puerto diferente
make share port=4201
```

### Configuración de allowedHosts

Los proyectos creados con `ng-docker` ya vienen preconfigurados para funcionar con Cloudflare Tunnel. Si tienes un proyecto existente y ves el error `"Blocked request. This host is not allowed"`, agrega esto en `angular.json`:

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

Luego reinicia:

```bash
make down && make start
```

## Notas

- Hot reload funciona automáticamente
- `node_modules` se comparte con el host (autocompletado en IDE)
- No necesitas Node.js instalado en tu sistema
- Cada proyecto es independiente con su propia versión de Angular y Node
- El contenedor ejecuta como usuario no-root por seguridad
- Límite de 4 GB de RAM por contenedor
