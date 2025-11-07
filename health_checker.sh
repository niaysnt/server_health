#!/bin/bash
set -euo pipefail

# === Server Health Checker ===
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
log_date=$(date +"%Y-%m-%d")
log_file="system_log_${log_date}.txt"

echo "=== Server Health Checker - $timestamp ===" | tee -a "$log_file"

# --- CPU ---
read _ user nice system idle iowait irq softirq steal guest < /proc/stat
sleep 0.5
read _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 guest2 < /proc/stat

idle_delta=$((idle2 - idle))
total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
total_delta=$((total2 - total1))
cpu_use=$(awk -v idle="$idle_delta" -v total="$total_delta" 'BEGIN{printf "%.1f", (1 - idle/total)*100}')

# --- Memory ---
read total used free shared buffcache available < <(free -m | awk '/Mem:/ {print $2, $3, $4, $5, $6, $7}')
mem_pct=$(awk -v u="$used" -v t="$total" 'BEGIN{printf "%.1f", (u/t)*100}')

# --- Disk ---
read d_total d_used d_avail d_usepct < <(df -h / | awk 'NR==2{print $2, $3, $4, $5}')
disk_pct=$(echo "$d_usepct" | tr -d '%')

# --- Output utama ---
{
  echo "CPU Usage   : ${cpu_use}%"
  echo "Memory Usage: ${used}Mi / ${total}Mi (${mem_pct}% digunakan)"
  echo "Disk Usage  : ${d_used} / ${d_total} (${d_usepct} digunakan)"
} | tee -a "$log_file"

# --- Peringatan ---
cpu_int=${cpu_use%.*}
if (( cpu_int > 80 || disk_pct > 80 )); then
   echo " ⚠️ Warning: Sistem berat! CPU atau Disk melebihi 80%." | tee -a "$log_file"
else
   echo " ✅ Sistem normal, Tidak ada beban berat saat ini." | tee -a "$log_file"
fi

echo "============================================" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# === Simpan data ke CSV ===
csv="system_log_${log_date}.csv"
if [[ ! -f "$csv" ]]; then
  echo "timestamp,cpu_pct,mem_used_mi,mem_total_mi,mem_pct,disk_used,disk_total,disk_pct" >> "$csv"
fi
echo "$(date +'%Y-%m-%d %H:%M:%S'),${cpu_use},${used},${total},${mem_pct},${d_used},${d_total},${disk_pct}" >> "$csv"




#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/server_health/logs"
CSV_FILE="$OUT_DIR/system_log_$(date +%F).csv"
TXT_FILE="$OUT_DIR/system_log_$(date +%F).txt"
HOSTNAME="$(hostname)"
TIMESTAMP="$(date +'%F %T')"

mkdir -p "$OUT_DIR"

if [[ ! -f "$CSV_FILE" ]]; then
   echo "timestamp,host,load1,load5,load15,cpu_used_pct,mem_used_pct,swap_used_pct,root_used_pct,net_rx_kB,net_tx_kB,top_proc_name,top_proc_cpu,top_proc_mem" >> "$CSV_FILE"
fi

# load avg
read -r L1 L5 L15 _ < <(uptime | awk -F'load average:' '{gsub(/ /,"",$2); gsub(/,/," ",$2); print $2}')

# CPU used %
CPU_USED_PCT=$(mpstat 1 1 | awk '/Average/ && ($2 ~ /all/ || $3 ~ /all/) {idle=$NF; sub(",",".",idle); printf("%.2f", 100 - idle)}')

# Mem & swap used %
MEM_USED_PCT=$(free | awk '/Mem:/ {printf("%.2f", $3/$2*100)}')
SWAP_USED_PCT=$(free | awk '/Swap:/ { if ($2==0) print "0.00"; else printf("%.2f", $3/$2*100)}')

# Root disk %
ROOT_USED_PCT=$(df -hP / | awk 'NR==2 {gsub("%",""); print $5}')

# Net kB/s (1s sample)
read -r RX1 TX1 < <(awk '/:/ && $1 !~ /lo:/ {rx+=$2; tx+=$10} END{print rx,tx}' /proc/net/dev)
sleep 1
read -r RX2 TX2 < <(awk '/:/ && $1 !~ /lo:/ {rx+=$2; tx+=$10} END{print rx,tx}' /proc/net/dev)
NET_RX_KB=$(( (RX2 - RX1)/1024 ))
NET_TX_KB=$(( (TX2 - TX1)/1024 ))

# Top process by CPU (portable, tanpa :width)
read -r PNAME PCPU PMEM < <(
  ps -eo pid,comm,pcpu,pmem --no-header \
  | sort -k3 -nr \
  | awk 'NR==1{print $2, $3, $4}'
)

# fallback kalau kosong
PNAME=${PNAME:-none}
PCPU=${PCPU:-0}
PMEM=${PMEM:-0}

# Write logs
echo "$TIMESTAMP,$HOSTNAME,$L1,$L5,$L15,$CPU_USED_PCT,$MEM_USED_PCT,$SWAP_USED_PCT,$ROOT_USED_PCT,$NET_RX_KB,$NET_TX_KB,$PNAME,$PCPU,$PMEM" >> "$CSV_FILE"
printf "[%s] host=%s load=%s/%s/%s cpu=%.2f%% mem=%.2f%% swap=%s%% root=%s%% net=%s/%s kB top=%s cpu=%s%% mem=%s%%\n" \
  "$TIMESTAMP" "$HOSTNAME" "$L1" "$L5" "$L15" "$CPU_USED_PCT" "$MEM_USED_PCT" "$SWAP_USED_PCT" "$ROOT_USED_PCT" "$NET_RX_KB" "$NET_TX_KB" "$PNAME" "$PCPU" "$PMEM" \
  >> "$TXT_FILE"

# Exit code for alerting
# pastikan:
CPU_THR=85; DISK_THR=90     # sementara diturunkan untuk test
CPU_INT=${CPU_USED_PCT%.*}
ALERT=0
(( CPU_INT > CPU_THR )) && ALERT=1
(( ROOT_USED_PCT > DISK_THR )) && ALERT=1
exit $ALERT


#!/bin/bash
# Day 6: unified alert logger
mkdir -p logs
log_alert() {
  printf '[%s] ALERT: %s\n' "$(date '+%F %T')" "$1" >> "logs/alerts.log"
}
