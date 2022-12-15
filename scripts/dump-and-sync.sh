#!/bin/bash
NAME="dump-and-sync"
KONG_DP_WORKSPACE=${KONG_DP_WORKSPACE:-default}
KONG_CP_WORKSPACE=${KONG_CP_WORKSPACE:-default}
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

# 
# DP
# 
# DP Ping
CP_PING_OUTPUT=$(deck ping --kong-addr ${KONG_DP_ADMIN_URL} --workspace ${KONG_DP_WORKSPACE} --timeout 60 --tls-skip-verify)
CP_PING_STATUS=$?
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Ping output CP: ${CP_PING_OUTPUT}"
fi
if [ $CP_PING_STATUS -ne 0 ]; then
  echo "ERROR [$NAME]: Deck ping to CP failed. Exiting."
  exit 1
fi
# 
# DP Dump
DUMP_OUTPUT=$(deck dump --output-file ${DS_FILE_PATH}/${DS_FILE_NAME} --kong-addr ${KONG_DP_ADMIN_URL} --workspace ${KONG_DP_WORKSPACE} --yes --tls-skip-verify)
DUMP_STATUS=$?
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: dump exit code: ${DUMP_STATUS}"
fi
if [ $DUMP_STATUS -ne 0 ]; then
  echo "ERROR [$NAME]: Deck dump failed. Exiting."
  exit 1
fi


# Shift focus to the DP now that we have the dump file
# 
# DP
KONG_TOKEN_VALUE=""
if [ -n "$KONG_CP_ADMIN_TOKEN" ]; then
  KONG_TOKEN_VALUE="--headers kong-admin-token:${KONG_CP_ADMIN_TOKEN}"
fi
# 
# DP Ping
DP_PING_OUTPUT=$(deck ping --kong-addr ${KONG_CP_ADMIN_URL} --workspace ${KONG_CP_WORKSPACE} --timeout 60 --tls-skip-verify ${KONG_TOKEN_VALUE})
DP_PING_STATUS=$?
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Ping output DP: ${DP_PING_OUTPUT}"
fi
if [ $DP_PING_STATUS -ne 0 ]; then
  echo "ERROR [$NAME]: Deck ping to DP failed. Exiting."
  exit 1
fi
# To prevent collision wait between 1 and 14 seconds
COLLISION_SLEEP=$((1 + $RANDOM % 7) + (1 + $RANDOM % 7))
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Sleeping ${COLLISION_SLEEP} seconds before running diff check. For concurrency elimination."
fi
sleep $COLLISION_SLEEP
# 
# DP Diff
DIFF_OUTPUT=$(deck diff --state ${DS_FILE_PATH}/${DS_FILE_NAME} --kong-addr ${KONG_CP_ADMIN_URL} --workspace ${KONG_CP_WORKSPACE} --tls-skip-verify --non-zero-exit-code ${KONG_TOKEN_VALUE})
DIFF_STATUS=$?
# exit code 2 if there is a diff present
# exit code 0 if no diff is found
# exit code 1 if an error occurs
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Diff output: ${DIFF_OUTPUT}"
fi
if [ $DIFF_STATUS -ne 2 ]; then
  echo "INFO [$NAME]: No diff. Exiting."
  exit 0
fi
# 
# DP Sync
SYNC_OUTPUT=$(deck sync --state ${DS_FILE_PATH}/${DS_FILE_NAME} --kong-addr ${KONG_CP_ADMIN_URL} --workspace ${KONG_CP_WORKSPACE} --tls-skip-verify --silence-events ${KONG_TOKEN_VALUE})
SYNC_STATUS=$?
if [ $DS_DEBUG == "true" ]; then
  echo "DEBUG [$NAME]: Sync output: ${SYNC_OUTPUT}"
fi
if [ $SYNC_STATUS -ne 0 ]; then
  echo "ERROR [$NAME]: Deck sync failed. Exiting."
  exit 1
fi