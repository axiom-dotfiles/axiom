#!/bin/bash

NETWORK_INTERFACE="${1:-eth0}"

safe_num() {
  local val="$1"
  [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]] && echo "$val" || echo "0"
}

get_cpu_usage() {
  top -bn2 -d0.1 | grep '^%Cpu' | tail -n1 | awk '{print 100 - $8}'
}

get_cpu_temp() {
  local temp=$(sensors 2>/dev/null | grep -iE 'Package id 0|Tctl|Tdie|CPU Temperature' | head -n1 | grep -oP '\+\K[0-9.]+' | head -n1)
  safe_num "$temp"
}

get_mem_usage() {
  free 2>/dev/null | awk '/^Mem:/{printf "%.2f", ($3/$2)*100}' || echo "0"
}

get_network_stats() {
  local interface="$1"
  local rx_bytes=0
  local tx_bytes=0
  local rx_packets=0
  local tx_packets=0
  
  if [ -d "/sys/class/net/$interface" ]; then
    rx_bytes=$(cat /sys/class/net/"$interface"/statistics/rx_bytes 2>/dev/null || echo "0")
    tx_bytes=$(cat /sys/class/net/"$interface"/statistics/tx_bytes 2>/dev/null || echo "0")
    rx_packets=$(cat /sys/class/net/"$interface"/statistics/rx_packets 2>/dev/null || echo "0")
    tx_packets=$(cat /sys/class/net/"$interface"/statistics/tx_packets 2>/dev/null || echo "0")
  fi
  
  # Convert bytes to MB
  local rx_mb=$(awk "BEGIN {printf \"%.2f\", $rx_bytes/1024/1024}")
  local tx_mb=$(awk "BEGIN {printf \"%.2f\", $tx_bytes/1024/1024}")
  
  rx_mb=$(safe_num "$rx_mb")
  tx_mb=$(safe_num "$tx_mb")
  rx_packets=$(safe_num "$rx_packets")
  tx_packets=$(safe_num "$tx_packets")
  
  echo "{\"interface\":\"$interface\",\"rxMB\":$rx_mb,\"txMB\":$tx_mb,\"rxPackets\":$rx_packets,\"txPackets\":$tx_packets}"
}

CPU_USAGE=$(get_cpu_usage)
CPU_TEMP=$(get_cpu_temp)
MEM_USAGE=$(get_mem_usage)
NETWORK=$(get_network_stats "$NETWORK_INTERFACE")

echo "{\"cpuUsage\": $CPU_USAGE, \"cpuTemp\": $CPU_TEMP, \"memUsage\": $MEM_USAGE, \"network\": $NETWORK}"
