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
| Build and demo automation                   | [Makefile](Makefile)                                                                                         |

## Architecture in one paragraph

The emulator is split into four components instead of being one
monolithic class. The **register file** owns `R0..R7`, `PC`, `SP`,
and the flags. The **ALU** is stateless — pure functions that compute
a result and update flags. The **bus** owns the 64 KiB of RAM, the
on-chip cycle counter, and the MMIO routing for the TTY and timer.
The **control unit** drives Fetch / Decode / Execute via a
**table-driven decoder**: a static table maps each opcode to a
small handler function, so adding a new instruction is one new row.

## Requirements

You need a C++17 compiler and `make`.

Either `g++` or `clang++` works. The Makefile uses `c++` by default,
which usually points to the system C++ compiler.

For the Fibonacci demo output formatting, the Makefile also uses `xxd`,
which is available by default on most Linux and macOS systems.

## Quick start

Build the TinyCPU emulator:

```bash
make
```

Assemble and run the Fibonacci demo:

```bash
make fib
```

This command compiles the emulator, assembles `examples/fib.asm` into
`build/fib.bin`, runs it on the TinyCPU emulator, and prints the expected
and actual output.

Expected output:

```text
00 01 01 02 03 05 08 0d 15 22 37
```

These are raw hexadecimal byte values. In decimal, they are:

```text
0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55
```

## Makefile commands

| Command      | Purpose                                                        |
| ------------ | -------------------------------------------------------------- |
| `make`       | Build the TinyCPU emulator.                                    |
| `make fib`   | Assemble and run the Fibonacci sequence demo.                  |
| `make hello` | Assemble and run the Hello, World demo.                        |
| `make timer` | Assemble and run the timer demo.                               |
| `make trace` | Assemble and run the timer demo with instruction tracing.      |
| `make dump`  | Assemble Fibonacci and dump the generated memory image.        |
| `make clean` | Remove generated build files.                                  |
| `make help`  | Show the available Makefile commands.                          |

## Run the example programs with Makefile

### Fibonacci sequence

```bash
make fib
```

The Fibonacci program writes raw byte values to the memory-mapped TTY
output port at address `0xC000`. The Makefile formats those bytes so the
sequence is easy to read.

Expected first 11 bytes:

```text
00 01 01 02 03 05 08 0d 15 22 37
```

Decimal interpretation:

```text
0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55
```

### Hello, World

```bash
make hello
```

The Hello, World program prints characters by writing each character byte
to the memory-mapped TTY output port at address `0xC000`.

### Timer / instruction trace demo

```bash
make trace
```

The trace demo runs the timer example with tracing enabled. This shows one
trace line per executed instruction, which helps demonstrate the CPU's
Fetch / Decode / Execute cycle.

## Manual build

The Makefile is the recommended way to build and run the project, but the
same build can also be done manually:

```bash
mkdir -p build
c++ -std=c++17 -O2 -Wall -Wextra -o build/tinycpu \
    src/main.cpp src/control_unit.cpp src/bus.cpp \
    src/alu.cpp src/assembler.cpp src/isa.cpp
```

## Manual run commands

### Hello, World

Assemble, run, and dump memory after halt:

```bash
./build/tinycpu asm examples/hello.asm -o build/hello.bin
./build/tinycpu run build/hello.bin --trace --dump-after 0x0000:0x005F
```

### Fibonacci sequence

Assemble and run:

```bash
./build/tinycpu asm examples/fib.asm -o build/fib.bin
./build/tinycpu run build/fib.bin | xxd -p -c 256 | sed 's/../& /g' | sed 's/ $//'
```

Expected first 11 bytes:

```text
00 01 01 02 03 05 08 0d 15 22 37
```

### Timer / cycle-trace demo

Assemble and run with trace enabled:

```bash
./build/tinycpu asm examples/timer.asm -o build/timer.bin
./build/tinycpu run build/timer.bin --trace
```

## CLI quick reference

| Command                                                           | Purpose                                |
| ----------------------------------------------------------------- | -------------------------------------- |
| `tinycpu asm <src.asm> -o <out.bin>`                              | Assemble source to a flat binary.      |
| `tinycpu run <bin> [--origin 0x..] [--trace] [--dump-after F:T]`  | Load, run, optionally trace and dump.  |
| `tinycpu dump <bin> [--origin 0x..] [F:T]`                        | Hex-dump a binary as if it were loaded. |

## Clean generated files

Remove the build directory and generated binaries:

```bash
make clean
```

## Important Links

- [GitHub Repository](https://github.com/Dinesh0602/CPU_Design)
- [Demo Video](https://drive.google.com/file/d/1K-24X_4zY1k-5s9ytleoQ0g5UTink5NY/view?usp=drive_link)
- [Report](https://docs.google.com/document/d/1IGAPWipW6TN5aTECrqoANggwxLhHdnGnWOryLURU98U/view)


This is the main project demo because it shows the full pipeline:
assembly source code, assembler output, CPU emulation, ALU/register
updates during execution, memory-mapped I/O, and final Fibonacci output.