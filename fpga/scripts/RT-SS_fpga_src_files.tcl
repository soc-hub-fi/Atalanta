# ------------------------------------------------------------------------------
# RT-SS_fpga_src_files.tcl
#
# Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
# Date     : 03-dec-2023
#
# Description: Source file list for the FPGA prototype of the RT-SS. Adds source
# files/packages to project and sets the project include directories
#
# Ascii art headers generated using https://textkool.com/en/ascii-art-generator
# (style: ANSI Shadow)
# ------------------------------------------------------------------------------

# Clear the console output
puts "\n---------------------------------------------------------";
puts "RT-SS_fpga_src_files.tcl - Starting...";
puts "---------------------------------------------------------\n";

# ██╗███╗   ██╗ ██████╗██╗     ██╗   ██╗██████╗ ███████╗███████╗
# ██║████╗  ██║██╔════╝██║     ██║   ██║██╔══██╗██╔════╝██╔════╝
# ██║██╔██╗ ██║██║     ██║     ██║   ██║██║  ██║█████╗  ███████╗
# ██║██║╚██╗██║██║     ██║     ██║   ██║██║  ██║██╔══╝  ╚════██║
# ██║██║ ╚████║╚██████╗███████╗╚██████╔╝██████╔╝███████╗███████║
# ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝

set RT_SS_INCLUDE_PATHS " \
  ${REPO_DIR}/ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl \
  ${REPO_DIR}/ips/rt-ibex/rtl \
  ${REPO_DIR}/ips/rt-ibex/vendor/lowrisc_ip/dv/sv/dv_utils \
  ${REPO_DIR}/ips/register_interface/include \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/include \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/include \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src \
";

set_property include_dirs ${RT_SS_INCLUDE_PATHS} [current_fileset];
set_property include_dirs ${RT_SS_INCLUDE_PATHS} [current_fileset -simset];

# ██╗██████╗ ███████╗██╗  ██╗
# ██║██╔══██╗██╔════╝╚██╗██╔╝
# ██║██████╔╝█████╗   ╚███╔╝ 
# ██║██╔══██╗██╔══╝   ██╔██╗ 
# ██║██████╔╝███████╗██╔╝ ██╗
# ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

set RT_SS_IBEX_SRC " \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_pkg.sv \
  ${REPO_DIR}/ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_ram_1p_pkg.sv \
  ${REPO_DIR}/ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_secded_pkg.sv \
  ${REPO_DIR}/ips/rt-ibex/dv/uvm/core_ibex/common/prim/prim_buf.sv \
  ${REPO_DIR}/ips/rt-ibex/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_generic_buf.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_register_file_fpga.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_counter.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_icache.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_id_stage.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_pkg.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_compressed_decoder.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_decoder.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_prefetch_buffer.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_multdiv_fast.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_if_stage.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_multdiv_slow.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_lockstep.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_controller.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_core.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_csr.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_top.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_branch_predict.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_alu.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_fetch_fifo.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_ex_block.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_cs_registers.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_load_store_unit.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_wb_stage.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_pmp.sv \
  ${REPO_DIR}/ips/rt-ibex/rtl/ibex_dummy_instr.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_IBEX_SRC};


# ██████╗ ██╗███████╗ ██████╗██╗   ██╗      ██████╗ ██████╗  ██████╗ 
# ██╔══██╗██║██╔════╝██╔════╝██║   ██║      ██╔══██╗██╔══██╗██╔════╝ 
# ██████╔╝██║███████╗██║     ██║   ██║█████╗██║  ██║██████╔╝██║  ███╗
# ██╔══██╗██║╚════██║██║     ╚██╗ ██╔╝╚════╝██║  ██║██╔══██╗██║   ██║
# ██║  ██║██║███████║╚██████╗ ╚████╔╝       ██████╔╝██████╔╝╚██████╔╝
# ╚═╝  ╚═╝╚═╝╚══════╝ ╚═════╝  ╚═══╝        ╚═════╝ ╚═════╝  ╚═════╝ 

