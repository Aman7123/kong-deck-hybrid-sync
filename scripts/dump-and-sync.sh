#!/bin/bash
NAME="dump-and-sync"
KONG_WORKSPACE=${KONG_WORKSPACE:-default}
KONG_DP_ADMIN_URL=${KONG_DP_ADMIN_URL}
KONG_CP_ADMIN_URL=${KONG_CP_ADMIN_URL}
KONG_CP_ADMIN_TOKEN=${KONG_CP_ADMIN_TOKEN}
DS_FILE_NAME=${DS_FILE_NAME:-dump.yaml}
DS_FILE_PATH=${DS_FILE_PATH:-/tmp}
DS_DEBUG=${DS_DEBUG:-false}
VERBOSE=${VERBOSE:-false}
if [ $VERBOSE == "true" ]; then
  set -x
fi
if [ -z "$KONG_DP_ADMIN_URL" ]; then
  echo "Using in container env to build local admin api url. This might not work."
  KONG_DP_ADMIN_URL="http://${KONG_DP_KONG_ADMIN_SERVICE_HOST}:${KONG_DP_KONG_ADMIN_SERVICE_PORT}"
fi
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Starting..."
  echo "KONG_WORKSPACE=${KONG_WORKSPACE}"
  echo "KONG_DP_ADMIN_URL=${KONG_DP_ADMIN_URL}"
  echo "KONG_CP_ADMIN_URL=${KONG_CP_ADMIN_URL}"
  echo "KONG_CP_ADMIN_TOKEN=${KONG_CP_ADMIN_TOKEN}"
fi
if [ -z "$KONG_DP_ADMIN_URL" ] || [ -z "$KONG_CP_ADMIN_URL" ] || [ -z "$KONG_CP_ADMIN_TOKEN" ]; then
  echo "ERROR [$NAME]: Missing required env variables KONG_DP_ADMIN_URL, KONG_CP_ADMIN_URL, or KONG_CP_ADMIN_TOKEN. Exiting."
  exit 1
fi

# CP
# Ping
PING_OUTPUT=$(deck ping --kong-addr ${KONG_DP_ADMIN_URL} --workspace ${KONG_WORKSPACE} --timeout 60 --tls-skip-verify)
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Ping output CP: ${PING_OUTPUT}"
fi
DUMP_OUTPUT=$(deck dump --output-file ${DS_FILE_PATH}/${DS_FILE_NAME} --kong-addr ${KONG_DP_ADMIN_URL} --workspace ${KONG_WORKSPACE} --yes --tls-skip-verify)

# DP
KONG_TOKEN_VALUE=""
if [ -n "$KONG_CP_ADMIN_TOKEN" ]; then
  KONG_TOKEN_VALUE="--headers kong-admin-token:${KONG_CP_ADMIN_TOKEN}"
fi
# Ping
PING_OUTPUT=$(deck ping --kong-addr ${KONG_CP_ADMIN_URL} --workspace ${KONG_WORKSPACE} --timeout 60 --tls-skip-verify ${KONG_TOKEN_VALUE})
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Ping output DP: ${PING_OUTPUT}"
fi
# Reset
RESET_OUTPUT=$(deck reset --kong-addr ${KONG_CP_ADMIN_URL} --workspace ${KONG_WORKSPACE} --tls-skip-verify ${KONG_TOKEN_VALUE} --force)
# Sync
SYNC_OUTPUT=$(deck sync --state ${DS_FILE_PATH}/${DS_FILE_NAME} --kong-addr ${KONG_CP_ADMIN_URL} --workspace ${KONG_WORKSPACE} --tls-skip-verify --silence-events ${KONG_TOKEN_VALUE})
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Sync output: ${SYNC_OUTPUT}"
fi