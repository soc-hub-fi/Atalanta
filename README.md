# Atalanta, a RISC-V Microcontroller

## Disclaimer

This project is still in an experimental state and under internal development, therefore we do not take contributions yet.

## Simulation with Questa

To use Questa, i.e. `vsim`, for simulation, source `/opt/soc/eda/mentor/mentor_init.sh` when working on Tulitikli.

To compile the design for Questa, use

```sh
make repository_init #if starting fresh
make compile
make elaborate
```

from the repository root.

To enable the Ibex execution trace, substitute `make compile` with `make compile_debug`, then continue with the regular targets.

To run tests in batch more, use

```sh
make simulate TEST=<TestName>
```

`TestName` can be set to `jtag_test` to test the functionality of the debug module, or matched with a test name from `./stims/`. For example, 

```sh
make simulate TEST=uart_test
```
will reference `./stims/uart_test_imem.hex` and `./stims/uart_test_dmem.hex`.
By default, `vsim` tests will use the JTAG interface to load programs. To set memory loading to use SystemVerilog's `$readmemh` task, set `LOAD=READMEM` when using this Makefile.

 `make simulate` will generate the waveform of the simulation in both `vcd` and `wlf` format.

```sh
make wave
```

is a shortcut for `gtkwave waveform.vcd` that can be used to open the `vcd` file with GTKWave. The `wlf` file can be viewed in Questa with `vsim wave.wlf`.

## Simulation with Verilator [Experimental]

### Dependencies

- The Verilator features used here depend on GCC 10 or newer, or Clang (untested). Ensure your compiler is suitable before proceeding.
- This build is developed on top of version *5.008*. Currently, this requires a manual [installation](https://verilator.org/guide/latest/install.html#git-quick-install).
- Waveforms are viewed with GTKWave, install with ```sudo apt install gtkwave``` if necessary.

### Simulation

Verilator-specific files are within ./verilator.
After navigating to the directory, simulations can be controlled with the following commands:

```sh
make verilate TEST=<TESTNAME> [TRACE=1]# Compile testbench with parameters for <TESTNAME>. 
#<TESTNAME> should match with a stim file pair in ./stims/, e.g. 'TEST=gpio_blink' uses './stims/gpio_blink_imem.hex' and './stims/gpio_blink_dmem.hex'. Set TRACE=1 for CPU trace.
make simv TEST=<TESTNAME>     # Run compiled test in batch mode and produce vcd waveform.
make wave # Open waveform in GTKWave.
make clean # Remove build/build_verilator.
```

## FPGA

### Synthesis

FPGA-specific files are within `./fpga`. The supported commands are:

```sh
make all        # Run clean_all and then top
make top        # Run Vivado flow to generate bitstream (stored under fpga/build/RT-SS)
make all_ips    # Synthesise FPGA IPs required by project only 
make clean_top  # Remove Vivado project and any generated bitstreams
make clean_ips  # Remove all synthesised IPs
make clean_all  # Remove all existing build products 
```

### Prototyping

The design is currently supported for the PYNQ-Z1 FPGA board. Run the above synthesis flow to generate the bitstream file `RT-SS_fpga.bit`. Alternatively, check the artifacts of the RT-SS Nightly CI pipeline for an instance of the bitstream built from the main branch.

### Prerequisites

[RISC-V OpenOCD](https://github.com/riscv/riscv-openocd) is required to communicate with the design. To connect via JTAG to the debug module of the design, use a FT2232-based debug probe. Relevant documentation: [IC Datasheet](https://ftdichip.com/wp-content/uploads/2020/07/DS_FT2232H.pdf), [Mini-module](https://ftdichip.com/wp-content/uploads/2020/07/DS_FT2232H_Mini_Module.pdf).

### Setup

The probe is connected with the following pinout:

```text
BD0 -> CK_IO37
BD1 -> CK_IO0
BD2 -> CK_IO1
BD3 -> CK_IO3
GND -> GND
```

The switches on the board control `rst_i` and `jtag_trst_ni`. The correct positions for normal operation are:

```text
SW0 : down (away from 'SW0' label)
SW1 : up (towards 'SW1' label)
```

### UART

The UART pins are mapped to:

```text
UART_RX_I -> CK_IO12
UART_TX_O -> CK_IO13
```

### Communication

After physical connections are correctly setup, launch OpenOCD with

```sh
riscv-openocd -f ./fpga/utils/ft232_openocd_RT-SS.cfg
```

You may need to adjust the tracked config file slightly. BUG: Currently, the first connection attempt always fails, but retrying immediately will connect successfully. Once the terminal echoes "Ready for Remote Connections", open a new terminal and use

```sh
riscv32-unknown-elf-gdb <Test ELF> -x ./fpga/utils/rt-ss.gdb
```

The `.gdb` file automates connecting GDB to the debug module and loading the ELF into the program memory.

## Software Compilation

The functional testing of the subsystem is performed with software-based tests. The source code for C tests is located in `./examples/smoke_tests`, along with a common, minimal `crt0.S` and a linker script `link.ld`. The Python3 requirements for `compile.py` are stored in `./examples/smoke_tests/scripts/requirements.txt`.
To Compile a test, run

```sh
./examples/smoke_tests/scripts/compile.py ./examples/smoke_tests/<test_name>.c
```

if compiling with a local riscv32-gcc or

```sh
./examples/smoke_tests/scripts/compile.py ./examples/smoke_tests/<test_name>.c --riscv-xlen 64
```

if working on the Tulitikli environment. The compiled programs are formatted to `.hex` and stored in `./stims/` and the `.elf` is stored in `./elf/`.

**NOTE**: The compilation of stim-files for tests is part of the CI pipeline and thus the files are not tracked in Git. **Do not add new files to `./stims/` in Git**.



## Additional important repo notes

Insert source / authors / licences / acknowledgements as deemed needed
