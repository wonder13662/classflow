#!/usr/bin/env bash

check_required_firebase_config() {
  local platform="$1"
  local environment="$2"
  FIREBASE_DEFINE_FILE="${REPO_ROOT}/config/firebase/${environment}/${platform}.json"

  if [[ ! -f "${FIREBASE_DEFINE_FILE}" ]]; then
    echo "[오류] ${environment}/${platform} Firebase 설정이 없습니다." >&2
    echo "       ${FIREBASE_DEFINE_FILE}을 만들고 config/firebase/${environment}/${platform}.example.json을 참고하세요." >&2
    return 1
  fi

  if ! python3 - "${FIREBASE_DEFINE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
required = (
    "FIREBASE_API_KEY",
    "FIREBASE_APP_ID",
    "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_PROJECT_ID",
)
try:
    config = json.loads(path.read_text())
except (OSError, json.JSONDecodeError) as error:
    print(f"JSON을 읽을 수 없습니다: {error}", file=sys.stderr)
    raise SystemExit(1)
if not isinstance(config, dict):
    print("최상위 값은 JSON 객체여야 합니다.", file=sys.stderr)
    raise SystemExit(1)
missing = [key for key in required if not isinstance(config.get(key), str) or not config[key].strip()]
placeholders = [key for key in required if isinstance(config.get(key), str) and any(marker in config[key].lower() for marker in ("replace", "your_", "placeholder"))]
if missing or placeholders:
    details = []
    if missing:
        details.append("누락: " + ", ".join(missing))
    if placeholders:
        details.append("예제 값 미교체: " + ", ".join(placeholders))
    print("; ".join(details), file=sys.stderr)
    raise SystemExit(1)
PY
  then
    echo "[오류] Firebase 설정 형식 또는 필수 값이 올바르지 않습니다: ${FIREBASE_DEFINE_FILE}" >&2
    return 1
  fi
}