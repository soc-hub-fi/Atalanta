verilator --cc \
../ips/ibex/rtl/ibex_pkg.sv \
-I../ips/ibex/vendor/lowrisc_ip/ip/prim/rtl \
-I../ips/ibex/vendor/lowrisc_ip/dv/sv/dv_utils \
../ips/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_ram_1p_pkg.sv \
../ips/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_secded_pkg.sv \
../ips/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_util_pkg.sv \
../ips/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_cipher_pkg.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/cf_math_pkg.sv \
../ips/riscv-dbg/src/dm_pkg.sv \
../ips/ibex/syn/rtl/prim_clock_gating.v \
../ips/ibex/dv/uvm/core_ibex/common/prim/prim_buf.sv \
../ips/ibex/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_generic_buf.sv \
../ips/ibex/rtl/ibex_register_file_ff.sv \
-I../ips/ibex/rtl \
../ips/ibex/rtl/ibex_cs_registers.sv \
../ips/ibex/rtl/ibex_core.sv \
../ips/ibex/rtl/ibex_top.sv \
-I../ips/bow-common-ips/ips/axi/include \
../ips/bow-common-ips/ips/axi/src/axi_pkg.sv \
../ips/bow-common-ips/ips/axi/src/axi_intf.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/fifo_v3.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/deprecated/fifo_v2.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/spill_register.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/delta_counter.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/rr_arb_tree.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/lzc.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/counter.sv \
-I../ips/bow-common-ips/ips/pulp-common-cells/include \
../ips/bow-common-ips/ips/axi/src/axi_lite_to_apb.sv \
../ips/bow-common-ips/ips/axi/src/axi_lite_demux.sv \
../ips/bow-common-ips/ips/axi/src/axi_err_slv.sv \
../ips/bow-common-ips/ips/axi/src/axi_lite_mux.sv \
../ips/bow-common-ips/ips/axi/src/axi_lite_to_axi.sv \
../ips/bow-common-ips/ips/axi/src/axi_lite_xbar.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/addr_decode.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/fall_through_register.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/onehot_to_bin.sv \
../ips/bow-common-ips/ips/tech_cells_generic/src/deprecated/pulp_clk_cells.sv \
../ips/bow-common-ips/ips/tech_cells_generic/src/rtl/tc_clk.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/spill_register_flushable.sv \
../ips/bow-common-ips/ips/tech_cells_generic/src/deprecated/cluster_clk_cells.sv \
../ips/bow-common-ips/ips/pulp-common-cells/src/cdc_2phase.sv \
../ips/riscv-dbg/debug_rom/debug_rom_one_scratch.sv \
../ips/riscv-dbg/debug_rom/debug_rom.sv \
../ips/riscv-dbg/src/dmi_cdc.sv \
../ips/riscv-dbg/src/dmi_jtag_tap.sv \
../ips/riscv-dbg/src/dm_sba.sv \
../ips/riscv-dbg/src/dm_mem.sv \
../ips/riscv-dbg/src/dm_csrs.sv \
../ips/riscv-dbg/src/dm_top.sv \
../ips/riscv-dbg/src/dmi_jtag.sv \
../src/ip/rt_debug.sv \
../src/ip/rt_ibex_bootrom.sv \
../src/ip/ibex_axi_bridge.sv \
../src/ip/mem_axi_bridge.sv \
../src/ip/rt_mem_wrapper.sv \
../src/ip/rt_uart_wrapper.sv \
../src/ip/sram.sv \
../src/ip/rt_reg_if.sv \
../src/ip/rt_gpio_wrapper.sv \
../src/ip/rt_ibex_wrapper.sv \
../src/ip/rt_top.sv --top-module rt_top \
-Wno-LATCH -Wno-WIDTHCONCAT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-STMTDLY \
$1 --timing -Wno-CMPCONST -Wno-UNOPTFLAT -Wno-TIMESCALEMOD -Wno-UNSIGNED \
--trace --x-assign unique --timescale-override "1ns/1ps" --x-initial unique --exe tb_rt_top.cc

RESULT=$?
if [ $RESULT -eq 0 ]; then
  if [ "$1"  =  "--lint-only" ]; then
    echo Linting passed
  else
    make -C obj_dir -f Vrt_top.mk Vrt_top
    echo Sources compiled
  fi
else
  echo Compilation failed
fi



