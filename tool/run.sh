#!/usr/bin/env bash
# 자주 사용하는 실행 예제 (기본값: dev / ios / debug, 지정 기기가 있으면 플랫폼 추론)
#   ./tool/run.sh
#   ./tool/run.sh dev                       # 개발 환경, iOS
#   ./tool/run.sh stage ios                 # 스테이징 환경, iOS
#   ./tool/run.sh dev android               # 개발 환경, Android
#   ./tool/run.sh dev web                   # 개발 환경, Chrome
#   ./tool/run.sh --debug                   # 디버그 모드 (기본값)
#   ./tool/run.sh prod ios --release        # 배포 모드, Firebase/RevenueCat 설정 필수
#   ./tool/run.sh --device-id=<DEVICE_ID>   # flutter devices에서 확인한 ID로 교체
#   ./tool/run.sh dev web --device-id=chrome
#   ./tool/run.sh --dart-define=FEATURE_ENABLED=true
#   ./tool/run.sh --help
# 환경: dev | stage | prod / 플랫폼: android | ios | web
# CLASSFLOW_ENV는 환경 인자로 자동 설정되므로 --dart-define으로 지정하지 않습니다.
# 터미널에서 다음 명령을 실행하면 Flutter가 인식한 디바이스와 ID를 확인할 수 있습니다.
#   $ flutter devices --machine
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/_environment.sh"
source "${SCRIPT_DIR}/_check_firebase.sh"
source "${SCRIPT_DIR}/_check_revenuecat.sh"
source "${SCRIPT_DIR}/_execution_timing.sh"

usage() { echo "사용법: ./tool/run.sh [dev|stage|prod] [android|ios|web] [--debug|--release] [--device-id=ID] [--dart-define=KEY=VALUE] (기본값: dev ios, 지정 기기가 있으면 플랫폼 추론)"; }
ENV_INPUT="dev"
PLATFORM="ios"
PLATFORM_EXPLICIT=false
if [[ $# -gt 0 && "$1" != -* ]]; then
  ENV_INPUT="$1"
  shift
fi
if [[ $# -gt 0 && "$1" != -* ]]; then
  PLATFORM="$1"
  PLATFORM_EXPLICIT=true
  shift
fi
resolve_classflow_environment "${ENV_INPUT}"
require_platform "${PLATFORM}"

RUN_MODE="debug"
DEVICE_ID="${CLASSFLOW_DEVICE_ID:-}"
DEVICE_SOURCE="VS Code 선택"
EXTRA_DART_DEFINES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) RUN_MODE="debug" ;;
    --release) RUN_MODE="release" ;;
    --device-id=*) DEVICE_ID="${1#--device-id=}"; DEVICE_SOURCE="명령행 지정"; [[ -n "${DEVICE_ID}" ]] || { echo "[오류] --device-id 값이 비어 있습니다." >&2; exit 2; } ;;
    --vscode-device-id=*)
      vscode_device_id="${1#--vscode-device-id=}"
      if [[ -n "${vscode_device_id}" && "${DEVICE_SOURCE}" != "명령행 지정" ]]; then
        DEVICE_ID="${vscode_device_id}"
        DEVICE_SOURCE="VS Code 선택"
      fi
      ;;
    --dart-define=CLASSFLOW_ENV=*) echo "[오류] CLASSFLOW_ENV는 환경 인자에서 자동 설정됩니다." >&2; exit 2 ;;
    --dart-define=*) EXTRA_DART_DEFINES+=("$1") ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[오류] 알 수 없는 옵션: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${PLATFORM}" != "web" || -n "${DEVICE_ID}" ]]; then
  devices_json="$(flutter devices --machine)"
  if ! selected_device="$(printf '%s' "${devices_json}" | python3 -c '
import json
import sys

platform, requested_id, explicit = sys.argv[1:]
try:
    devices = json.load(sys.stdin)
    if not isinstance(devices, list):
        raise ValueError("기기 목록은 배열이어야 합니다.")
except (ValueError, TypeError) as error:
    print("[오류] 기기 목록을 읽을 수 없습니다: {}".format(error), file=sys.stderr)
    raise SystemExit(1)

for device in devices:
    if not device.get("isSupported", True):
        continue
    target = device.get("targetPlatform", "")
    if target == "ios":
        device_platform = "ios"
    elif target.startswith("android-"):
        device_platform = "android"
    elif target.startswith("web-"):
        device_platform = "web"
    else:
        continue
    device_id = device.get("id", "")
    if not device_id:
        continue
    if requested_id:
        if device_id != requested_id:
            continue
        if explicit == "true" and device_platform != platform:
            print("[오류] 지정한 플랫폼 {}과 기기 {}의 플랫폼 {}이 일치하지 않습니다.".format(
                platform, requested_id, device_platform), file=sys.stderr)
            raise SystemExit(1)
    elif device_platform != platform:
        continue
    print("{}\t{}\t{}".format(device_platform, device_id, device.get("name") or device_id))
    break
else:
    print("[오류] 실행 가능한 {} 기기가 없습니다. flutter devices로 확인하세요.".format(
        requested_id or platform), file=sys.stderr)
    raise SystemExit(1)
  ' "${PLATFORM}" "${DEVICE_ID}" "${PLATFORM_EXPLICIT}")"; then
    exit 1
  fi
  if [[ -z "${DEVICE_ID}" ]]; then DEVICE_SOURCE="자동 선택"; fi
  IFS=$'\t' read -r PLATFORM DEVICE_ID DEVICE_NAME <<< "${selected_device}"
  echo "[기기] ${PLATFORM} ${DEVICE_SOURCE}: ${DEVICE_ID} (${DEVICE_NAME})"
else
  DEVICE_ID="chrome"
fi

RUN_ARGS=(--"${RUN_MODE}" --dart-define=CLASSFLOW_ENV="${CLASSFLOW_ENV}")
if [[ "${RUN_MODE}" == "release" || -f "${REPO_ROOT}/config/firebase/${CLASSFLOW_ENV}/${PLATFORM}.json" ]]; then
  check_required_firebase_config "${PLATFORM}" "${CLASSFLOW_ENV}"
  RUN_ARGS+=(--dart-define-from-file="${FIREBASE_DEFINE_FILE}")
else
  echo "[안내] Firebase 설정이 없어 초기화 없이 실행합니다. config/firebase/${CLASSFLOW_ENV}/${PLATFORM}.json을 추가하면 자동 연동됩니다."
fi
if [[ "${RUN_MODE}" == "release" || -f "${REPO_ROOT}/config/revenuecat/${CLASSFLOW_ENV}.json" ]]; then
  check_required_revenuecat_define_file "${CLASSFLOW_ENV}"
  RUN_ARGS+=(--dart-define-from-file="${REVENUECAT_DEFINE_FILE}")
else
  echo "[안내] RevenueCat define 설정 없이 실행합니다."
fi
if [[ ${#EXTRA_DART_DEFINES[@]} -gt 0 ]]; then
  RUN_ARGS+=("${EXTRA_DART_DEFINES[@]}")
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
