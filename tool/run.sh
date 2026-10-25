#!/usr/bin/env bash
# ============================================================
# SketchReeler — 환경별 Flutter run 스크립트
# ============================================================
# 사용법:
#   ./tool/run.sh [--debug|--release] <env> [platform] [--dart-define=KEY=VALUE ...]
#
# 인자:
#   env       필수. dev | stage | prod
#   platform  선택. android | ios  (생략 시 연결된 기기 자동 선택)
#   옵션      --debug | --release  (기본값: debug)
#             --dart-define=KEY=VALUE  (여러 번 지정 가능, flutter run에 그대로 전달)
#             --device-id=ID  (지정한 장치를 사용, 자동 선택 생략)
#
# 예시:
#   ./tool/run.sh dev
#   ./tool/run.sh stage android
#   ./tool/run.sh prod ios
#   ./tool/run.sh dev --release
#   ./tool/run.sh --release prod ios
#
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
  echo -e "${CYAN}사용법:${NC} ./tool/run.sh [--debug|--release] <env> [platform] [--dart-define=KEY=VALUE ...]"
  echo ""
  echo -e "${CYAN}인자:${NC}"
  echo "  env       필수. dev | stage | prod"
  echo "  platform  선택. android | ios  (생략 시 연결된 기기 자동 선택)"
  echo "  옵션      --debug | --release  (기본값: debug)"
  echo "            --dart-define=KEY=VALUE  (여러 번 지정 가능, flutter run에 그대로 전달)"
  echo "            --device-id=ID  (지정한 장치를 사용, 자동 선택 생략)"
  echo ""
  echo -e "${CYAN}예시:${NC}"
  echo "  ./tool/run.sh dev"
  echo "  ./tool/run.sh stage android"
  echo "  ./tool/run.sh prod ios"
  echo "  ./tool/run.sh dev --release"
  echo "  ./tool/run.sh --release prod ios"
  echo ""
}

# ── 인자 검증 ────────────────────────────────────────────────
RUN_MODE="debug"
DEVICE_ID=""
POSITIONAL=()
EXTRA_DART_DEFINES=()
SELECTED_IOS_PROVISIONING_PROFILE_SPECIFIER=""

for arg in "$@"; do
  case "${arg}" in
    --release)
      RUN_MODE="release"
      ;;
    --debug)
      RUN_MODE="debug"
      ;;
    --device-id=*)
      DEVICE_ID="${arg#--device-id=}"
      if [[ -z "${DEVICE_ID}" ]]; then
        echo -e "${RED}[오류] --device-id 값이 비어 있습니다.${NC}"
        exit 1
      fi
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --dart-define=*)
      EXTRA_DART_DEFINES+=("${arg}")
      ;;
    --*)
      echo -e "${RED}[오류] 알 수 없는 옵션: '${arg}'${NC}"
      usage
      exit 1
      ;;
    *)
      POSITIONAL+=("${arg}")
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -lt 1 ]]; then
  echo -e "${RED}[오류] env 인자가 누락되었습니다.${NC}"
  usage
  exit 1
fi

if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
  echo -e "${RED}[오류] 인자가 너무 많습니다.${NC}"
  usage
  exit 1
fi

ENV="${POSITIONAL[0]}"
PLATFORM="${POSITIONAL[1]:-}"

# ── 환경 매핑 ────────────────────────────────────────────────
# env 값 → Flutter flavor 이름 및 CLASSFLOW_ENV 값으로 변환한다.
# 정책 상수와 동기화: lib/constants/android_flavor_policy.dart
#                     lib/constants/ios_scheme_policy.dart
#                     lib/constants/firebase_environment_policy.dart
case "${ENV}" in
  dev)
    FLAVOR="dev"
    CLASSFLOW_ENV="development"
    ;;
  stage)
    FLAVOR="stage"
    CLASSFLOW_ENV="stage"
    ;;
  prod)
    FLAVOR="prod"
    CLASSFLOW_ENV="production"
    ;;
  *)
    echo -e "${RED}[오류] 알 수 없는 env 값: '${ENV}'${NC}"
    echo -e "       허용 값: ${YELLOW}dev${NC} | ${YELLOW}stage${NC} | ${YELLOW}prod${NC}"
    usage
    exit 1
    ;;
esac

# ── 플랫폼 검증 ──────────────────────────────────────────────
if [[ -n "${PLATFORM}" ]]; then
  case "${PLATFORM}" in
    android)
      ;;
    ios)
      ;;
    *)
      echo -e "${RED}[오류] 알 수 없는 platform 값: '${PLATFORM}'${NC}"
      echo -e "       허용 값: ${YELLOW}android${NC} | ${YELLOW}ios${NC}  (생략 시 자동 선택)"
      usage
      exit 1
      ;;
  esac
