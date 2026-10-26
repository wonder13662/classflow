#!/usr/bin/env bash

resolve_classflow_environment() {
  case "$1" in
    dev|development)
      CLASSFLOW_ENV="development"
      ;;
    stage)
      CLASSFLOW_ENV="stage"
      ;;
    prod|production)
      CLASSFLOW_ENV="production"
      ;;
    *)
      echo "[오류] 지원하지 않는 환경입니다: $1 (dev | stage | prod)" >&2
      return 1
      ;;
  esac
}

require_platform() {
  case "$1" in
    android|ios|web) ;;
    *)
      echo "[오류] 지원하지 않는 플랫폼입니다: $1 (android | ios | web)" >&2
      return 1
      ;;
  esac
}