#!/bin/bash

safe_num() {
  local val="$1"
  [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]] && echo "$val" || echo "0"
}

get_disks() {
  local disks_json="["
  local first=true
  # Get all mounted filesystems, excluding special/temporary ones
  while IFS= read -r line; do
    local device=$(echo "$line" | awk '{print $1}')
    local mount_point=$(echo "$line" | awk '{print $6}')
    local disk_total=$(echo "$line" | awk '{print $2}' | sed 's/G//')
    local disk_usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    disk_total=$(safe_num "$disk_total")
    disk_usage=$(safe_num "$disk_usage")
    [ "$disk_usage" = "0" ] && [ "$disk_total" = "0" ] && continue
    # Extract a meaningful name (last part of device path)
    local disk_name=$(basename "$device")
    [ "$first" = false ] && disks_json+=","
    first=false
    disks_json+="{\"name\":\"$disk_name\",\"mount\":\"$mount_point\",\"usage\":$disk_usage,\"total\":$disk_total}"
  done < <(df -BG 2>/dev/null | grep -E '^/dev/' | grep -vE '(loop|tmpfs|devtmpfs)')
  disks_json+="]"
  echo "$disks_json"
}

get_disks
