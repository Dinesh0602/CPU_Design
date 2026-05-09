# TinyCPU — A Software CPU in C++

TinyCPU is a complete CPU built entirely in software. Source assembly
is read by a two-pass assembler, the resulting bytes are loaded into a
64 KiB memory, and a component-based emulator (Register File, ALU,
Bus, and Control Unit) executes them one instruction at a time, with
all I/O handled through memory-mapped ports.

The repository ships every piece the assignment calls for:

| Required piece                              | Where it lives                                                                                                |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| CPU schematic                               | [docs/schematic.png](docs/schematic.png)                                                                      |
| ISA spec                                    | [docs/ISA.md](docs/ISA.md)                                                                                    |
| Emulator — registers / ALU / control unit / bus / memory / MMIO | [src/register_file.hpp](src/register_file.hpp), [src/alu.hpp](src/alu.hpp), [src/bus.hpp](src/bus.hpp), [src/control_unit.hpp](src/control_unit.hpp) |
| Top-level CPU facade                        | [src/cpu.hpp](src/cpu.hpp)                                                                                    |
| Loader, runner, memory dump                 | [src/main.cpp](src/main.cpp)                                                                                  |
| Two-pass assembler with labels and literals | [src/assembler.hpp](src/assembler.hpp), [src/assembler.cpp](src/assembler.cpp)                                |
| Hello, World                                | [examples/hello.asm](examples/hello.asm)                                                                      |
| Fibonacci sequence                          | [examples/fib.asm](examples/fib.asm)                                                                          |
| Timer / Fetch-Decode-Execute demo           | [examples/timer.asm](examples/timer.asm)                                                                      |
| Project report                              | [docs/project_report.md](docs/project_report.md)                                                              |

## Architecture in one paragraph

The emulator is split into four components instead of being one
monolithic class. The **register file** owns `R0..R7`, `PC`, `SP`,
and the flags. The **ALU** is stateless — pure functions that compute
a result and update flags. The **bus** owns the 64 KiB of RAM, the
on-chip cycle counter, and the MMIO routing for the TTY and timer.
The **control unit** drives Fetch / Decode / Execute via a
**table-driven decoder**: a static table maps each opcode to a
small handler function, so adding a new instruction is one new row.

## Build

```bash
mkdir -p build
c++ -std=c++17 -O2 -Wall -Wextra -o build/tinycpu \
    src/main.cpp src/control_unit.cpp src/bus.cpp \
    src/alu.cpp  src/assembler.cpp    src/isa.cpp
```

Either `g++` or `clang++` works.

## Run the example programs

Hello, World — assemble, run, and dump memory after halt:

```bash
./build/tinycpu asm examples/hello.asm -o hello.bin
./build/tinycpu run hello.bin --trace --dump-after 0x0000:0x005F
```

Fibonacci — outputs raw bytes; pipe through `xxd` to read them:

```bash
./build/tinycpu asm examples/fib.asm -o fib.bin
./build/tinycpu run fib.bin | xxd
```

Expected first 11 bytes: `00 01 01 02 03 05 08 0d 15 22 37` →
0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55.

Timer / cycle-trace demo — see one trace line per Fetch/Decode/Execute:

```bash
./build/tinycpu asm examples/timer.asm -o timer.bin
./build/tinycpu run timer.bin --trace
```

## CLI quick reference

| Command                                                                | Purpose                                     |
| ---------------------------------------------------------------------- | ------------------------------------------- |
| `tinycpu asm  <src.asm> -o <out.bin>`                                  | Assemble source to a flat binary.           |
| `tinycpu run  <bin> [--origin 0x..] [--trace] [--dump-after F:T]`      | Load, run, optionally trace and dump.       |
| `tinycpu dump <bin> [--origin 0x..] [F:T]`                             | Hex-dump a binary as if it were loaded.     |
