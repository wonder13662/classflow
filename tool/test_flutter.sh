#!/usr/bin/env bash
# ============================================================
# SketchReeler — Flutter 테스트 실행 스크립트
# ============================================================
# 목적:
# - dartcv4 native assets hook lock 고착으로 인한 테스트 무출력/타임아웃을 줄인다.
# - 기본 테스트 동시 실행 수를 1로 고정해 lock 경합 가능성을 줄인다.
#
# 사용법:
#   ./tool/test_flutter.sh
#   ./tool/test_flutter.sh test/widgets/loading_overlay_test.dart
#   ./tool/test_flutter.sh --reporter compact
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

START_TIME="$(date +%s)"

DARTCV4_LOCK_FILE=".dart_tool/hooks_runner/shared/dartcv4/.lock"
DARTCV4_BUILD_DIR=".dart_tool/hooks_runner/shared/dartcv4/build"
HOOKS_RUNNER_DIR=".dart_tool/hooks_runner"

abort_if_flutter_test_already_running() {
  local running_pids=()

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] && running_pids+=("${pid}")
  done < <(
    ps -ax -o pid= -o command= \
      | grep -F "flutter test" \
      | grep -F "${REPO_ROOT}" \
      | grep -v "grep -F" \
      | awk '{print $1}'
  )

  if [[ "${#running_pids[@]}" -eq 0 ]]; then
    return
  fi

  echo -e "${RED}[중단]${NC} 동일 워크스페이스에서 실행 중인 flutter test 프로세스를 감지했습니다: ${running_pids[*]}"
  echo -e "${YELLOW}[안내]${NC} 기존 테스트 실행이 종료된 뒤 다시 시도하세요."
  exit 2
}

cleanup_stale_dartcv4_lock() {
  if [[ ! -f "${DARTCV4_LOCK_FILE}" ]]; then
    return
  fi

  local lock_owner_pid=""
  lock_owner_pid="$(sed -n 's/.*pid \([0-9][0-9]*\).*/\1/p' "${DARTCV4_LOCK_FILE}" | head -n 1 || true)"

  if [[ -n "${lock_owner_pid}" ]] && kill -0 "${lock_owner_pid}" 2>/dev/null; then
    echo -e "${CYAN}[정보]${NC} dartcv4 lock owner(pid=${lock_owner_pid})가 실행 중입니다. lock 파일을 유지합니다."
    return
  fi

  echo -e "${YELLOW}[정리]${NC} stale dartcv4 lock 파일을 삭제합니다: ${DARTCV4_LOCK_FILE}"
  rm -f "${DARTCV4_LOCK_FILE}"
}

# 초 단위 정수를 HH:mm:ss 형식으로 변환한다.
format_duration_hhmmss() {
  local total_seconds="$1"
  printf '%02d:%02d:%02d' \
    "$((total_seconds / 3600))" \
    "$(((total_seconds % 3600) / 60))" \
    "$((total_seconds % 60))"
}

# flutter test 출력의 마지막 "+통과 -실패:" 요약 라인에서 개수를 추출한다.
# 요약 라인을 찾지 못하면 0/0으로 처리한다.
parse_test_counts() {
  local output="$1"
  local last_summary=""
  last_summary="$(printf '%s\n' "${output}" | grep -oE '\+[0-9]+( -[0-9]+)?:' | tail -n 1 || true)"

  TESTS_PASSED=0
  TESTS_FAILED=0

  if [[ -z "${last_summary}" ]]; then
    return
  fi

  TESTS_PASSED="$(printf '%s' "${last_summary}" | grep -oE '^\+[0-9]+' | tr -d '+' || true)"
  TESTS_PASSED="${TESTS_PASSED:-0}"

  if [[ "${last_summary}" == *" -"* ]]; then
    TESTS_FAILED="$(printf '%s' "${last_summary}" | grep -oE ' -[0-9]+' | tr -d ' -' || true)"
    TESTS_FAILED="${TESTS_FAILED:-0}"
  fi
}

