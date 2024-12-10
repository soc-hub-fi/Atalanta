# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added
- NanoDMA instance with interrupt-based test
- GPIO output sanity test to examples, `vip_rt_top`

### Fixed
- `OtherRules` bad initialization
- DMA undriven ports
- DMA `read_mgr.addr` and `write_mgr.addr` latches
- DMA `rd_req` and `wr_req` combo loops
- uart.sv duplicated newline behaviour
- Peripheral memory map to fit SPI
- AXI address mapping end address

### Changed
- RT-Ibex initial fetch address to BASE+0x100 (was 0x80) to accomodate 64 entry vector table
- FPGA flow timing error handling

## [v0.1.0] - 2024-11-15

### Added

- Changelog

[unreleased]: https://github.com/soc-hub-fi/Atalanta/compare/v0.1.0...HEAD
