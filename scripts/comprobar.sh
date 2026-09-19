#!/usr/bin/env bash
# Comprobación rápida del estado del despliegue.
set -uo pipefail

cd "$(dirname "$0")/.."

ok() { echo "  OK    $1"; }
ko() { echo "  FALLO $1"; }

echo
echo "Servicios"
for svc in postgres redis n8n-main n8n-worker n8n-webhook caddy; do
	estado="$(docker compose ps --format '{{.State}}' "$svc" 2>/dev/null | head -1)"
	if [[ "$estado" == "running" ]]; then ok "$svc"; else ko "$svc (${estado:-no existe})"; fi
done

echo
echo "Base de datos"
if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-n8n}" >/dev/null 2>&1; then
	ok "postgres acepta conexiones"
	filas="$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-n8n}" -d "${POSTGRES_DB:-n8n}" \
		-tAc 'SELECT count(*) FROM execution_entity;' 2>/dev/null || echo '?')"
	echo "  INFO  ejecuciones almacenadas: ${filas}"
else
	ko "postgres no responde"
fi

echo
echo "Cola"
if docker compose exec -T redis sh -c 'redis-cli -a "$REDIS_PASSWORD" ping' 2>/dev/null | grep -q PONG; then
	ok "redis responde"
	politica="$(docker compose exec -T redis sh -c \
		'redis-cli -a "$REDIS_PASSWORD" config get maxmemory-policy' 2>/dev/null | tail -1)"
	if [[ "$politica" == "noeviction" ]]; then
		ok "maxmemory-policy = noeviction"
	else
		ko "maxmemory-policy = ${politica} (debe ser noeviction o se pierden trabajos)"
	fi
	pendientes="$(docker compose exec -T redis sh -c \
		'redis-cli -a "$REDIS_PASSWORD" llen bull:jobs:wait' 2>/dev/null | tail -1)"
	echo "  INFO  trabajos en espera: ${pendientes:-0}"
else
	ko "redis no responde"
fi

echo
echo "Clave de cifrado"
claves="$(for s in n8n-main n8n-worker n8n-webhook; do
	docker compose exec -T "$s" printenv N8N_ENCRYPTION_KEY 2>/dev/null
done | sort -u | wc -l | tr -d ' ')"
if [[ "$claves" == "1" ]]; then
	ok "idéntica en main, worker y webhook"
else
	ko "difiere entre servicios: las credenciales fallarán"
fi

echo