# 총 실행 시간과 테스트 통과/실패 개수를 요약 출력한다.
print_run_summary() {
  local end_time elapsed elapsed_formatted total_tests
  end_time="$(date +%s)"
  elapsed=$((end_time - START_TIME))
  elapsed_formatted="$(format_duration_hhmmss "${elapsed}")"

  parse_test_counts "${TEST_OUTPUT}"
  total_tests=$((TESTS_PASSED + TESTS_FAILED))

  echo -e "${CYAN}[요약]${NC} 총 실행 시간: ${elapsed_formatted}"
  echo -e "${CYAN}[요약]${NC} 총 테스트 ${total_tests}개 중 실패 ${TESTS_FAILED}개"
}

has_concurrency_arg=false
for arg in "$@"; do
  case "${arg}" in
    http://*|https://*)
      echo -e "${RED}[중단]${NC} PR/웹 URL은 테스트 경로로 사용할 수 없습니다: ${arg}" >&2
      echo -e "${YELLOW}[안내]${NC} test/ 아래의 Dart 테스트 파일 경로를 전달하세요. 전체 테스트는 인자 없이 실행하세요." >&2
      exit 2
      ;;
    --concurrency=*|-j=*|-j)
      has_concurrency_arg=true
      ;;
  esac
done

RUN_ARGS=()
if [[ "${has_concurrency_arg}" == false ]]; then
  RUN_ARGS+=(--concurrency=1)
fi
RUN_ARGS+=("$@")

cleanup_stale_dartcv4_lock
abort_if_flutter_test_already_running
mkdir -p "build/native_assets/macos"

echo -e "${CYAN}[실행]${NC} flutter test ${RUN_ARGS[*]}"
set +e
TEST_OUTPUT="$(flutter test "${RUN_ARGS[@]}" 2>&1)"
TEST_EXIT_CODE=$?
set -e

printf '%s\n' "${TEST_OUTPUT}"

if [[ ${TEST_EXIT_CODE} -eq 0 ]]; then
  echo -e "${GREEN}[완료]${NC} Flutter 테스트 통과"
  print_run_summary
  exit 0
fi

if [[ "${TEST_OUTPUT}" == *"Could not acquire the lock to"* ]] && [[ "${TEST_OUTPUT}" == *".dart_tool/hooks_runner/shared/dartcv4/.lock"* ]]; then
  echo -e "${YELLOW}[재시도]${NC} dartcv4 lock 타임아웃을 감지했습니다. hooks_runner 캐시 정리 후 1회 재시도합니다."
  rm -rf "${HOOKS_RUNNER_DIR}"
  set +e
  TEST_OUTPUT="$(flutter test "${RUN_ARGS[@]}" 2>&1)"
  TEST_EXIT_CODE=$?
  set -e
  printf '%s\n' "${TEST_OUTPUT}"
  print_run_summary
  exit ${TEST_EXIT_CODE}
fi

if [[ "${TEST_OUTPUT}" == *"Invalid kernel binary format version"* ]] || [[ "${TEST_OUTPUT}" == *"Can't load Kernel binary"* ]]; then
  echo -e "${YELLOW}[재시도]${NC} hooks_runner kernel version 불일치를 감지했습니다. hooks_runner 캐시 정리 후 1회 재시도합니다."
  rm -rf "${HOOKS_RUNNER_DIR}"
  set +e
  TEST_OUTPUT="$(flutter test "${RUN_ARGS[@]}" 2>&1)"
  TEST_EXIT_CODE=$?
  set -e
  printf '%s\n' "${TEST_OUTPUT}"
  print_run_summary
  exit ${TEST_EXIT_CODE}
fi

if [[ "${TEST_OUTPUT}" == *"include could not find requested file"* ]] && [[ "${TEST_OUTPUT}" == *"kleidicv"* ]]; then
  echo -e "${YELLOW}[재시도]${NC} dartcv4 KleidiCV 캐시가 불완전합니다. 빌드 캐시와 lock만 정리 후 1회 재시도합니다."
  rm -rf "${DARTCV4_BUILD_DIR}"
  cleanup_stale_dartcv4_lock
  set +e
  TEST_OUTPUT="$(flutter test "${RUN_ARGS[@]}" 2>&1)"
  TEST_EXIT_CODE=$?
  set -e
  printf '%s\n' "${TEST_OUTPUT}"
  print_run_summary
  exit ${TEST_EXIT_CODE}
fi

echo -e "${RED}[실패]${NC} Flutter 테스트가 실패했습니다."
print_run_summary
exit ${TEST_EXIT_CODE}
