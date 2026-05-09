# TinyCPU — Project Report

**Project:** A complete software CPU implemented in C/C++
**Team members:** Dinesh Buruboyina, Jainam Chhatbar, Kalyani Chitre, Manish Maryala
**Date:** May 2026

---

## 1. Overview

TinyCPU is a fully functional CPU implemented entirely in software. It
defines its own Instruction Set Architecture, an emulator that
exercises every required architectural element (registers, ALU, control
unit, system bus, main memory, and memory-mapped I/O), a two-pass
assembler that turns human-readable mnemonics into a binary image, and
three example programs that demonstrate the Fetch / Decode / Execute
pipeline end-to-end.

### Repository layout

```
tinycpu_project/
├── README.md
├── docs/
│   ├── ISA.md                 ; instruction-set specification
│   ├── project_report.md      ; this document
│   └── schematic.png          ; CPU architecture diagram
├── examples/
│   ├── hello.asm              ; "Hello, World" via MMIO TTY
│   ├── fib.asm                ; first 11 Fibonacci numbers
│   └── timer.asm              ; Fetch/Decode/Execute demo + on-chip timer
└── src/
    ├── isa.{hpp,cpp}          ; opcodes, register codes, memory map (single source of truth)
    ├── register_file.hpp      ; R0..R7 + PC + SP + Flags
    ├── alu.{hpp,cpp}          ; pure-function arithmetic and logic
    ├── bus.{hpp,cpp}          ; memory + cycle counter + MMIO routing
    ├── control_unit.{hpp,cpp} ; Fetch/Decode/Execute, table-driven decoder
    ├── cpu.hpp                ; facade that composes the four components
    ├── assembler.{hpp,cpp}    ; two-pass assembler with labels and literals
    └── main.cpp               ; CLI: assemble / run / dump
```

The architecture is split into separate components rather than a single
monolithic class. That makes each architectural piece testable in
isolation and makes it obvious which file owns which concern.

---

## 2. CPU Schematic

A single-page architectural drawing is in
[`docs/schematic.png`](schematic.png). It shows the eight 8-bit
general-purpose registers, the program counter and stack pointer, the
ALU on the data path, the Control Unit driving Fetch / Decode /
Execute, and the system bus that ties memory, timer, and TTY together.

---

## 3. Instruction Set Architecture

The full specification is in [`docs/ISA.md`](ISA.md). At a glance:

- **Word sizes** — 8-bit byte, 16-bit little-endian word, 64 KiB byte-addressable memory.
- **Registers** — `R0..R7` (8-bit), `PC` and `SP` (16-bit), plus four flags (`Z, N, C, V`).
- **Instruction format** — 1 opcode byte + 0..3 operand bytes; size determined entirely by opcode.
- **Operand layouts** — six fixed shapes (`None`, `R`, `R_imm`, `R_R`, `R_addr`, `Addr`).
- **Instructions** — 23 total: data movement (`NOP`, `MOVI`, `LD`, `ST`, `MOV`),
  arithmetic & logic (`ADD`, `SUB`, `AND`, `OR`, `XOR`, `CMP`, `INC`, `DEC`),
  branches (`BR`, `BEQ`, `BNE`, `BCS`, `BCC`, `BMI`, `BPL`),
  stack (`PUSH`, `POP`), and system (`HLT`).
- **Encoding** — opcodes are grouped by class via the high nibble:
  `0x0_` = data movement, `0x2_` = ALU, `0x4_` = branches, `0x6_` = stack, `0x8_` = system.
