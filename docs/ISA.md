# TinyCPU — Instruction Set Architecture

This document is the contract between programmers, the assembler, and the
emulator. It specifies the architectural state, the addressable layout
of memory, the binary form of every instruction, and the rules each
instruction follows for updating the status flags.

---

## 1. Word sizes

| Quantity      | Size                              |
| ------------- | --------------------------------- |
| Byte          | 8 bits                            |
| Word          | 16 bits, little-endian in memory  |
| Address space | 64 KiB, byte-addressable          |

Instructions and data share one address space. All accesses go through
the system bus; there is no separate I/O space.

---

## 2. Architectural registers

**General-purpose (8-bit):** eight registers `R0`, `R1`, `R2`, `R3`,
`R4`, `R5`, `R6`, `R7`.

**Special (16-bit):**
- `PC` — program counter; always names the next byte to fetch
- `SP` — stack pointer; resets to `0x03FF` and grows downward

**Status flags (held in `Flags`):**
- `Z` — last result was zero
- `N` — bit 7 of last result was set
- `C` — carry from add / borrow from sub
- `V` — signed (two's-complement) overflow on add or sub

The 3-bit register code that appears inside encoded instructions is
just the register number (`R0` → `0b000`, `R7` → `0b111`).

---

## 3. Memory map

| Range             | Purpose                                                      |
| ----------------- | ------------------------------------------------------------ |
| `0x0000 – 0xBFFF` | RAM (programs and data; load default at `0x0000`)            |
| `0xC000`          | **TTY_OUT** — write a byte to print as ASCII on the host     |
| `0xC001`          | **TTY_IN**  — read a byte (returns 0 if no key was pressed)  |
| `0xC010`          | **TIMER**   — low byte of the on-chip cycle counter          |
| `0xC011`          | **TIMER_CTRL** — write 1 to bit 0 to reset the counter        |
| `0xC012 – 0xFFFF` | RAM (free)                                                   |

There are no dedicated I/O instructions. To print, store to `TTY_OUT`;
to sample the timer, load from `TIMER`. Architecturally, MMIO is just
a few addresses on the bus.

---

## 4. Instruction format

Each instruction consists of a single **opcode byte** followed by
**zero or more operand bytes**. Six operand layouts cover every
mnemonic, and the size of an instruction is fully determined by its
opcode:

| Layout    | Bytes                  | Used by                                                  |
| --------- | ---------------------- | -------------------------------------------------------- |
| `None`    | `op`                   | `NOP`, `HLT`                                             |
| `R`       | `op  r`                | `INC`, `DEC`, `PUSH`, `POP`                              |
| `R_imm`   | `op  r  imm8`          | `MOVI`                                                   |
| `R_R`     | `op  d  s`             | `MOV`, `ADD`, `SUB`, `AND`, `OR`, `XOR`, `CMP`           |
| `R_addr`  | `op  r  lo  hi`        | `LD`, `ST`                                               |
| `Addr`    | `op  lo  hi`           | `BR`, `BEQ`, `BNE`, `BCS`, `BCC`, `BMI`, `BPL`           |

16-bit operands (addresses) are stored little-endian: low byte first,
high byte second.

---

## 5. Addressing modes

| Mode      | Source syntax       | Example                | Resolves to                           |
| --------- | ------------------- | ---------------------- | ------------------------------------- |
| Immediate | `#imm8`             | `MOVI R0, #10`         | the byte itself                       |
| Absolute  | `abs16` or `[abs16]`| `LD R3, [0xC010]`      | a 16-bit address                      |
| Register  | `R0`–`R7`           | `MOV R2, R1`           | a 3-bit register code                 |
| Label     | name                | `BNE loop`             | a 16-bit address recorded in pass 1   |

Numeric literals can be written as decimal (`72`), hex (`0x48`), binary
(`0b01001000`), or as character literals (`'H'`, `'\n'`). Any literal
may carry an optional `#` prefix when used as an immediate.

---

## 6. Instructions

The 23 architectural instructions, grouped by class:

| Class            | Mnemonic | Effect                                                  |
| ---------------- | -------- | ------------------------------------------------------- |
| Data movement    | `NOP`    | Do nothing.                                             |
|                  | `MOVI`   | `Rd ← imm8`                                              |
|                  | `LD`     | `Rd ← mem[abs16]`                                        |
|                  | `ST`     | `mem[abs16] ← Rs`                                        |
|                  | `MOV`    | `Rd ← Rs`                                                |
| Arithmetic/logic | `ADD`    | `Rd ← Rd + Rs`                                           |
|                  | `SUB`    | `Rd ← Rd − Rs`                                           |
|                  | `AND`    | `Rd ← Rd & Rs`                                           |
|                  | `OR`     | `Rd ← Rd \| Rs`                                          |
|                  | `XOR`    | `Rd ← Rd ^ Rs`                                           |
|                  | `CMP`    | Set flags as for `Rd − Rs`; `Rd` is not modified.        |
|                  | `INC`    | `Rd ← Rd + 1`                                            |
|                  | `DEC`    | `Rd ← Rd − 1`                                            |
| Branches         | `BR`     | Unconditional jump to `abs16`.                          |
|                  | `BEQ`    | Jump to `abs16` if `Z == 1`.                             |
|                  | `BNE`    | Jump to `abs16` if `Z == 0`.                             |
|                  | `BCS`    | Jump to `abs16` if `C == 1`.                             |
|                  | `BCC`    | Jump to `abs16` if `C == 0`.                             |
|                  | `BMI`    | Jump to `abs16` if `N == 1`.                             |
|                  | `BPL`    | Jump to `abs16` if `N == 0`.                             |
| Stack            | `PUSH`   | `mem[SP--] ← Rs`                                         |
|                  | `POP`    | `Rd ← mem[++SP]`                                         |
| System           | `HLT`    | Halt the CPU.                                           |

---

## 7. Encoding (opcode byte values)

The byte value of each opcode. Opcodes are grouped by class via the
high nibble (`0x0_` data, `0x2_` ALU, `0x4_` branches, `0x6_` stack,
`0x8_` system), which makes a hand-decode of any instruction
straightforward.

```
0x00   NOP
0x01   MOVI Rd, #imm8
0x02   LD   Rd, [abs16]
0x03   ST   Rs, [abs16]
0x04   MOV  Rd, Rs

0x20   ADD  Rd, Rs
0x21   SUB  Rd, Rs
0x22   AND  Rd, Rs
0x23   OR   Rd, Rs
0x24   XOR  Rd, Rs
0x25   CMP  Rd, Rs
0x26   INC  Rd
0x27   DEC  Rd

0x40   BR   abs16
0x41   BEQ  abs16
0x42   BNE  abs16
0x43   BCS  abs16
0x44   BCC  abs16
0x45   BMI  abs16
0x46   BPL  abs16

0x60   PUSH Rs
0x61   POP  Rd

0x80   HLT
```

---

## 8. Flag semantics

### Per-flag rule

| Flag | Set when                                               |
| ---- | ------------------------------------------------------ |
| `Z`  | the 8-bit result equals `0x00`                         |
| `N`  | bit 7 of the 8-bit result is `1`                       |
| `C`  | `ADD` carried out of bit 7 / `SUB`/`CMP` borrowed      |
| `V`  | signed overflow during `ADD`, `SUB`, or `CMP`          |

### What each instruction touches

| Instructions                                  | Z, N      | C         | V        |
| --------------------------------------------- | --------- | --------- | -------- |
| `ADD`, `SUB`, `CMP`                           | updated   | updated   | updated  |
| `AND`, `OR`, `XOR`, `INC`, `DEC`              | updated   | unchanged | cleared  |
| `MOVI`, `LD`, `MOV`, `POP`                    | updated   | unchanged | cleared  |
| `ST`, `PUSH`                                  | unchanged | unchanged | unchanged |
| `BR`, `BEQ`, `BNE`, `BCS`, `BCC`, `BMI`, `BPL` | unchanged | unchanged | unchanged |
| `NOP`, `HLT`                                  | unchanged | unchanged | unchanged |

`CMP Rd, Rs` performs the same arithmetic as `SUB Rd, Rs` but does not
write the difference back. It exists so a comparison + branch sequence
(`CMP R0, R1` → `BEQ ...`) does not perturb the operand registers.
