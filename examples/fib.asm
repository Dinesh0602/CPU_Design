; ----------------------------------------------------------------------------
; fib.asm — emit the first 11 Fibonacci numbers via MMIO.
;
; Each value is stored to 0xC000 (the TTY device), so values up to 127 print
; as their ASCII char and larger ones come out as whatever byte the host
; terminal renders. Pipe through `xxd` if you want the raw values.
;
; Register usage:
;   R0 — current term  (a)
;   R1 — next term     (b)
;   R2 — scratch (saves the old b before we overwrite it)
;   R3 — countdown of remaining terms to emit
; ----------------------------------------------------------------------------

.org 0x0000

    MOVI R0, #0         ; a = 0
    MOVI R1, #1         ; b = 1
    MOVI R3, #11        ; print 11 terms

loop:
    ST   R0, [0xC000]   ; emit a
    MOV  R2, R1         ; scratch <- b
    ADD  R1, R0         ; b <- b + a
    MOV  R0, R2         ; a <- old b
    DEC  R3
    BNE  loop
    HLT
