#!/usr/bin/env bash
# ============================================================
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/_environment.sh"
source "${SCRIPT_DIR}/_check_firebase.sh"
source "${SCRIPT_DIR}/_check_revenuecat.sh"
source "${SCRIPT_DIR}/_execution_timing.sh"

usage() { echo "사용법: ./tool/run.sh <dev|stage|prod> <android|ios|web> [--debug|--release] [--device-id=ID] [--dart-define=KEY=VALUE]"; }
if [[ $# -lt 2 ]]; then usage >&2; exit 2; fi
ENV_INPUT="$1"
PLATFORM="$2"
shift 2
resolve_classflow_environment "${ENV_INPUT}"
require_platform "${PLATFORM}"

RUN_MODE="debug"
DEVICE_ID=""
EXTRA_DART_DEFINES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) RUN_MODE="debug" ;;
    --release) RUN_MODE="release" ;;
    --device-id=*) DEVICE_ID="${1#--device-id=}"; [[ -n "${DEVICE_ID}" ]] || { echo "[오류] --device-id 값이 비어 있습니다." >&2; exit 2; } ;;
    --dart-define=CLASSFLOW_ENV=*) echo "[오류] CLASSFLOW_ENV는 환경 인자에서 자동 설정됩니다." >&2; exit 2 ;;
    --dart-define=*) EXTRA_DART_DEFINES+=("$1") ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[오류] 알 수 없는 옵션: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

check_required_firebase_config "${PLATFORM}" "${CLASSFLOW_ENV}"
check_required_revenuecat_define_file "${CLASSFLOW_ENV}"
RUN_ARGS=(--"${RUN_MODE}" --dart-define=CLASSFLOW_ENV="${CLASSFLOW_ENV}" --dart-define-from-file="${FIREBASE_DEFINE_FILE}" --dart-define-from-file="${REVENUECAT_DEFINE_FILE}")
RUN_ARGS+=("${EXTRA_DART_DEFINES[@]}")
if [[ "${PLATFORM}" == "web" ]]; then
  DEVICE_ID="${DEVICE_ID:-chrome}"
elif [[ -z "${DEVICE_ID}" ]]; then
  devices_json="$(flutter devices --machine)"
  device_ids=()
  while IFS= read -r device_id; do
    [[ -n "${device_id}" ]] && device_ids+=("${device_id}")
  done < <(printf '%s' "${devices_json}" | python3 -c '
import json
import sys

platform = sys.argv[1]
devices = json.load(sys.stdin)
for device in devices:
    target = device.get("targetPlatform", "")
    if target.startswith(platform):
        print(device["id"])
  ' "${PLATFORM}")
  if [[ ${#device_ids[@]} -eq 0 ]]; then
    echo "[오류] 연결된 ${PLATFORM} 기기가 없습니다. flutter devices로 확인하세요." >&2
    exit 1
  fi
  if [[ ${#device_ids[@]} -gt 1 ]]; then
    echo "[오류] ${PLATFORM} 기기가 여러 대입니다. --device-id=<device-id>로 대상을 지정하세요." >&2
    printf '  %s\n' "${device_ids[@]}" >&2
    exit 1
  fi
  DEVICE_ID="${device_ids[0]}"
fi
if [[ -n "${DEVICE_ID}" ]]; then RUN_ARGS+=(-d "${DEVICE_ID}"); fi

echo "[실행] ClassFlow ${ENV_INPUT} (${CLASSFLOW_ENV}) / ${PLATFORM}"
start_execution_timing
set +e
flutter run "${RUN_ARGS[@]}"
exit_code=$?
set -e
print_execution_timing
exit "${exit_code}"
