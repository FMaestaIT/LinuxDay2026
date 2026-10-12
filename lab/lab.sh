#!/usr/bin/env bash
# Accende, spegne (deallocate: niente costi di calcolo) o mostra lo stato delle VM del lab.
set -euo pipefail

VMS=("rg-claude-lab-lamp vm-lamp" "rg-claude-lab-api vm-api" "rg-claude-lab-broken vm-broken")

case "${1:-}" in
  start | stop)
    action=$([[ $1 == start ]] && echo start || echo deallocate)
    for entry in "${VMS[@]}"; do
      read -r rg vm <<<"$entry"
      echo "$1: $vm"
      az vm "$action" -g "$rg" -n "$vm" --no-wait
    done
    ;;
  status)
    for entry in "${VMS[@]}"; do
      read -r rg vm <<<"$entry"
      printf '%-10s %s\n' "$vm" "$(az vm get-instance-view -g "$rg" -n "$vm" \
        --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus | [0]" -o tsv)"
    done
    ;;
  *)
    echo "uso: $0 start|stop|status" >&2
    exit 1
    ;;
esac
