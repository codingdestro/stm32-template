#!/usr/bin/env bash
# Verify that the firmware reset stack fits the connected STM32's SRAM.
set -euo pipefail

elf="${1:-build/firmware.elf}"

if [[ ! -f "$elf" ]]; then
  printf 'error: firmware ELF not found: %s\n' "$elf" >&2
  exit 2
fi

probe="$(st-info --probe)"
sram_bytes="$(sed -n 's/^[[:space:]]*sram:[[:space:]]*\([0-9][0-9]*\).*/\1/p' <<<"$probe")"
device="$(sed -n 's/^[[:space:]]*dev-type:[[:space:]]*//p' <<<"$probe")"
stack_hex="$(arm-none-eabi-nm --defined-only "$elf" | awk '$3 == "_estack" { print $1 }')"

if [[ -z "$sram_bytes" || -z "$stack_hex" ]]; then
  printf 'error: could not determine the connected SRAM or firmware stack\n' >&2
  exit 2
fi

stack=$((16#$stack_hex))
sram_end=$((0x20000000 + sram_bytes))

printf 'target: %s, SRAM end: 0x%08X\n' "$device" "$sram_end"
printf 'firmware reset stack: 0x%08X\n' "$stack"

if ((stack != sram_end)); then
  printf 'error: reset stack does not match the connected MCU SRAM; a manual reset may not boot the firmware\n' >&2
  exit 1
fi
