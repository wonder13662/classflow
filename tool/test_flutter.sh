#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"
START_TIME="$(date +%s)"

for arg in "$@"; do
  case "${arg}" in
    http://*|https://*)
      echo "[오류] URL은 테스트 경로로 사용할 수 없습니다: ${arg}" >&2
      echo "       test/ 아래의 Dart 테스트 파일을 지정하거나 인자 없이 전체 테스트를 실행하세요." >&2
      exit 2
      ;;
  esac
done

RUN_ARGS=()
has_concurrency=false
for arg in "$@"; do
  case "${arg}" in --concurrency=*|-j=*|-j) has_concurrency=true ;; esac
done
if [[ "${has_concurrency}" == false ]]; then RUN_ARGS+=(--concurrency=1); fi
RUN_ARGS+=("$@")

echo "[실행] flutter test ${RUN_ARGS[*]}"
set +e
TEST_OUTPUT="$(flutter test "${RUN_ARGS[@]}" 2>&1)"
exit_code=$?
set -e
printf '%s\n' "${TEST_OUTPUT}"
elapsed=$(($(date +%s) - START_TIME))
printf '[요약] 실행 시간: %02d:%02d:%02d\n' "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" "$((elapsed % 60))"
if [[ ${exit_code} -eq 0 ]]; then echo "[완료] Flutter 테스트 통과"; else echo "[실패] Flutter 테스트 종료 코드: ${exit_code}" >&2; fi
exit "${exit_code}"
