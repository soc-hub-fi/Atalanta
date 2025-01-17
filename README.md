# Atalanta, a Predictable RISC-V Microcontroller

## Getting started
Dependencies are managed with [Bender](https://github.com/pulp-platform/bender) and can be fetched by calling
```
make repository_init
```

## Simulation

### Dependencies

- The Verilator features used here depend on GCC 10 or newer, or Clang (untested). Ensure your compiler is suitable before proceeding.
- This build is developed on top of version *5.008*. Currently, this requires a manual [installation](https://verilator.org/guide/latest/install.html#git-quick-install).
- [Elf2Hex](https://github.com/sifive/elf2hex) is used to create hex-stims from ELF-binaries when loading programs with `$readmemh`.

### with Verilator

Verilator simulations can be invoked from the repository root with
```
make verilate simv TEST=<name of test, e.g. 'uart_sanity'>
```
This will clean and compile the design and the software test, then invoke the simulation.

By default, programs are loaded with `$readmemh` (applicable to simulations only). JTAG-based serial loading is supported and can be invoked by appending `JTAG_LOAD=1` to the above command.

An Instruction trace and a `.fst` waveform are always generated under `build/verilator_build`.


### with Questa

RTL simulation is tested with QuestaSim-64 10.7g and 24.2

To compile the design and run batch simulations, use

```sh
make compile elaborate simulate TEST=<name of test, e.g. 'uart_sanity'>
```

from the repository root.





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

Software compulation is implicitly included in the simulator invocation. Artifacts are generated under `examples/*/build`.


## Citing

If you use our work, please consider citing it as 
```
@InProceedings{AN2024,
 author="Nurmi, Antti
 and Lindgren, Per
 and Kalache, Abdesattar
 and Lunnikivi, Henri
 and H{\"a}m{\"a}l{\"a}inen, Timo D.",
 editor="Fey, Dietmar
 and Stabernack, Benno
 and Lankes, Stefan
 and Pacher, Mathias
 and Pionteck, Thilo",
 title="Atalanta: Open-Source RISC-V Microcontroller for Rust-Based Hard Real-Time Systems",
 booktitle="Architecture of Computing Systems",
 year="2024",
 publisher="Springer Nature Switzerland",
 address="Cham",
 pages="316--330",
 isbn="978-3-031-66146-4"
}

```

