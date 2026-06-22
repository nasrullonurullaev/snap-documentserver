#!/usr/bin/env bash
set -euo pipefail

: "${SNAP_NAME:?SNAP_NAME is required}"
: "${SCENARIO:?SCENARIO is required}"

install_snapd() {
  echo "==> Ensure snapd is installed"
  if command -v snap >/dev/null 2>&1; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y snapd
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y snapd
  elif command -v yum >/dev/null 2>&1; then
    yum install -y snapd
  else
    echo "No supported package manager found for snapd installation" >&2
    exit 1
  fi

  systemctl enable --now snapd.socket
  ln -sfn /var/lib/snapd/snap /snap
  snap wait system seed.loaded
}

wait_for_snapd() {
  echo "==> Wait for snapd to become idle"
  for attempt in {1..60}; do
    if ! snap changes | awk 'NR > 1 && $2 == "Doing" { found = 1 } END { exit found ? 0 : 1 }'; then
      return
    fi

    echo "snapd is still busy ($attempt/60)..."
    sleep 5
  done

  echo "snapd still has changes in progress:" >&2
  snap changes >&2 || true
  return 1
}

install_local_snap() {
  local allow_existing_install=${1:-false}

  echo "==> Install local snap artifact"
  if snap install --dangerous ./${SNAP_NAME}_*.snap; then
    wait_for_snapd
    return
  fi

  if [ "$allow_existing_install" = true ] && snap list "$SNAP_NAME" >/dev/null 2>&1; then
    echo "${SNAP_NAME} is installed despite the non-zero snap install exit code" >&2
    wait_for_snapd
    return
  fi

  return 1
}

install_store_snap() {
  echo "==> Install current stable snap from the store"
  snap install "$SNAP_NAME"
  wait_for_snapd
}

prepare_for_refresh() {
  echo "==> Prepare installed snap for local refresh"
  snap stop "$SNAP_NAME" || true
  wait_for_snapd
  rm -rf "/tmp/snap-private-tmp/snap.${SNAP_NAME}"
}

run_clean_scenario() {
  install_local_snap true
}

run_upgrade_scenario() {
  install_store_snap
  prepare_for_refresh
  install_local_snap
  snap start "$SNAP_NAME"
  wait_for_snapd
}

run_scenario() {
  echo "==> Run ${SCENARIO} scenario"
  case "$SCENARIO" in
    clean) run_clean_scenario ;;
    upgrade) run_upgrade_scenario ;;
    *)
      echo "Unknown scenario: $SCENARIO" >&2
      exit 1
      ;;
  esac
}

require_service_active() {
  local service="$1"
  snap services "$SNAP_NAME" | awk -v svc="$service" '
    $1 == svc { found = 1; state = $3 }
    END { exit !(found && state == "active") }
  '
}

check_services() {
  echo "==> Check snap services"
  snap services "$SNAP_NAME"
  require_service_active "${SNAP_NAME}.nginx"
  require_service_active "${SNAP_NAME}.documentserver"
}

install_snapd
run_scenario
check_services