## NOTE: DMI TAP PATCHED FOR FPGA VERSION
set RT_SS_RISCV_DBG_SRC " \
  ${REPO_DIR}/ips/riscv-dbg/src/dm_pkg.sv \
  ${REPO_DIR}/ips/riscv-dbg/src/dm_csrs.sv \
  ${REPO_DIR}/ips/riscv-dbg/src/dm_sba.sv \
  ${REPO_DIR}/ips/riscv-dbg/src/dm_mem.sv \
  ${REPO_DIR}/ips/riscv-dbg/src/dmi_cdc.sv \
  ${REPO_DIR}/src/ip/dmi_jtag_tap.sv \ 
  ${REPO_DIR}/ips/riscv-dbg/src/dmi_jtag.sv \
  ${REPO_DIR}/ips/riscv-dbg/src/dm_top.sv \
  ${REPO_DIR}/ips/riscv-dbg/debug_rom/debug_rom_one_scratch.sv \
  ${REPO_DIR}/ips/riscv-dbg/debug_rom/debug_rom.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_RISCV_DBG_SRC};

#  ██████╗ ██████╗ ███╗   ███╗███╗   ███╗ ██████╗ ███╗   ██╗     ██████╗███████╗██╗     ██╗     ███████╗
# ██╔════╝██╔═══██╗████╗ ████║████╗ ████║██╔═══██╗████╗  ██║    ██╔════╝██╔════╝██║     ██║     ██╔════╝
# ██║     ██║   ██║██╔████╔██║██╔████╔██║██║   ██║██╔██╗ ██║    ██║     █████╗  ██║     ██║     ███████╗
# ██║     ██║   ██║██║╚██╔╝██║██║╚██╔╝██║██║   ██║██║╚██╗██║    ██║     ██╔══╝  ██║     ██║     ╚════██║
# ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║    ╚██████╗███████╗███████╗███████╗███████║
#  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝     ╚═════╝╚══════╝╚══════╝╚══════╝╚══════╝

set RT_SS_COMMON_CELLS_SRC " \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/cf_math_pkg.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/lzc.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/rr_arb_tree.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/spill_register_flushable.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/spill_register.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/addr_decode.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/delta_counter.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/counter.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/cdc_2phase.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/sync.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/fifo_v3.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/deprecated/fifo_v2.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/stream_arbiter.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/stream_arbiter_flushable.sv \
"

add_files -norecurse -scan_for_includes ${RT_SS_COMMON_CELLS_SRC};

#  █████╗ ██╗  ██╗██╗
# ██╔══██╗╚██╗██╔╝██║
# ███████║ ╚███╔╝ ██║
# ██╔══██║ ██╔██╗ ██║
# ██║  ██║██╔╝ ██╗██║
# ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝

set RT_SS_AXI_SRC " \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_pkg.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_lite_demux.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_lite_mux.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_lite_to_apb.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/onehot_to_bin.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/pulp-common-cells/src/fall_through_register.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_lite_join.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_lite_to_axi.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_err_slv.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_intf.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/axi/src/axi_lite_xbar.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_AXI_SRC};

# ████████╗███████╗ ██████╗██╗  ██╗     ██████╗███████╗██╗     ██╗     ███████╗     ██████╗ ███████╗███╗   ██╗███████╗██████╗ ██╗ ██████╗
# ╚══██╔══╝██╔════╝██╔════╝██║  ██║    ██╔════╝██╔════╝██║     ██║     ██╔════╝    ██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔══██╗██║██╔════╝
#    ██║   █████╗  ██║     ███████║    ██║     █████╗  ██║     ██║     ███████╗    ██║  ███╗█████╗  ██╔██╗ ██║█████╗  ██████╔╝██║██║     
#    ██║   ██╔══╝  ██║     ██╔══██║    ██║     ██╔══╝  ██║     ██║     ╚════██║    ██║   ██║██╔══╝  ██║╚██╗██║██╔══╝  ██╔══██╗██║██║     
#    ██║   ███████╗╚██████╗██║  ██║    ╚██████╗███████╗███████╗███████╗███████║    ╚██████╔╝███████╗██║ ╚████║███████╗██║  ██║██║╚██████╗
#    ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝     ╚═════╝╚══════╝╚══════╝╚══════╝╚══════╝     ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝ ╚═════╝

