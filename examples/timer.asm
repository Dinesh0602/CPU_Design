; ----------------------------------------------------------------------------
; timer.asm — show the Fetch / Decode / Execute cycle and read the on-chip
; timer.
;
; Run with --trace to see one trace line per retired instruction. The MMIO
; timer at 0xC010 holds the low byte of a counter that ticks once per
; instruction. We sample it after the loop and print the value as a single
; byte.
; ----------------------------------------------------------------------------

.org 0x0000

start:
    MOVI R0, #3         ; loop count = 3

loop:
    ST   R0, [0xC000]   ; emit R0
    DEC  R0
    BNE  loop

    LD   R0, [0xC010]   ; sample TIMER
    ST   R0, [0xC000]   ; print the cycle count
    HLT
