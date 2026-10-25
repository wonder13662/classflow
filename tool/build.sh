#!/usr/bin/env bash
# ============================================================
# SketchReeler — 환경별 Flutter build 스크립트
# ============================================================
# 사용법:
#   ./tool/build.sh <env> <platform> [build_mode]
#
# 인자:
#   env         필수. dev | stage | prod
#   platform    필수. android | ios
#   build_mode  선택. debug | release
#               기본값: prod는 release, dev/stage는 debug
#
# 예시:
#   ./tool/build.sh dev android
#   ./tool/build.sh stage ios
#   ./tool/build.sh prod android release
#   ./tool/build.sh dev ios debug
# ============================================================
set -euo pipefail

# ── 색상 정의 ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_check_firebase.sh"
source "${SCRIPT_DIR}/_check_revenuecat.sh"
source "${SCRIPT_DIR}/_execution_timing.sh"

# ── 도움말 ───────────────────────────────────────────────────
usage() {
  echo ""
  echo -e "${CYAN}사용법:${NC} ./tool/build.sh <env> <platform> [build_mode]"
  echo ""
  echo -e "${CYAN}인자:${NC}"
  echo "  env         필수. dev | stage | prod"
  echo "  platform    필수. android | ios"
  echo "  build_mode  선택. debug | release"
  echo "              기본값: prod는 release, dev/stage는 debug"
  echo ""
  echo -e "${CYAN}예시:${NC}"
  echo "  ./tool/build.sh dev android"
  echo "  ./tool/build.sh stage ios"
  echo "  ./tool/build.sh prod android release"
  echo "  ./tool/build.sh dev ios debug"
  echo ""
}

# ── 인자 검증 ────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
  if [[ $# -eq 0 ]]; then
    echo -e "${RED}[오류] env, platform 인자가 누락되었습니다.${NC}"
  else
    echo -e "${RED}[오류] platform 인자가 누락되었습니다.${NC}"
  fi
  usage
  exit 1
fi

ENV="${1}"
PLATFORM="${2}"
BUILD_MODE="${3:-}"

# ── 환경 매핑 ────────────────────────────────────────────────
# env 값 → Flutter flavor 이름 및 SKETCH_ENV 값으로 변환한다.
# 정책 상수와 동기화: lib/constants/android_flavor_policy.dart
#                     lib/constants/ios_scheme_policy.dart
#                     lib/constants/firebase_environment_policy.dart
case "${ENV}" in
  dev)
    FLAVOR="dev"
    SKETCH_ENV="development"
    DEFAULT_BUILD_MODE="debug"
    ;;
  stage)
    FLAVOR="stage"
    SKETCH_ENV="stage"
    DEFAULT_BUILD_MODE="debug"
    ;;
  prod)
    FLAVOR="prod"
    SKETCH_ENV="production"
    DEFAULT_BUILD_MODE="release"
    ;;
  *)
    echo -e "${RED}[오류] 알 수 없는 env 값: '${ENV}'${NC}"
    echo -e "       허용 값: ${YELLOW}dev${NC} | ${YELLOW}stage${NC} | ${YELLOW}prod${NC}"
    usage
    exit 1
    ;;
esac

# ── 빌드 모드 결정 ───────────────────────────────────────────
if [[ -z "${BUILD_MODE}" ]]; then
  BUILD_MODE="${DEFAULT_BUILD_MODE}"
fi

case "${BUILD_MODE}" in
  debug|release)
    ;;
  *)
    echo -e "${RED}[오류] 알 수 없는 build_mode 값: '${BUILD_MODE}'${NC}"
    echo -e "       허용 값: ${YELLOW}debug${NC} | ${YELLOW}release${NC}"
    usage
    exit 1
    ;;
esac

# ── 플랫폼별 빌드 명령 조합 ──────────────────────────────────
case "${PLATFORM}" in
  android)
    BUILD_SUBCOMMAND="apk"
    if [[ "${BUILD_MODE}" == "release" ]]; then
      MODE_FLAGS=(--release)
    else
      MODE_FLAGS=(--debug)
    fi
    ;;
  ios)
    if [[ "${BUILD_MODE}" == "release" ]]; then
      BUILD_SUBCOMMAND="ipa"
      MODE_FLAGS=(--release)
    else
      BUILD_SUBCOMMAND="ios"
      MODE_FLAGS=(--debug --no-codesign)
    fi
    ;;
  *)
    echo -e "${RED}[오류] 알 수 없는 platform 값: '${PLATFORM}'${NC}"
    echo -e "       허용 값: ${YELLOW}android${NC} | ${YELLOW}ios${NC}"
    usage
    exit 1
    ;;
esac

case "${PLATFORM}" in
  ios)
    check_required_firebase_config "ios" "${ENV}"
    ;;
  android)
    check_required_firebase_config "android" "${ENV}"
    ;;
esac

check_required_revenuecat_define_file "${ENV}" "${PLATFORM}"

# ── 실행 ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[SketchReeler build]${NC}"
echo -e "  환경:       ${CYAN}${ENV}${NC}"
echo -e "  플랫폼:     ${CYAN}${PLATFORM}${NC}"
echo -e "  빌드 모드:  ${CYAN}${BUILD_MODE}${NC}"
echo -e "  Flavor:     ${CYAN}${FLAVOR}${NC}"
echo -e "  SKETCH_ENV: ${CYAN}${SKETCH_ENV}${NC}"
echo -e "  RevenueCat define: ${CYAN}${REVENUECAT_DEFINE_FILE}${NC}"
echo ""

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOKEN_GENERATE_COMMAND="cd \"${REPO_ROOT}\" && dart run tool/generate_theme_tokens.dart"

start_execution_timing

echo -e "${CYAN}[실행]${NC} 공유 테마 토큰 생성"
echo -e "  명령: ${CYAN}${TOKEN_GENERATE_COMMAND}${NC}"
(
  cd "${REPO_ROOT}"
  dart run tool/generate_theme_tokens.dart
)

flutter build "${BUILD_SUBCOMMAND}" \
  --flavor "${FLAVOR}" \
  --dart-define=SKETCH_ENV="${SKETCH_ENV}" \
  --dart-define-from-file="${REVENUECAT_DEFINE_FILE}" \
  "${MODE_FLAGS[@]}"
