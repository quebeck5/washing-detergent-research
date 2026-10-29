#!/usr/bin/env bash
# Machine-Activity Monitor for Long Tasks
# Watches GPU, CPU 1-min loadavg, and physical net traffic (minus Tailscale tunnel)

prev=0
first=1
while true; do
  gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
  [ -z "$gpu" ] && gpu=0
  load=$(awk '{print $1}' /proc/loadavg)
  phys=0
  for f in /sys/class/net/*/statistics/rx_bytes; do
    st=$(dirname $f)
    i=$(basename $(dirname $st))
    [ -e /sys/class/net/$i/device ] || continue
    phys=$((phys + $(cat $st/rx_bytes) + $(cat $st/tx_bytes)))
  done
  tn=0
  for s in rx_bytes tx_bytes; do
    v=$(cat /sys/class/net/tailscale0/statistics/$s 2>/dev/null || echo 0)
    tn=$((tn + v))
  done
  cur=$((phys - tn))
  [ $cur -lt 0 ] && cur=0
  if [ $first -eq 1 ]; then
    dnet=0
    first=0
  else
    dnet=$((cur - prev))
  fi
  prev=$cur
  netmb=$(awk "BEGIN{printf \"%.1f\", $dnet/1048576}")
  state=IDLE
  [ "$gpu" -gt 0 ] 2>/dev/null && state=ACTIVE
  [ "$(awk "BEGIN{print ($load > 2.0)}")" = 1 ] && state=ACTIVE
  [ "$dnet" -gt 524288 ] && state=ACTIVE
  echo "$state gpu=${gpu}% load=${load} net=${netmb}MB"
  sleep 10
done
