#!/usr/bin/env bash
# Staging deploy / rollback for the frontend image (DDP-#49 / DKR-06).
#
# Runs ON THE STAGING HOST, invoked over SSH by .github/workflows/deploy.yml:
#
#   ssh staging 'bash -s -- "$SHA" "$TOKEN" "$IMAGE" "$USER" "$DIR" "$ROLLBACK"' \
#     < scripts/deploy-staging.sh
#
# Behaviour:
#   - upserts FRONTEND_IMAGE=<image>:sha-<sha> in .env (desired state stays on
#     the host for manual operations; never :latest)
#   - pulls ONLY the frontend image (backend/chatbot/db were provisioned once)
#   - recreates just the frontend container (--no-build) and waits for its
#     healthcheck plus functional endpoint checks
#   - on failure: rolls back to the previously deployed SHA (unless disabled),
#     leaving the stack on the last known-good image
#
# Required host bootstrap (one time, see README "Staging on EC2"):
#   Docker + Compose v2, /opt/onecare containing docker-compose.yml,
#   docker-compose.prod.yml and a populated .env, backend/chatbot images
#   built once.
set -euo pipefail

IMAGE_SHA="${1:?usage: deploy-staging.sh <image_sha> <ghcr_token> <image> <ghcr_user> [remote_dir] [auto_rollback]}"
GHCR_PULL_TOKEN="${2:?missing ghcr pull token}"
IMAGE="${3:?missing image (ghcr.io/<owner>/onecare-frontend)}"
GHCR_USER="${4:?missing ghcr username}"
REMOTE_DIR="${5:-/opt/onecare}"
AUTO_ROLLBACK="${6:-true}"

CONTAINER=onecare-frontend

log() { printf '[deploy] %s\n' "$*"; }

cd "$REMOTE_DIR"
[ -f .env ] || { log "ERROR: no .env in $REMOTE_DIR (host not bootstrapped?)"; exit 1; }
[ -f docker-compose.yml ] || { log "ERROR: no docker-compose.yml in $REMOTE_DIR"; exit 1; }

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml)

current_image() {
  grep -E '^FRONTEND_IMAGE=' .env | head -n1 | cut -d= -f2- || true
}

# upsert so older .env files without the variable still work
upsert_env() {
  local key="$1" val="$2"
  if grep -qE "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" .env
  else
    printf '\n# set by deploy-staging.sh (DDP-#49 / DKR-06)\n%s=%s\n' "$key" "$val" >> .env
  fi
  log "${key} -> ${val}"
}

set_image() {
  upsert_env FRONTEND_IMAGE "$1"
}

wait_healthy() {
  log "waiting for $CONTAINER health..."
  local i status
  for i in $(seq 1 30); do
    status="$(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo missing)"
    case "$status" in
      healthy) log "healthy after ~$((i * 5))s"; return 0 ;;
      missing) log "container not created yet" ;;
      *) log "health: $status" ;;
    esac
    sleep 5
  done
  docker logs --tail 40 "$CONTAINER" || true
  return 1
}

check_endpoints() {
  local port code base body
  port="$(grep -E '^FRONTEND_PORT=' .env | head -n1 | cut -d= -f2-)"
  port="${port:-3000}"
  base="http://127.0.0.1:${port}"

  code="$(curl -fsS -o /dev/null -w '%{http_code}' "$base/healthz" || echo 000)"
  [ "$code" = "200" ] || { log "/healthz returned $code"; return 1; }
  log "/healthz -> 200"

  body="$(curl -fsS "$base/config.json" | tr -d ' \n' || true)"
  case "$body" in
    *apiBaseUrl*:*) log "/config.json served ($body)" ;;
    *) log "/config.json missing or invalid: '$body'"; return 1 ;;
  esac

  # DDP-#49: any 200 counts - DEGRADED (e.g. SMTP unreachable) is deliberately
  # HTTP 200 so it must never fail a deploy (AC4); only DOWN (503, MySQL/Redis)
  # fails. The prod layer binds the backend on 127.0.0.1:BACKEND_PORT.
  bport="$(grep -E '^BACKEND_PORT=' .env | head -n1 | cut -d= -f2-)"
  bport="${bport:-8080}"
  code="$(curl -fsS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${bport}/actuator/health" || echo 000)"
  [ "$code" = "200" ] || { log "/actuator/health returned $code (expected 200)"; return 1; }
  log "/actuator/health -> 200 (UP or DEGRADED)"

  # Any non-502/504 answer proves nginx reached the backend through the
  # service DNS (401/404/405 are all valid Spring responses).
  code="$(curl -s -o /dev/null -w '%{http_code}' "$base/api/__deploy_probe__")"
  case "$code" in
    502|504) log "backend unreachable through the /api proxy (HTTP $code)"; return 1 ;;
    *) log "/api proxy -> backend answered HTTP $code" ;;
  esac
}

# Returns non-zero on failure (never exits) so the caller can roll back.
deploy_image() {
  local img="$1"
  set_image "$img"
  # The staging host must always run the staging profile (AC3), even when
  # .env was refreshed from .env.example (which says dev).
  upsert_env SPRING_PROFILES_ACTIVE staging
  echo "$GHCR_PULL_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin >/dev/null 2>&1 \
    || { log "ghcr login failed"; return 1; }
  log "pulling $img"
  "${COMPOSE[@]}" pull frontend || { log "pull failed for $img"; return 1; }
  log "recreating frontend (--no-build)"
  "${COMPOSE[@]}" up -d --no-build || { log "compose up failed"; return 1; }
  wait_healthy || { log "frontend never became healthy"; return 1; }
  check_endpoints || { log "post-deploy checks failed"; return 1; }
  return 0
}

PREV_IMAGE="$(current_image)"
NEW_IMAGE="${IMAGE}:sha-${IMAGE_SHA}"
log "deploying $NEW_IMAGE (previous: ${PREV_IMAGE:-none})"

if deploy_image "$NEW_IMAGE"; then
  docker image prune -f >/dev/null 2>&1 || true
  log "deploy OK: $NEW_IMAGE"
  log "rollback: re-run the deploy workflow with the previous SHA (${PREV_IMAGE##*:})"
  exit 0
fi

log "deploy FAILED"
if [ "$AUTO_ROLLBACK" = "true" ] && [ -n "$PREV_IMAGE" ] && [ "$PREV_IMAGE" != "$NEW_IMAGE" ]; then
  log "rolling back to $PREV_IMAGE"
  if deploy_image "$PREV_IMAGE"; then
    log "rollback OK - stack restored on $PREV_IMAGE"
    exit 1
  fi
  log "ROLLBACK ALSO FAILED - manual intervention required"
fi
exit 1
