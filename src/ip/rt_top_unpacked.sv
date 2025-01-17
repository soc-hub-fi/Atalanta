/*
  Interface unwrapper for Atalanta/rt-ss, required by Verilator
  authors: Antti Nurmi <antti.nurmi@tuni.fi>
*/

`include "axi/assign.svh"
`define COMMON_CELLS_ASSERTS_OFF

module rt_top_unpacked #(
  parameter int unsigned AxiAddrWidth   = 32,
  parameter int unsigned AxiDataWidth   = 32,
  parameter int unsigned ClicIrqSrcs    = 64,
  parameter bit          IbexRve        = 1,
  parameter bit          JtagLoad       = 1,
  localparam int SrcW = $clog2(ClicIrqSrcs),
  localparam int unsigned AxiStrbWidth = AxiDataWidth / 8,
  parameter int unsigned AxiIdWidth   = 9,
  parameter int unsigned AxiUserWidth = 1
)(
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [3:0]         gpio_input_i,
  output logic [3:0]         gpio_output_o,
  input  logic               uart_rx_i,
  output logic               uart_tx_o,

  output logic [AxiAddrWidth-1:0] axim_aw_addr_o,
  output logic              [2:0] axim_aw_prot_o,
  output logic              [5:0] axim_aw_atop_o,
  output logic              [1:0] axim_aw_burst_o,
  output logic              [3:0] axim_aw_cache_o,
  output logic                    axim_aw_valid_o,
  input  logic                    axim_aw_ready_i,
  output logic                    axim_aw_lock_o,
  output logic              [3:0] axim_aw_qos_o,
  output logic              [3:0] axim_aw_region_o,
  output logic [  AxiIdWidth-1:0] axim_aw_id_o,
  output logic              [7:0] axim_aw_len_o,
  output logic              [2:0] axim_aw_size_o,
  output logic [AxiUserWidth-1:0] axim_aw_user_o,
  output logic [AxiDataWidth-1:0] axim_w_data_o,
  output logic [AxiStrbWidth-1:0] axim_w_strb_o,
  output logic                    axim_w_valid_o,
  input  logic                    axim_w_ready_i,
  output logic                    axim_w_last_o,
  output logic [AxiUserWidth-1:0] axim_w_user_o,
  input  logic              [1:0] axim_b_resp_i,
  input  logic [  AxiIdWidth-1:0] axim_b_id_i,
  input  logic [AxiUserWidth-1:0] axim_b_user_i,
  input  logic                    axim_b_valid_i,
  output logic                    axim_b_ready_o,
  output logic [AxiAddrWidth-1:0] axim_ar_addr_o,
  output logic              [2:0] axim_ar_prot_o,
  output logic [  AxiIdWidth-1:0] axim_ar_id_o,
  output logic              [7:0] axim_ar_len_o,
  output logic              [1:0] axim_ar_burst_o,
  output logic              [3:0] axim_ar_cache_o,
  output logic              [3:0] axim_ar_qos_o,
  output logic              [3:0] axim_ar_region_o,
  output logic              [2:0] axim_ar_size_o,
  output logic                    axim_ar_valid_o,
  output logic                    axim_ar_lock_o,
  output logic [AxiUserWidth-1:0] axim_ar_user_o,
  input  logic                    axim_ar_ready_i,
  input  logic [AxiDataWidth-1:0] axim_r_data_i,
  input  logic              [1:0] axim_r_resp_i,
  input  logic [  AxiIdWidth-1:0] axim_r_id_i,
  input  logic [AxiUserWidth-1:0] axim_r_user_i,
  input  logic                    axim_r_valid_i,
  input  logic                    axim_r_last_i,
  output logic                    axim_r_ready_o,

  input  logic [AxiAddrWidth-1:0] axis_aw_addr_i,
  input  logic              [2:0] axis_aw_prot_i,
  input  logic                    axis_aw_valid_i,
  output logic                    axis_aw_ready_o,
  input  logic              [5:0] axis_aw_atop_i,
  input  logic              [1:0] axis_aw_burst_i,
  input  logic              [3:0] axis_aw_cache_i,
  input  logic              [7:0] axis_aw_len_i,
  input  logic                    axis_aw_lock_i,
  input  logic [  AxiIdWidth-1:0] axis_aw_id_i,
  input  logic              [3:0] axis_aw_qos_i,
  input  logic              [3:0] axis_aw_region_i,
  input  logic              [2:0] axis_aw_size_i,
  input  logic [AxiUserWidth-1:0] axis_aw_user_i,
  input  logic [AxiDataWidth-1:0] axis_w_data_i,
  input  logic [AxiStrbWidth-1:0] axis_w_strb_i,
  input  logic                    axis_w_valid_i,
  output logic                    axis_w_ready_o,
  input  logic                    axis_w_last_i,
  input  logic [AxiUserWidth-1:0] axis_w_user_i,
  output logic              [1:0] axis_b_resp_o,
  output logic                    axis_b_valid_o,
  input  logic                    axis_b_ready_i,
  output logic [  AxiIdWidth-1:0] axis_b_id_o,
  output logic [AxiUserWidth-1:0] axis_b_user_o,
  input  logic [AxiAddrWidth-1:0] axis_ar_addr_i,
  input  logic              [2:0] axis_ar_prot_i,
  input  logic                    axis_ar_valid_i,
  output logic                    axis_ar_ready_o,
  input  logic [  AxiIdWidth-1:0] axis_ar_id_i,
  input  logic              [7:0] axis_ar_len_i,
  input  logic                    axis_ar_lock_i,
  input  logic              [1:0] axis_ar_burst_i,
  input  logic              [3:0] axis_ar_cache_i,
  input  logic              [3:0] axis_ar_qos_i,
  input  logic              [3:0] axis_ar_region_i,
  input  logic [AxiUserWidth-1:0] axis_ar_user_i,
  input  logic              [2:0] axis_ar_size_i,
  output logic [AxiDataWidth-1:0] axis_r_data_o,
  output logic              [1:0] axis_r_resp_o,
  output logic                    axis_r_valid_o,
  input  logic                    axis_r_ready_i,
  output logic [  AxiIdWidth-1:0] axis_r_id_o,
  output logic                    axis_r_last_o,
  output logic [AxiUserWidth-1:0] axis_r_user_o,

  input  logic                    jtag_tck_i,
  input  logic                    jtag_tms_i,
  input  logic                    jtag_trst_ni,
  input  logic                    jtag_td_i,
  output logic                    jtag_td_o,

  input  logic                    intr_src_i
);

