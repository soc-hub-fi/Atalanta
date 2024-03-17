# Real-Time Subsystem for Bow SoC

## Open items

- DUT expansion (CLIC, AnTiQ)
- Yosys flow
- Testset expansion

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
make simulate <Test Name>=1 STIM_PATH="<Path to Stimulus>"
```

The default `STIM_PATH` points to `./stims/nop_loop.hex` to provide a non-functional yet valid program to the CPU instruction memory. `make simulate` will generate the waveform of the simulation in both `vcd` and `wlf` format.

```sh
make wave
```

is a shortcut for `gtkwave waveform.vcd` that can be used to open the `vcd` file with GTKWave. The `wlf` file can be viewed in Questa with `vsim wave.wlf`.

## Simulation with Verilator

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

## Continuous Integration (CI) Management

Ideally, *all* compilation flows and tests would be run as part of the CI with every commit. In reality this is not practical, but the general guidance should be to include as much of these to the CI as is possible.

### Nightly Run

Certain CI jobs, e.g. FPGA synthesis, will take a significant amount of time (> 5 min). In an effort to decongest our (very limited) CI runners, move long CI jobs to the *RT-SS Nightly* CI run. This can be done by adding

```yml
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

### Test Checking

TODO: document adding new tests.

Test outputs are checked with `./check_output.sh`. Use **exactly** `[FAILED]` or `[PASSED]` prints to indicate the result of a test.

## Development and Merge Operations

Project development should be done via feature branches. Merge branches to main often. For fluent merge housekeeping do following. From settings -> Merge requests:

- Enable "delete source branch" option by default: Yes (checkmark the box)

- Squash commits when merging: Encourage or Require. This will clean up main branch history by huge amount.

- Merge checks: Pipelines must succeed: Yes

- Merge checks: Skipped pipelines are considered successfull: No

- Merge checks: All threads must be resolved: Yes

Merges should be **always** reviewed and accepted by another developer.

## Documentation

NDocs documentation available at <https://soc-hub.gitlab-pages.tuni.fi/bow/hw/rt-ss>

## Repository pipeline settings

To ensure flawless operation for CI, ensure that settings -> CI/CD has following settings:

### General pipelines

- Auto-cancel redundant pipelines: Yes

- Git strategy: git clone

- Git shallow clone: 1

### Runners

- Available group runner: tie-sochub-gitlabrunner-ci (if missing contact <matti.kayra@tuni.fi> and/or <arto.oinonen@tuni.fi>)

### Token Access

- Limit access: No (it would prevent hiearchical repository access in CI)

## Pipeline status

Like with the pages, Change **common/ss-template** as you repo path to see pipeline status images as part of this header readme.

Pipeline status: [![pipeline status](https://gitlab.tuni.fi/soc-hub/bow/hw/rt-ss/badges/main/pipeline.svg)](https://gitlab.tuni.fi/soc-hub/bow/hw/rt-ss/-/commits/main)

Coverage: [![coverage report](https://gitlab.tuni.fi/soc-hub/bow/hw/rt-ss/badges/main/coverage.svg)](https://gitlab.tuni.fi/soc-hub/bow/hw/rt-ss/-/commits/main)

Latest release: [![Latest Release](https://gitlab.tuni.fi/soc-hub/bow/hw/rt-ss/-/badges/release.svg)](https://gitlab.tuni.fi/soc-hub/bow/hw/rt-ss/-/releases)

## Additional important repo notes

Insert source / authors / licences / acknowledgements as deemed needed
