#!/usr/bin/env bash

check_required_revenuecat_define_file() {
  local environment="$1"
  REVENUECAT_DEFINE_FILE="${REPO_ROOT}/config/revenuecat/${environment}.json"

  if [[ ! -f "${REVENUECAT_DEFINE_FILE}" ]]; then
    echo "[오류] ${environment} RevenueCat define 설정이 없습니다." >&2
    echo "       ${REVENUECAT_DEFINE_FILE}을 만들고 config/revenuecat/${environment}.example.json을 참고하세요." >&2
    return 1
  fi

  if ! python3 - "${REVENUECAT_DEFINE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

try:
    config = json.loads(Path(sys.argv[1]).read_text())
except (OSError, json.JSONDecodeError) as error:
    print(f"JSON을 읽을 수 없습니다: {error}", file=sys.stderr)
    raise SystemExit(1)
value = config.get("REVENUECAT_API_KEY") if isinstance(config, dict) else None
if not isinstance(value, str) or not value.strip() or any(marker in value.lower() for marker in ("replace", "your_", "placeholder")):
    print("REVENUECAT_API_KEY가 없거나 예제 값입니다.", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    echo "[오류] RevenueCat 설정 형식 또는 API key가 올바르지 않습니다: ${REVENUECAT_DEFINE_FILE}" >&2
    return 1
  fi
}