logic [ClicIrqSrcs-1:0] irqs;

AXI_BUS #(
  .AXI_ADDR_WIDTH (AxiAddrWidth),
  .AXI_DATA_WIDTH (AxiDataWidth),
  .AXI_ID_WIDTH   (AxiIdWidth),
  .AXI_USER_WIDTH (AxiUserWidth)
) axim_bus (), axis_bus ();


assign axim_aw_addr_o     = axim_bus.aw_addr;
assign axim_aw_prot_o     = axim_bus.aw_prot;
assign axim_aw_atop_o     = axim_bus.aw_atop;
assign axim_aw_burst_o    = axim_bus.aw_burst;
assign axim_aw_cache_o    = axim_bus.aw_cache;
assign axim_aw_valid_o    = axim_bus.aw_valid;
assign axim_bus.aw_ready  = axim_aw_ready_i;
assign axim_aw_lock_o     = axim_bus.aw_lock;
assign axim_aw_qos_o      = axim_bus.aw_qos;
assign axim_aw_region_o   = axim_bus.aw_region;
assign axim_aw_id_o       = axim_bus.aw_id;
assign axim_aw_len_o      = axim_bus.aw_len;
assign axim_aw_size_o     = axim_bus.aw_size;
assign axim_aw_user_o     = axim_bus.aw_user;
assign axim_w_data_o      = axim_bus.w_data;
assign axim_w_strb_o      = axim_bus.w_strb;
assign axim_w_valid_o     = axim_bus.w_valid;
assign axim_bus.w_ready   = axim_w_ready_i;
assign axim_w_last_o      = axim_bus.w_last;
assign axim_w_user_o      = axim_bus.w_user;
assign axim_bus.b_resp    = axim_b_resp_i;
assign axim_bus.b_id      = axim_b_id_i;
assign axim_bus.b_user    = axim_b_user_i;
assign axim_bus.b_valid   = axim_b_valid_i;
assign axim_b_ready_o     = axim_bus.b_ready;
assign axim_ar_addr_o     = axim_bus.ar_addr;
assign axim_ar_prot_o     = axim_bus.ar_prot;
assign axim_ar_id_o       = axim_bus.ar_id;
assign axim_ar_len_o      = axim_bus.ar_len;
assign axim_ar_burst_o    = axim_bus.ar_burst;
assign axim_ar_cache_o    = axim_bus.ar_cache;
assign axim_ar_qos_o      = axim_bus.ar_qos;
assign axim_ar_region_o   = axim_bus.ar_region;
assign axim_ar_size_o     = axim_bus.ar_size;
assign axim_ar_valid_o    = axim_bus.ar_valid;
assign axim_ar_lock_o     = axim_bus.ar_lock;
assign axim_ar_user_o     = axim_bus.ar_user;
assign axim_bus.ar_ready  = axim_ar_ready_i;
assign axim_bus.r_data    = axim_r_data_i;
assign axim_bus.r_resp    = axim_r_resp_i;
assign axim_bus.r_id      = axim_r_id_i;
assign axim_bus.r_user    = axim_r_user_i;
assign axim_bus.r_valid   = axim_r_valid_i;
assign axim_bus.r_last    = axim_r_last_i;
assign axim_r_ready_o     = axim_bus.r_ready;

