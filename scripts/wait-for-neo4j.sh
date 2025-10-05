#!/usr/bin/env bash
set -euo pipefail

HOST="${NEO4J_HOST:-127.0.0.1}"
PORT_HTTP="${NEO4J_HTTP_PORT:-7474}"

echo "Waiting for Neo4j at http://${HOST}:${PORT_HTTP} ..."
for i in $(seq 1 120); do
  if curl -fsS "http://${HOST}:${PORT_HTTP}" > /dev/null; then
    echo "Neo4j is up"
    exit 0
  fi
  sleep 1
done
echo "Neo4j did not become ready in time" >&2
exit 1

