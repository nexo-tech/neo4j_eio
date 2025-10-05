#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Starting Neo4j via docker compose..."
docker compose -f "${REPO_ROOT}/docker-compose.yml" up -d neo4j

export NEO4J_HOST=127.0.0.1
export NEO4J_PORT=7687
export NEO4J_USER=neo4j
export NEO4J_PASSWORD=test
export NEO4J_HTTP_PORT=7474

"${SCRIPT_DIR}/wait-for-neo4j.sh"

echo "Running dune runtest..."
cd "${SCRIPT_DIR}/.."
dune runtest -j 2