set RT_SS_TECH_CELLS_GENERIC_SRC " \
  ${REPO_DIR}/ips/bow-common-ips/ips/tech_cells_generic/src/rtl/tc_clk.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/tech_cells_generic/src/deprecated/pulp_clk_cells.sv \
  ${REPO_DIR}/ips/bow-common-ips/ips/tech_cells_generic/src/deprecated/cluster_clk_cells.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_TECH_CELLS_GENERIC_SRC}

# ██╗   ██╗ █████╗ ██████╗ ████████╗
# ██║   ██║██╔══██╗██╔══██╗╚══██╔══╝
# ██║   ██║███████║██████╔╝   ██║   
# ██║   ██║██╔══██║██╔══██╗   ██║   
# ╚██████╔╝██║  ██║██║  ██║   ██║   
#  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   

set RT_SS_UART_SRC " \
  ${REPO_DIR}/ips/apb_uart/src/slib_input_sync.sv \
  ${REPO_DIR}/ips/apb_uart/src/slib_input_filter.sv \
  ${REPO_DIR}/ips/apb_uart/src/slib_clock_div.sv \
  ${REPO_DIR}/ips/apb_uart/src/slib_counter.sv \
  ${REPO_DIR}/ips/apb_uart/src/slib_mv_filter.sv \
  ${REPO_DIR}/ips/apb_uart/src/slib_fifo.sv \
  ${REPO_DIR}/ips/apb_uart/src/uart_baudgen.sv \
  ${REPO_DIR}/ips/apb_uart/src/uart_interrupt.sv \
  ${REPO_DIR}/ips/apb_uart/src/uart_transmitter.sv \
  ${REPO_DIR}/ips/apb_uart/src/uart_receiver.sv \
  ${REPO_DIR}/ips/apb_uart/src/slib_edge_detect.sv \
  ${REPO_DIR}/ips/apb_uart/src/apb_uart.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_UART_SRC}

#  ██████╗██╗     ██╗ ██████╗
# ██╔════╝██║     ██║██╔════╝
# ██║     ██║     ██║██║     
# ██║     ██║     ██║██║     
# ╚██████╗███████╗██║╚██████╗
#  ╚═════╝╚══════╝╚═╝ ╚═════╝

set RT_SS_CLIC_SRC " \
  ${REPO_DIR}/ips/register_interface/src/reg_intf.sv \
  ${REPO_DIR}/ips/register_interface/src/axi_lite_to_reg.sv \
  ${REPO_DIR}/ips/register_interface/vendor/lowrisc_opentitan/src/prim_subreg.sv \
  ${REPO_DIR}/ips/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv \
  ${REPO_DIR}/ips/clic/src/clicint_reg_pkg.sv \
  ${REPO_DIR}/ips/clic/src/clicint_reg_top.sv \
  ${REPO_DIR}/ips/clic/src/mclic_reg_pkg.sv \
  ${REPO_DIR}/ips/clic/src/clic_reg_adapter.sv \
  ${REPO_DIR}/ips/clic/src/mclic_reg_top.sv \
  ${REPO_DIR}/ips/clic/src/clic_gateway.sv \
  ${REPO_DIR}/ips/clic/src/clic_target.sv \
  ${REPO_DIR}/ips/register_interface/src/axi_lite_to_reg.sv \
  ${REPO_DIR}/ips/clic/src/clic.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_CLIC_SRC};

