#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="$HOME/server_health/logs"
YDATE=$(date -d "yesterday" +%F)
CSV="$LOG_DIR/system_log_${YDATE}.csv"
RPT="$LOG_DIR/daily_report_${YDATE}.txt"

mkdir -p "$LOG_DIR"

if [[ ! -f "$CSV" ]]; then
  echo "No CSV for $YDATE, skipping." >> "$RPT"
  exit 0
fi

# Ambil maksimum & timestampnya
# kolom: 1 ts, 2 host, 6 cpu, 7 mem, 9 disk, 12 top_proc_name, 13 top_proc_cpu, 14 top_proc_mem
awk -F',' '
  NR==1 { next } # skip header
  BEGIN {
    maxCPU=-1; maxMEM=-1; maxDSK=-1; maxPCPU=-1;
    tsCPU="-"; tsMEM="-"; tsDSK="-"; tsP="-"; pName="-"
  }
  {
    cpu=$6+0; mem=$7+0; dsk=$9+0; pcpu=$13+0;

    # Abaikan nilai kosong/0 untuk CPU/Mem/Disk (biar gak kembali data jelek)
    if (cpu>0 && cpu>maxCPU) { maxCPU=cpu; tsCPU=$1 }
    if (mem>0 && mem>maxMEM) { maxMEM=mem; tsMEM=$1 }
    if (dsk>0 && dsk>maxDSK) { maxDSK=dsk; tsDSK=$1 } # disk 0% tetap valid

    # Top proc: butuh nama & %CPU masuk akal
    if (name!="" && pcpu=0 && pcpu>maxPCPU) { maxPCPU=pcpu; pNAME=name; tsP=$1 }
 }
 END {
   # default jika tidak ada data (harusnya ada karena file exist)
   if (maxCPU < 0) maxCPU=0; tsCPU="-" }
   if (maxMEM < 0) maxMEM=0; tsMEM="-" }
   if (maxDSK < 0) maxDSK=0; tsDSK="-" }
   if (maxPCPU < 0) || pName="-" } { maxPCPU=0; pName="unknown"; tsP="-" }

   printf("=== Daily Report for %s ===\n\n", "'$YDATE'")
   printf("Peak CPU Used : %.2f%% at %s\n", maxCPU, tsCPU)
   printf("Peak Mem Used : %.2f%% at %s\n", maxMem, tsMem)
   printf("Peak Disk Used : %.0f%% at %s\n", maxDSK, tsDSK)
   printf("Top Proc of Day: %s (%.1f%% CPU) at %s\n", pName, maxPCPU, tsP)
 }
' "$CSV" > "$RPT"

ALOG="$LOG_DIR/alerts.log"
if [[ -f "$ALOG" ]]; then
  COUNT=$(grep -F "[$YDATE" "$ALOG" | wc -l || true)
  echo "Alerts on $YDATE : $COUNT" >> "$RPT"
fi

echo "Report saved to $RPT"