- **Addressing modes** — immediate (`#imm8`), absolute (`abs16`, with optional `[..]` syntax),
  register (`R0..R7`), and label (resolved during the assembler's first pass).
- **Memory map** — RAM in `0x0000..0xBFFF`, MMIO at `0xC000` (TTY_OUT),
  `0xC001` (TTY_IN), `0xC010` (TIMER), `0xC011` (TIMER_CTRL); rest is RAM again.
- **Flag semantics** — `Z, N, C, V` updated according to the rules in the ISA spec;
  `CMP` is `SUB` without writeback.

---

## 4. Emulator

The emulator is built as four independently-meaningful classes that the
top-level `CPU` facade composes together.

### 4.1 Register File — [`src/register_file.hpp`](../src/register_file.hpp)

Holds the architectural state: the eight 8-bit GPRs `R0..R7`, the
16-bit `PC` and `SP`, and the `Flags` struct. The interface is
deliberately small — `read`, `write`, `pc`, `set_pc`, `advance_pc`,
`push_sp`, `pop_sp`, `flags()` — so no other component is allowed to
touch the registers as a raw array.

### 4.2 ALU — [`src/alu.hpp`](../src/alu.hpp), [`src/alu.cpp`](../src/alu.cpp)

A set of pure functions: each takes the operand bytes and a reference
to `Flags`, returns the 8-bit result, and updates exactly the flags
that the ISA's flag-semantics table says it should. Carry and signed-
overflow are computed from a wider intermediate so the rules are easy
to verify against the spec.

### 4.3 Bus — [`src/bus.hpp`](../src/bus.hpp), [`src/bus.cpp`](../src/bus.cpp)

The bus owns the 64 KiB of physical RAM, the on-chip cycle counter, and
the dispatch of memory-mapped I/O. Every architectural memory access
flows through `Bus::read` / `Bus::write`, so MMIO routing happens in
exactly one place. TTY in/out are wired in as `std::function`
callbacks, which keeps the bus extensible — adding a new MMIO device is
a one-line callback registration.

### 4.4 Control Unit — [`src/control_unit.hpp`](../src/control_unit.hpp), [`src/control_unit.cpp`](../src/control_unit.cpp)

Drives Fetch / Decode / Execute. Decoding is **table-driven**: a static
array of `{opcode, mnemonic, handler}` entries is searched by the
opcode byte, and the matched handler runs. Each handler is a small,
focused function — there is no central `switch` statement, and adding
a new instruction is local: one new handler, one new table row.

### 4.5 Memory and MMIO

Backed by `std::array<uint8_t, 65536>` inside the bus. The four MMIO
ports:

| Port            | Address | Direction | Behaviour                                  |
| --------------- | ------- | --------- | ------------------------------------------ |
| `TTY_OUT`       | `0xC000`| write     | Byte sent to host stdout.                  |
| `TTY_IN`        | `0xC001`| read      | Byte from host stdin (0 if no key).        |
| `TIMER`         | `0xC010`| read      | Low byte of the running cycle counter.     |
| `TIMER_CTRL`    | `0xC011`| write     | Bit 0 = 1 resets the cycle counter.        |

### 4.6 Load, Run, Memory Dump

The CPU facade exposes `load`, `step` / `run_to_halt`, and `dump`. The
CLI driver wraps these into the `asm`, `run`, and `dump` subcommands.
With `--trace`, the control unit prints one disassembled line per
retired instruction; with `--dump-after F:T`, the bus prints a hex dump
of the requested window after the program halts.

---

## 5. Assembler

[`src/assembler.cpp`](../src/assembler.cpp) is a clean two-pass
assembler whose encoding is fully data-driven by a single mnemonic table.

### 5.1 Lexing

Each line is split into tokens. Whitespace and `,` are separators; `;`
starts a line comment; `"..."` and `'...'` literals are kept as single
tokens; an optional leading `label:` is detached. The result is a
vector of `LexedLine` records.

### 5.2 Pass 1 — sizing (label discovery)

Walk every `LexedLine`, looking up its mnemonic in the operand-shape
table to learn the instruction's size in bytes, and record the running
`pc` for any label encountered. This pass produces the symbol table and
nothing else, which is what allows **forward** label references like
`BR loop` before `loop:` is defined.

### 5.3 Pass 2 — code production

Walk the lines again. Each mnemonic's `Shape` (`None`, `R`, `R_imm`,
`R_R`, `R_addr`, `Addr`) tells the assembler how many operand bytes to
emit and in what order. Numbers come from `parse_number` (decimal, hex,
binary, or character literals); addresses come from `resolve`, which
first consults the symbol table and then falls back to `parse_number`.

### 5.4 Numeric literals and labels

