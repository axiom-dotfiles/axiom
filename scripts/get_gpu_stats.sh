#!/bin/bash

GPU_VENDOR="${1:-none}"

safe_num() {
  local val="$1"
  [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]] && echo "$val" || echo "0"
}

get_gpu_stats() {
  local vendor="$1"
  local usage=0
  local temp=0
  case "$vendor" in
  nvidia)
    if command -v nvidia-smi &>/dev/null; then
      local output=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
      usage=$(echo "$output" | cut -d',' -f1 | tr -d ' ')
      temp=$(echo "$output" | cut -d',' -f2 | tr -d ' ')
    fi
    ;;
  amd)
    if command -v rocm-smi &>/dev/null; then
      local rocm_output=$(rocm-smi --showuse --showtemp 2>/dev/null)
      usage=$(echo "$rocm_output" | grep 'GPU\[0\].*GPU use' | grep -oP 'GPU use \(%\): \K\d+' | head -n1)
      temp=$(echo "$rocm_output" | grep 'GPU\[0\].*edge' | grep -oP 'edge\) \(C\): \K[0-9.]+' | head -n1)
      if [ -z "$temp" ] || [ "$temp" = "0" ]; then
        temp=$(echo "$rocm_output" | grep 'GPU\[0\].*junction' | grep -oP 'junction\) \(C\): \K[0-9.]+' | head -n1)
      fi
    else
      usage=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo "0")
      local temp_millidegrees=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)
      [ -n "$temp_millidegrees" ] && temp=$((temp_millidegrees / 1000))
    fi
    ;;
  intel)
    if command -v intel_gpu_top &>/dev/null; then
      usage=$(timeout 1s intel_gpu_top -J -s 500 2>/dev/null | grep -m1 '"busy"' | grep -oP ':\s*\K[0-9.]+' | head -n1)
    fi
    temp=$(sensors 2>/dev/null | grep -iE 'intel|gpu' | grep -oP '\+\K[0-9.]+' | head -n1)
    ;;
  esac
  usage=$(safe_num "$usage")
  temp=$(safe_num "$temp")
  echo "{\"gpuUsage\": $usage, \"gpuTemp\": $temp}"
}

get_gpu_stats "$GPU_VENDOR"
