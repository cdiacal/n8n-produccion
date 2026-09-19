#!/usr/bin/env bash
# Genera .env a partir de .env.example con secretos aleatorios.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
	echo "Ya existe un fichero .env. No lo sobrescribo."
	echo "Si quieres regenerarlo, muévelo primero: mv .env .env.bak"
	exit 1
fi

gen() { openssl rand -hex 32; }

ENCRYPTION_KEY="$(gen)"
POSTGRES_PASSWORD="$(gen)"
REDIS_PASSWORD="$(gen)"

sed \
	-e "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}|" \
	-e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
	-e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=${REDIS_PASSWORD}|" \
	.env.example >.env

chmod 600 .env

cat <<EOF

.env creado.

Falta editar a mano:
  N8N_HOST   -> tu dominio real

=====================================================================
 GUARDA ESTO FUERA DEL SERVIDOR ANTES DE ARRANCAR NADA:

 N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}

 Sin esta clave, un backup de la base de datos es inservible:
 las credenciales no se pueden descifrar y hay que reintroducirlas
 todas a mano.
=====================================================================

EOF