Supported literal forms:
- Decimal (`42`)
- Hexadecimal (`0xFF10`)
- Binary (`0b00101010`)
- Character (`'H'`, `'\n'`, `'\t'`, etc.)

Labels are case-insensitive identifiers ending in `:`. They may be
defined on a line of their own or in front of an instruction.

### 5.5 Directives

| Directive | Effect                                                               |
| --------- | -------------------------------------------------------------------- |
| `.org N`  | Sets the origin / continues output at address `N` (NOP-padded).      |
| `.byte ...` | Emits each operand as a single byte; `"strings"` are expanded char-by-char. |
| `.word ...` | Emits each operand as a 16-bit little-endian word; labels accepted. |

---

## 6. Programs

Three example programs ship with the project, each lining up with one
required demo from the assignment.

### 6.1 Timer / Fetch–Decode–Execute demo — [`examples/timer.asm`](../examples/timer.asm)

A short loop chosen so that running it under `--trace` produces a
readable, labelled record of every Fetch / Decode / Execute cycle.
After the loop finishes, the program reads `TIMER` (`0xC010`) into a
register and stores it back to `TTY_OUT`, which simultaneously
demonstrates an MMIO load and the on-chip timer.

```bash
./tinycpu asm  ../examples/timer.asm -o timer.bin
./tinycpu run  timer.bin --trace
```

### 6.2 Hello, World — [`examples/hello.asm`](../examples/hello.asm)

Loads each character of `"Hello, World\n"` into `R0` with `MOVI` and
stores it through `ST R0, [0xC000]`. Demonstrates `MOVI`, `ST`, `HLT`,
character literals, and the MMIO-only I/O model.

```bash
./tinycpu asm  ../examples/hello.asm -o hello.bin
./tinycpu run  hello.bin --trace --dump-after 0x0000:0x005F
```

### 6.3 Fibonacci sequence — [`examples/fib.asm`](../examples/fib.asm)

Computes the first 11 Fibonacci terms by holding the running pair in
`R0` / `R1`, using `R2` as a scratch swap, and counting iterations down
in `R3`. Exercises the ALU (`ADD`, `DEC`), data movement (`MOV`),
conditional control flow (`BNE`), and MMIO output in one short
program.

```bash
./tinycpu asm  ../examples/fib.asm -o fib.bin
./tinycpu run  fib.bin | xxd
```

Expected first 11 bytes: `00 01 01 02 03 05 08 0d 15 22 37`
(0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55).

---

## 7. Build and CLI

```bash
mkdir -p build
c++ -std=c++17 -O2 -Wall -Wextra -o build/tinycpu \
    src/main.cpp src/control_unit.cpp src/bus.cpp \
    src/alu.cpp  src/assembler.cpp    src/isa.cpp
```

The CLI exposes three subcommands:

| Command                                                             | Purpose                                          |
| ------------------------------------------------------------------- | ------------------------------------------------ |
| `tinycpu asm  <src.asm> -o <out.bin>`                               | Assemble source to a flat binary.                |
| `tinycpu run  <bin> [--origin 0x..] [--trace] [--dump-after F:T]`   | Load, run, optionally trace and dump memory.     |
| `tinycpu dump <bin> [--origin 0x..] [F:T]`                          | Hex-dump a binary as if it were loaded.          |

---

## 8. Contributions

| Member               | Area of responsibility |
| -------------------- | ---------------------- |
| **Dinesh Buruboyina** | Bus, MMIO routing, timer, integration of the four components into the `CPU` facade |
| **Jainam Chhatbar**   | Assembler (lexer, two passes, mnemonic table, numeric and character literals); ISA documentation |
| **Kalyani Chitre**    | Register file and ALU (arithmetic, logic, flag semantics); example programs |
| **Manish Maryala**    | Control unit and table-driven decoder; CPU schematic; project report; end-to-end testing |

Every member reviewed the others' pull requests and contributed to the
final integration pass.

---

*Formatting tip:* to export this report as a PDF with double spacing,
1-inch margins, and footer page numbers, open it in Google Docs or Word
and apply those settings before exporting.
