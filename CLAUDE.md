# Contexto del proyecto

## Qué es esto

Despliegue de n8n autoalojado en **modo cola** para producción, documentado en español. Es la capa gratuita de un producto: el repo público atrae tráfico y sirve de portfolio técnico; la capa de pago (aparte, no en este repo) cubre backups, Kubernetes, observabilidad y runbook.

Público objetivo: gente que ya sabe usar n8n y necesita que no se le caiga. No es un tutorial de iniciación.

## Estado actual

Primera versión sin probar en un servidor real. La sintaxis YAML y de los scripts está validada, pero **nada se ha arrancado todavía**. La prioridad ahora es probar y corregir, no añadir funcionalidad.

## Decisiones tomadas — no revertir sin motivo

- **Redis con `maxmemory-policy noeviction`.** Bajo presión de memoria, la política por defecto expulsa claves; si son trabajos de Bull, se pierden ejecuciones sin error visible.
- **Procesador de webhooks separado del main**, con Caddy enrutando `/webhook/*`, `/webhook-waiting/*`, `/form/*` y `/form-waiting/*` hacia él. Es lo que evita que una tanda de webhooks congele el editor.
- **PostgreSQL, no SQLite.** El modo cola no está soportado sobre SQLite.
- **Versión de n8n fijada** en `.env` (`N8N_VERSION`). Nunca `:latest`.
- **`N8N_ENCRYPTION_KEY` idéntica** en main, worker y webhook. `scripts/comprobar.sh` lo valida explícitamente porque es el fallo que más tiempo hace perder.
- **Pruning de ejecuciones activado.** Causa número uno de instancias sin disco.

## Restricciones

- **Nada de infraestructura del trabajo del autor.** Ni configuraciones, ni nombres de host, ni topologías reales de su empleador. Todo se construye desde cero.
- **Todo en español**, incluidos comentarios y mensajes de los scripts.
- Los comentarios explican **por qué**, no qué. Si una línea no tiene un motivo no obvio, no lleva comentario.
- La sección "Qué NO cubre" del README es intencionada: enumera la capa de pago sin sonar a anuncio. No ampliarla con soluciones.

## Estructura

```
docker-compose.yml          main + workers + webhook + postgres + redis + caddy
.env.example                plantilla de variables
caddy/Caddyfile             TLS y enrutado de webhooks
scripts/generar-secretos.sh genera .env con secretos aleatorios
scripts/comprobar.sh        verifica servicios, cola y clave de cifrado
```

## Tareas pendientes, por orden

1. Arrancar el stack completo en un VPS o en local y corregir lo que falle.
2. Verificar que los webhooks de producción llegan al procesador dedicado y no al main.
3. Romperlo a propósito y documentar el comportamiento real: matar workers en caliente, llenar la cola, cortar Redis, llenar el disco.
4. Confirmar que `WORKER_REPLICAS` en `.env` y `--scale` no se pisan entre sí.
5. Ajustar el README con lo observado, no con lo que dice la documentación oficial.

## Cómo trabajar aquí

Probar antes de escribir. Si una afirmación del README no se ha verificado en una instancia real, marcarla o quitarla. El valor del repo frente a los cien tutoriales existentes es precisamente que esto se ha ejecutado.