fi

resolve_device_id_by_platform() {
  local platform_name="$1"
  local device_candidates

  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}[오류] python3 실행 파일을 찾을 수 없습니다.${NC}"
    echo -e "       run 스크립트는 디바이스 자동 선택을 위해 python3(JSON 파싱)가 필요합니다."
    echo -e "       대안: ${YELLOW}flutter run -d <device-id> --flavor ${FLAVOR} --dart-define=CLASSFLOW_ENV=${CLASSFLOW_ENV}${NC}"
    exit 1
  fi

  local devices_json
  if ! devices_json="$(flutter devices --machine 2>/dev/null)"; then
    echo -e "${RED}[오류] flutter devices --machine 실행에 실패했습니다.${NC}"
    echo -e "       확인: ${YELLOW}flutter doctor${NC} 와 ${YELLOW}flutter devices${NC} 출력으로 SDK/디바이스 상태를 점검하세요."
    exit 1
  fi

  if device_candidates="$(printf '%s' "${devices_json}" | python3 -c '
import json
import sys

platform_name = sys.argv[1]
try:
    devices = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit(2)

matches = []
for device in devices:
    target_platform = device.get("targetPlatform", "")
    is_emulator = device.get("emulator", False)

    if platform_name == "ios" and target_platform == "ios" and not is_emulator:
      matches.append(device)

    if platform_name == "android" and target_platform == "android" and not is_emulator:
        matches.append(device)

if not matches:
    raise SystemExit(1)
for device in matches:
    name = str(device.get("name", device["id"])).replace("\n", " ").replace("\t", " ")
    print(device["id"] + "\t" + name)