# ██████╗ ████████╗   ███████╗███████╗
# ██╔══██╗╚══██╔══╝   ██╔════╝██╔════╝
# ██████╔╝   ██║█████╗███████╗███████╗
# ██╔══██╗   ██║╚════╝╚════██║╚════██║
# ██║  ██║   ██║      ███████║███████║
# ╚═╝  ╚═╝   ╚═╝      ╚══════╝╚══════╝

set RT_SS_RTL_SRC " \
  ${REPO_DIR}/src/ip/timer_core.sv \
  ${REPO_DIR}/src/ip/rt_timer.sv \
  ${REPO_DIR}/src/ip/ibex_axi_bridge.sv \
  ${REPO_DIR}/src/ip/mem_axi_bridge.sv \
  ${REPO_DIR}/src/ip/rt_debug.sv \
  ${REPO_DIR}/src/ip/rt_ibex_bootrom.sv \  
  ${REPO_DIR}/src/ip/rt_gpio.sv \
  ${REPO_DIR}/src/ip/rt_cpu.sv \
  ${REPO_DIR}/src/ip/rt_mem.sv \
  ${REPO_DIR}/src/ip/rt_handshake_fsm.sv \
  ${REPO_DIR}/src/ip/rt_mem_mux_threeway.sv \
  ${REPO_DIR}/src/ip/rt_mem_mux.sv \
  ${REPO_DIR}/src/ip/rt_dpmem.sv \
  ${REPO_DIR}/src/ip/rt_register_interface.sv \
  ${REPO_DIR}/src/ip/rt_mem_axi_intf.sv \
  ${REPO_DIR}/src/ip/rt_top.sv \
  ${REPO_DIR}/src/ip/rt_clic_axi.sv \
  ${REPO_DIR}/src/ip/rt_irq.sv \
  ${REPO_DIR}/src/ip/rt_peripherals.sv \
  ${REPO_DIR}/src/ip/sram.sv \
  ${REPO_DIR}/src/ip/dp_sram.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_RTL_SRC};

# ███████╗██████╗  ██████╗  █████╗     ██████╗ ████████╗██╗     
# ██╔════╝██╔══██╗██╔════╝ ██╔══██╗    ██╔══██╗╚══██╔══╝██║     
# █████╗  ██████╔╝██║  ███╗███████║    ██████╔╝   ██║   ██║     
# ██╔══╝  ██╔═══╝ ██║   ██║██╔══██║    ██╔══██╗   ██║   ██║     
# ██║     ██║     ╚██████╔╝██║  ██║    ██║  ██║   ██║   ███████╗
# ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝   ╚═╝   ╚══════╝
                                                              
set RT_SS_FPGA_RTL_SRC " \
  ${REPO_DIR}/fpga/hdl/src/xilinx_sp_BRAM.sv \
  ${REPO_DIR}/fpga/hdl/src/xilinx_dp_BRAM.sv \
  ${REPO_DIR}/fpga/hdl/src/rt_top_fpga_wrapper_${FPGA_BOARD}.sv \
  ${REPO_DIR}/fpga/hdl/src/prim_clock_gating.sv \
";

add_files -norecurse -scan_for_includes ${RT_SS_FPGA_RTL_SRC};

# ████████╗██████╗ 
# ╚══██╔══╝██╔══██╗
#    ██║   ██████╔╝
#    ██║   ██╔══██╗
#    ██║   ██████╔╝
#    ╚═╝   ╚═════╝ 

set RT_SS_TB_SRC " \
  ${REPO_DIR}/fpga/hdl/tb/tb_rt_ss_jtag_fpga.sv \
  ${REPO_DIR}/src/tb/rt_jtag_pkg.sv \
  ${REPO_DIR}/src/tb/riscv_pkg.sv \
";

add_files -norecurse -scan_for_includes -fileset [current_fileset -simset] ${RT_SS_TB_SRC};

puts "\n---------------------------------------------------------";
puts "RT-SS_fpga_src_files.tcl - Complete!";
puts "---------------------------------------------------------\n";

# ------------------------------------------------------------------------------
# End of Script
# ------------------------------------------------------------------------------
