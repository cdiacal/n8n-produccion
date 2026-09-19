# n8n en producción — stack de modo cola

Despliegue de **n8n autoalojado en modo cola**, listo para producción, documentado en español.

La mayoría de guías que hay por ahí despliegan n8n como un contenedor único con SQLite. Eso funciona hasta el día en que llegan varios webhooks a la vez, el editor se congela, una ejecución pesada bloquea el proceso o un redespliegue pierde peticiones. Este repo despliega n8n como lo recomienda su propia documentación para producción: procesos separados, cola real y base de datos real.

---

## Arquitectura

```
                    ┌─────────┐
   internet ──443──▶│  Caddy  │  TLS automático
                    └────┬────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
    /webhook/*                     todo lo demás
          │                             │
          ▼                             ▼
   ┌─────────────┐              ┌─────────────┐
   │ n8n-webhook │              │  n8n-main   │  editor + API
   └──────┬──────┘              └──────┬──────┘
          │                            │
          └────────────┬───────────────┘
                       │ encola
                       ▼
                 ┌──────────┐      ┌──────────────┐
                 │  Redis   │◀────▶│  n8n-worker  │  xN, ejecuta
                 └──────────┘      └──────┬───────┘
                                          │
                                   ┌──────▼──────┐
                                   │ PostgreSQL  │
                                   └─────────────┘
```

| Componente | Función | Escala |
|---|---|---|
| `n8n-main` | Editor, API, triggers programados | 1 réplica |
| `n8n-worker` | Ejecuta los workflows de la cola | N réplicas |
| `n8n-webhook` | Atiende webhooks de producción | N réplicas |
| `redis` | Cola de trabajos (Bull) | 1 |
| `postgres` | Workflows, credenciales, ejecuciones | 1 |
| `caddy` | TLS y enrutado | 1 |

Separar el procesador de webhooks del main es lo que evita que una tanda de peticiones te deje el editor inutilizable.

---

## Requisitos

- Docker y Docker Compose v2
- Un dominio apuntando al servidor (Caddy gestiona el certificado solo)
- Punto de partida razonable: 4 vCPU, 8 GB de RAM, 50 GB de disco

El disco es lo que más se subestima. Con pruning activado, 50 GB aguantan bien; sin pruning, cualquier cifra se queda corta.

---

## Arranque

```bash
git clone https://github.com/TU-USUARIO/n8n-produccion.git
cd n8n-produccion

chmod +x scripts/*.sh
./scripts/generar-secretos.sh     # genera .env con secretos aleatorios
```

Edita `.env` y pon tu dominio en `N8N_HOST`.

**Antes de arrancar**, copia `N8N_ENCRYPTION_KEY` a un gestor de contraseñas fuera del servidor. Sin ella, un backup de la base de datos no sirve para nada: las credenciales no se descifran.

```bash
docker compose up -d
./scripts/comprobar.sh
```

---

## Operación

**Escalar workers.** Sube `WORKER_REPLICAS` en `.env` y aplica:

```bash
docker compose up -d --scale n8n-worker=4
```

Mide antes de escalar. Si la cola crece pero la CPU está ociosa, el cuello no son los workers: es una API externa lenta o un workflow mal hecho.

**Ver el estado de la cola:**

```bash
docker compose exec redis sh -c 'redis-cli -a "$REDIS_PASSWORD" llen bull:jobs:wait'
```

Si ese número crece de forma sostenida, tienes menos capacidad de ejecución que trabajo entrante.

**Actualizar de versión:**

```bash
# 1. backup antes, siempre
# 2. cambia N8N_VERSION en .env
docker compose pull && docker compose up -d
```

Lee siempre las notas de la versión. n8n publica versión menor casi cada semana y las mayores traen cambios incompatibles.

---

## Decisiones y por qué

**Redis con `noeviction`.** Bajo presión de memoria, la política por defecto expulsa claves. Si esas claves son trabajos de la cola, pierdes ejecuciones sin ningún error visible. Con `noeviction`, Redis rechaza escrituras en vez de tirar trabajo: falla ruidosamente, que es lo que quieres.

**PostgreSQL, no SQLite.** SQLite bloquea a nivel de fichero; con varios workers escribiendo, se convierte en el cuello de botella. El modo cola con SQLite directamente no está soportado.

**La clave de cifrado es la misma en los tres servicios.** Si difiere, el worker no puede descifrar las credenciales que guardó el main y los workflows fallan de forma confusa. `comprobar.sh` valida esto explícitamente.

**Versión fijada.** Nada de `:latest`. Un reinicio no debería cambiarte de versión.

**Pruning activado.** La tabla de ejecuciones crece sin límite. Es la causa número uno de instancias que se quedan sin disco.

---

## Qué NO cubre este repo

Esto es un despliegue funcional, no una instalación operada. Queda fuera:

- Backups automatizados y procedimiento de restauración probado
- Gestión de secretos fuera de ficheros `.env` en disco
- Despliegue en Kubernetes con Helm
- Observabilidad: Prometheus, Grafana y alertas de cola atascada o worker caído
- Runbook de incidencias
- Migración desde una instancia única con SQLite sin perder datos

Estoy preparando un paquete que cubre todo eso. Si te interesa, abre un issue o sígueme aquí.

---

## Contribuir

Si esto te ha ahorrado tiempo, dale una estrella. Si te ha fallado algo, abre un issue con tu versión de n8n y la salida de `./scripts/comprobar.sh`.

## Licencia

MIT