' "$platform_name"
)"; then
    local device_ids=()
    local device_names=()
    local candidate_id candidate_name
    while IFS=$'\t' read -r candidate_id candidate_name; do
      device_ids+=("${candidate_id}")
      device_names+=("${candidate_name}")
    done <<< "${device_candidates}"

    if [[ ${#device_ids[@]} -eq 1 ]]; then
      DEVICE_ID="${device_ids[0]}"
      return
    fi

    echo "연결된 ${platform_name} 실기기를 선택하세요:"
    local device_index
    for ((device_index=0; device_index<${#device_ids[@]}; device_index++)); do
      printf '[%s] %s (%s)\n' "$((device_index + 1))" "${device_names[device_index]}" "${device_ids[device_index]}"
    done

    local selection
    while true; do
      printf '기기 번호 (q: 취소): '
      if ! read -r selection || [[ "${selection}" == "q" ]]; then
        echo "기기 선택을 취소했습니다."
        exit 1
      fi
      for ((device_index=0; device_index<${#device_ids[@]}; device_index++)); do
        if [[ "${selection}" == "$((device_index + 1))" ]]; then
          DEVICE_ID="${device_ids[device_index]}"
          return
        fi
      done
      echo "목록에 표시된 기기 번호를 입력하세요."
    done
  else
    local parse_exit_code=$?
    if [[ ${parse_exit_code} -eq 2 ]]; then
      echo -e "${RED}[오류] flutter devices --machine 결과 JSON 파싱에 실패했습니다.${NC}"
      echo -e "       아래 명령 출력 형식이 비정상인지 확인하세요: ${YELLOW}flutter devices --machine${NC}"
    else
      echo -e "${RED}[오류] 연결된 ${platform_name} 실기기를 찾지 못했습니다.${NC}"
      echo -e "       확인: ${YELLOW}flutter devices${NC} 명령에서 대상 기기가 표시되는지 확인하세요."
    fi
    exit 1
  fi
}

list_prod_ios_development_profiles() {
  local profile_directory profile_path decoded_profile profile_name team_id application_id
  local get_task_allow expiration_date expiration_timestamp current_timestamp
  local provisioned_devices xcode_managed
  local profile_directories=(
    "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles"
    "${HOME}/Library/MobileDevice/Provisioning Profiles"
  )

  for profile_directory in "${profile_directories[@]}"; do
    [[ -d "${profile_directory}" ]] || continue
    for profile_path in "${profile_directory}"/*.mobileprovision; do
      [[ -f "${profile_path}" ]] || continue
      if ! decoded_profile="$(security cms -D -i "${profile_path}" 2>/dev/null)"; then
        continue
      fi

      profile_name="$(printf '%s' "${decoded_profile}" | plutil -extract Name raw -o - - 2>/dev/null || true)"
      team_id="$(printf '%s' "${decoded_profile}" | plutil -extract TeamIdentifier.0 raw -o - - 2>/dev/null || true)"
      application_id="$(printf '%s' "${decoded_profile}" | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null || true)"
      get_task_allow="$(printf '%s' "${decoded_profile}" | plutil -extract Entitlements.get-task-allow raw -o - - 2>/dev/null || true)"
      expiration_date="$(printf '%s' "${decoded_profile}" | plutil -extract ExpirationDate raw -o - - 2>/dev/null || true)"
      provisioned_devices="$(printf '%s' "${decoded_profile}" | plutil -extract ProvisionedDevices json -o - - 2>/dev/null || true)"
      xcode_managed="$(printf '%s' "${decoded_profile}" | plutil -extract IsXcodeManaged raw -o - - 2>/dev/null || true)"
      [[ -n "${profile_name}" && "${team_id}" == "2JDSH2C8HC" ]] || continue
      [[ "${application_id}" == "2JDSH2C8HC.com.wonder13662.sketchreeler" ]] || continue
      [[ "${get_task_allow}" == "true" ]] || continue
      [[ "${xcode_managed}" != "true" ]] || continue
      if [[ -n "${DEVICE_ID}" && "${provisioned_devices}" != *"\"${DEVICE_ID}\""* ]]; then
        continue
      fi

      expiration_timestamp="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "${expiration_date}" '+%s' 2>/dev/null || true)"
      [[ -n "${expiration_timestamp}" ]] || continue
      current_timestamp="$(date '+%s')"
      (( expiration_timestamp > current_timestamp )) || continue

      printf '%s\n' "${profile_name}"
    done
  done
}

select_prod_ios_development_profile() {
  local profile_name selection profile_index
  local profile_names=()

  while IFS= read -r profile_name; do
    [[ -n "${profile_name}" ]] && profile_names+=("${profile_name}")
  done < <(list_prod_ios_development_profiles | sort -u)

  if [[ ${#profile_names[@]} -eq 0 ]]; then
    echo -e "${RED}[오류] 설치된 prod iOS Development 프로파일이 없습니다.${NC}" >&2
    echo "       Team 2JDSH2C8HC 및 Bundle ID com.wonder13662.sketchreeler에 맞는 프로파일을 설치하세요." >&2
    return 1
  fi

  echo "prod iOS에서 사용할 Development 프로파일을 선택하세요:"
  for ((profile_index=0; profile_index<${#profile_names[@]}; profile_index++)); do
    printf '[%s] %s\n' "$((profile_index + 1))" "${profile_names[profile_index]}"
  done

  while true; do
    printf '프로파일 번호 (q: 취소): '
    if ! read -r selection || [[ "${selection}" == "q" ]]; then
      echo "프로파일 선택을 취소했습니다." >&2
      return 1
    fi
    for ((profile_index=0; profile_index<${#profile_names[@]}; profile_index++)); do
      if [[ "${selection}" == "$((profile_index + 1))" ]]; then
        SELECTED_IOS_PROVISIONING_PROFILE_SPECIFIER="${profile_names[profile_index]}"
        return 0
      fi
    done
    echo "목록에 표시된 프로파일 번호를 입력하세요."
  done
}

update_debug_prod_profile() {
  local action="$1"
  local profile_specifier="${2:-}"
  local project_path="${REPO_ROOT}/ios/Runner.xcodeproj/project.pbxproj"

  python3 - "${action}" "${profile_specifier}" "${project_path}" <<'PY'
from pathlib import Path
import sys

action = sys.argv[1]
profile_specifier = sys.argv[2]
project_path = Path(sys.argv[3])
marker = 'AA300003B1C2D3E4F5000003 /* Debug-prod */'
text = project_path.read_text()
start = text.index(marker)
end = text.index('\n\t\t};\n', start)
block = text[start:end]
profile_line = '\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "' + profile_specifier + '";\n'
profile_lines = [line for line in block.splitlines(keepends=True) if 'PROVISIONING_PROFILE_SPECIFIER' not in line]
anchor = next(
    (line for line in profile_lines if 'PRODUCT_NAME = "$(TARGET_NAME)";' in line),
    None,
)
if anchor is None:
    raise SystemExit('Debug-prod PRODUCT_NAME 설정을 찾지 못했습니다.')

anchor_index = profile_lines.index(anchor)
if action == 'apply':
    profile_lines.insert(anchor_index + 1, profile_line)
elif action != 'restore':
    raise SystemExit(f'지원하지 않는 프로파일 업데이트 동작입니다: {action}')

project_path.write_text(text[:start] + ''.join(profile_lines) + text[end:])
PY
}

case "${PLATFORM}" in
  ios)
    check_required_firebase_config "ios" "${ENV}"
    if [[ -z "${DEVICE_ID}" ]]; then
      resolve_device_id_by_platform "ios"
    fi
    ;;
  android)
    check_required_firebase_config "android" "${ENV}"
    if [[ -z "${DEVICE_ID}" ]]; then
      resolve_device_id_by_platform "android"
    fi
    ;;
  "")
    if [[ "$(uname -s)" == "Darwin" ]]; then
      check_required_firebase_config "ios" "${ENV}"
    fi
    ;;
esac

if [[ "$(uname -s)" == "Darwin" && "${ENV}" == "prod" && ( "${PLATFORM}" == "ios" || -z "${PLATFORM}" ) ]]; then
  if [[ "${RUN_MODE}" != "debug" ]]; then
    echo -e "${RED}[오류] prod iOS 직접 실행은 debug 모드만 지원합니다.${NC}" >&2
    echo "       prod 배포 빌드는 Archive/Export 경로의 App Store 프로파일 설정을 사용하세요." >&2
    exit 1
  fi
  select_prod_ios_development_profile || exit 1
fi

check_required_revenuecat_define_file "${ENV}" "${PLATFORM}"

# ── 로그 파일 준비 ───────────────────────────────────────────
# 실행별 로그를 저장소 루트 logs/ 아래에 보존해 재현/공유를 쉽게 한다.
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/run_${ENV}_${FLAVOR}_$(date +%Y%m%d_%H%M%S).log"

# ── 실행 ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[SketchReeler run]${NC}"
echo -e "  환경:     ${CYAN}${ENV}${NC}"
echo -e "  Flavor:   ${CYAN}${FLAVOR}${NC}"
echo -e "  CLASSFLOW_ENV: ${CYAN}${CLASSFLOW_ENV}${NC}"
echo -e "  실행 모드: ${CYAN}${RUN_MODE}${NC}"
if [[ -n "${DEVICE_ID}" ]]; then
  echo -e "  장치 ID:  ${CYAN}${DEVICE_ID}${NC}"
fi
echo -e "  RevenueCat define: ${CYAN}${REVENUECAT_DEFINE_FILE}${NC}"
if [[ -n "${PLATFORM}" ]]; then
  echo -e "  플랫폼:   ${CYAN}${PLATFORM}${NC}"
else
  echo -e "  플랫폼:   ${CYAN}(자동 선택)${NC}"
fi
if [[ ${#EXTRA_DART_DEFINES[@]} -gt 0 ]]; then
  echo -e "  추가 dart-define: ${CYAN}${EXTRA_DART_DEFINES[*]}${NC}"
fi
echo -e "  로그 파일: ${CYAN}${LOG_FILE}${NC}"
echo ""

start_execution_timing

if [[ -n "${SELECTED_IOS_PROVISIONING_PROFILE_SPECIFIER}" ]]; then
  update_debug_prod_profile apply "${SELECTED_IOS_PROVISIONING_PROFILE_SPECIFIER}"
  trap 'update_debug_prod_profile restore' EXIT
fi

RUN_ARGS=(
  --flavor "${FLAVOR}"
  --"${RUN_MODE}"
  --dart-define=CLASSFLOW_ENV="${CLASSFLOW_ENV}"
  --dart-define-from-file="${REVENUECAT_DEFINE_FILE}"
)

if [[ ${#EXTRA_DART_DEFINES[@]} -gt 0 ]]; then
  RUN_ARGS+=("${EXTRA_DART_DEFINES[@]}")
fi

if [[ -n "${DEVICE_ID}" ]]; then
  RUN_ARGS+=(-d "${DEVICE_ID}")
fi

RUN_ENV=()
if [[ "$(uname -s)" == "Darwin" && "${PLATFORM}" != "android" ]]; then
  # iOS 시스템 로그(특히 StoreKit JWS 원문) 노이즈를 줄인다.
  RUN_ENV+=(OS_ACTIVITY_MODE=disable)
fi

# stdin은 파이프에 연결하지 않아 hot-reload 키 입력(r/R/q)이 그대로 동작한다.
if [[ ${#RUN_ENV[@]} -gt 0 ]]; then
  env "${RUN_ENV[@]}" flutter run "${RUN_ARGS[@]}" 2>&1 | tee "${LOG_FILE}"
else
  flutter run "${RUN_ARGS[@]}" 2>&1 | tee "${LOG_FILE}"
fi