assign axis_bus.aw_addr   = axis_aw_addr_i;
assign axis_bus.aw_prot   = axis_aw_prot_i;
assign axis_bus.aw_valid  = axis_aw_valid_i;
assign axis_aw_ready_o    = axis_bus.aw_ready;
assign axis_bus.aw_atop   = axis_aw_atop_i;
assign axis_bus.aw_burst  = axis_aw_burst_i;
assign axis_bus.aw_cache  = axis_aw_cache_i;
assign axis_bus.aw_len    = axis_aw_len_i;
assign axis_bus.aw_lock   = axis_aw_lock_i;
assign axis_bus.aw_id     = axis_aw_id_i;
assign axis_bus.aw_qos    = axis_aw_qos_i;
assign axis_bus.aw_region = axis_aw_region_i;
assign axis_bus.aw_size   = axis_aw_size_i;
assign axis_bus.aw_user   = axis_aw_user_i;
assign axis_bus.w_data    = axis_w_data_i;
assign axis_bus.w_strb    = axis_w_strb_i;
assign axis_bus.w_valid   = axis_w_valid_i;
assign axis_w_ready_o     = axis_bus.w_ready;
assign axis_bus.w_last    = axis_w_last_i;
assign axis_bus.w_user    = axis_w_user_i;
assign axis_b_resp_o      = axis_bus.b_resp;
assign axis_b_valid_o     = axis_bus.b_valid;
assign axis_bus.b_ready   = axis_b_ready_i;
assign axis_b_id_o        = axis_bus.b_id;
assign axis_b_user_o      = axis_bus.b_user;
assign axis_bus.ar_addr   = axis_ar_addr_i;
assign axis_bus.ar_prot   = axis_ar_prot_i;
assign axis_bus.ar_valid  = axis_ar_valid_i;
assign axis_ar_ready_o    = axis_bus.ar_ready;
assign axis_bus.ar_id     = axis_ar_id_i;
assign axis_bus.ar_len    = axis_ar_len_i;
assign axis_bus.ar_lock   = axis_ar_lock_i;
assign axis_bus.ar_burst  = axis_ar_burst_i;
assign axis_bus.ar_cache  = axis_ar_cache_i;
assign axis_bus.ar_qos    = axis_ar_qos_i;
assign axis_bus.ar_region = axis_ar_region_i;
assign axis_bus.ar_user   = axis_ar_user_i;
assign axis_bus.ar_size   = axis_ar_size_i;
assign axis_r_data_o      = axis_bus.r_data;
assign axis_r_resp_o      = axis_bus.r_resp;
assign axis_r_valid_o     = axis_bus.r_valid;
assign axis_bus.r_ready   = axis_r_ready_i;
assign axis_r_id_o        = axis_bus.r_id;
assign axis_r_last_o      = axis_bus.r_last;
assign axis_r_user_o      = axis_bus.r_user;

rt_top #(
  .AxiAddrWidth (AxiAddrWidth),
  .AxiDataWidth (AxiDataWidth),
  .ClicIrqSrcs  (ClicIrqSrcs)
) i_rt_top (
  .clk_i,
  .rst_ni,
  .soc_slv       (axis_bus),
  .soc_mst       (axim_bus),
  .jtag_tck_i,
  .jtag_tms_i,
  .jtag_trst_ni,
  .jtag_td_i,
  .jtag_td_o,
  .gpio_input_i,
  .gpio_output_o,
  .uart_rx_i,
  .uart_tx_o,
  .intr_src_i
);

`ifndef SYNTHESIS
// TODO: Add passive VIPs here

initial begin
  // TODO: Add memory preload
  if(!JtagLoad) begin
    @(posedge rst_ni);
    $display("IN READMEM MODE");
    $readmemh("../../stims/mem_init.hex", i_rt_top.i_core.i_imem.i_sram.sram);
    $readmemh("../../stims/mem_init.hex", i_rt_top.i_core.i_dmem.i_sram.sram);
    //$readmemh();
  end
end
`endif

endmodule : rt_top_unpacked
