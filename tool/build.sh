#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/_environment.sh"
source "${SCRIPT_DIR}/_check_firebase.sh"
source "${SCRIPT_DIR}/_check_revenuecat.sh"
source "${SCRIPT_DIR}/_execution_timing.sh"

usage() { echo "사용법: ./tool/build.sh <dev|stage|prod> <android|ios|web> [debug|release]"; }
if [[ $# -lt 2 || $# -gt 3 ]]; then usage >&2; exit 2; fi
ENV_INPUT="$1"
PLATFORM="$2"
BUILD_MODE="${3:-}"
resolve_classflow_environment "${ENV_INPUT}"
require_platform "${PLATFORM}"
if [[ -z "${BUILD_MODE}" ]]; then
  if [[ "${CLASSFLOW_ENV}" == "production" ]]; then BUILD_MODE="release"; else BUILD_MODE="debug"; fi
fi
case "${BUILD_MODE}" in
  debug|release) ;;
  *) echo "[오류] 지원하지 않는 빌드 모드입니다: ${BUILD_MODE} (debug | release)" >&2; exit 2 ;;
esac

check_required_firebase_config "${PLATFORM}" "${CLASSFLOW_ENV}"
check_required_revenuecat_define_file "${CLASSFLOW_ENV}"
case "${PLATFORM}" in
  android) BUILD_SUBCOMMAND="apk" ;;
  ios) BUILD_SUBCOMMAND="ios" ;;
  web) BUILD_SUBCOMMAND="web" ;;
esac
BUILD_ARGS=("${BUILD_SUBCOMMAND}" --"${BUILD_MODE}" --dart-define=CLASSFLOW_ENV="${CLASSFLOW_ENV}" --dart-define-from-file="${FIREBASE_DEFINE_FILE}" --dart-define-from-file="${REVENUECAT_DEFINE_FILE}")
if [[ "${PLATFORM}" == "ios" && "${BUILD_MODE}" == "debug" ]]; then BUILD_ARGS+=(--no-codesign); fi

echo "[빌드] ClassFlow ${ENV_INPUT} (${CLASSFLOW_ENV}) / ${PLATFORM} / ${BUILD_MODE}"
start_execution_timing
set +e
flutter build "${BUILD_ARGS[@]}"
exit_code=$?
set -e
print_execution_timing
exit "${exit_code}"
