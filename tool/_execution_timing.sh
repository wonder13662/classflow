#!/usr/bin/env bash

start_execution_timing() {
  EXECUTION_START_TIME="$(date +%s)"
}

print_execution_timing() {
  local elapsed
  elapsed=$(($(date +%s) - EXECUTION_START_TIME))
  printf '[소요 시간] %02d:%02d:%02d\n' \
    "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" "$((elapsed % 60))"
}