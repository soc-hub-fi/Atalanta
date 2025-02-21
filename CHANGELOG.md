# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added
- 4 * 32-bit timer group
- QSPI APB peripheral (umapped in FPGA)

### Fixed
- Wake from sleep with IRQ
- Mtimer X values
- Mtimer with new implementation

### Changed
- rt-ibex to version with functional hardware stacking
- Peripherals frequency to be runtime-configurable
- Make Mtimer writable

## [v0.2.0] - 2025-01-24

### Fixed
- Verilator support after long stale period
- Erronious hard-coded program entry address

### Added
- PCS instance to default design configuration
- Readmem-program loading for Verilator
- C++ port of elfloader for Verilator
- "wfi" to timer_test to accommodate for rt-ibex's sleep mode
- Support for UART receiver in Atalanta and its TB environment
- UART_RX test case and updated UART baudrate  

### Changed
- OBI Bender dependency to vendor package to avoid problematic syntax in `obi_cut.sv`
- Core fully-connected crossbar to partially-connected pseudo-crossbar
- Refactor smoke_tests and handling of crt0.s in SW flow 

## [v0.1.1] - 2024-12-11

### Added
- NanoDMA instance with interrupt-based test
- GPIO output sanity test to examples, `vip_rt_top`

### Fixed
- interconnect address map width
- `OtherRules` bad initialization
- DMA undriven ports
- DMA `read_mgr.addr` and `write_mgr.addr` latches
- DMA `rd_req` and `wr_req` combo loops
- uart.sv duplicated newline behavior
- Peripheral memory map to fit SPI
- AXI address mapping end address

### Changed
- RT-Ibex initial fetch address to BASE+0x100 (was 0x80) to accommodate 64 entry vector table
- FPGA flow timing error handling

### Removed
- OpenTitan SPI host IP due to internal undriven port

## [v0.1.0] - 2024-11-15

### Added

- Changelog

[unreleased]: https://github.com/soc-hub-fi/Atalanta/compare/v0.1.0...HEAD
