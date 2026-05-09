; ----------------------------------------------------------------------------
; hello.asm — print "Hello, World" through MMIO.
;
; The TTY device is memory-mapped at 0xC000. Writing a byte there asks the
; host to print it. There are no dedicated I/O opcodes — we just store
; through ST.
; ----------------------------------------------------------------------------

.org 0x0000

start:
    MOVI R0, #'H'
    ST   R0, [0xC000]
    MOVI R0, #'e'
    ST   R0, [0xC000]
    MOVI R0, #'l'
    ST   R0, [0xC000]
    MOVI R0, #'l'
    ST   R0, [0xC000]
    MOVI R0, #'o'
    ST   R0, [0xC000]
    MOVI R0, #','
    ST   R0, [0xC000]
    MOVI R0, #' '
    ST   R0, [0xC000]
    MOVI R0, #'W'
    ST   R0, [0xC000]
    MOVI R0, #'o'
    ST   R0, [0xC000]
    MOVI R0, #'r'
    ST   R0, [0xC000]
    MOVI R0, #'l'
    ST   R0, [0xC000]
    MOVI R0, #'d'
    ST   R0, [0xC000]
    MOVI R0, #10        ; '\n'
    ST   R0, [0xC000]
    HLT
