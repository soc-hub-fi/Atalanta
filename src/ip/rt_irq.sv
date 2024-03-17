module rt_irq #(
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned AxiDataWidth = 32,
  parameter int          NSource       = 256,
  parameter int          IntCtlBits     = 8,
  localparam int SrcW = $clog2(NSource)
)(
  input  logic             clk_i,
  input  logic             rst_ni,
  AXI_LITE.Slave           axi_s,
  input [NSource-1:0]     intr_src_i,
  output logic             irq_valid_o,
  input  logic             irq_ready_i,
  output logic [SrcW-1:0] irq_id_o,
  output logic [7:0]       irq_level_o,
  output logic             irq_shv_o,
  output logic [1:0]       irq_priv_o,
  output logic             irq_kill_req_o,
  input  logic             irq_kill_ack_i
);

rt_clic_axi #(
  .AxiAddrWidth ( AxiAddrWidth ),
  .AxiDataWidth ( AxiDataWidth ),
  .NSource       ( NSource       ),
  .IntCtlBits     ( IntCtlBits     )
) i_clic (
  .clk_i          ( clk_i          ),
  .rst_ni         ( rst_ni         ),
  .axi_s          ( axi_s          ),
  .intr_src_i     ( intr_src_i     ), // 0-31 -> CLINT IRQS
  .irq_valid_o    ( irq_valid_o    ),
  .irq_ready_i    ( irq_ready_i    ),
  .irq_id_o       ( irq_id_o       ),
  .irq_level_o    ( irq_level_o    ),
  .irq_shv_o      ( irq_shv_o      ),
  .irq_priv_o     ( irq_priv_o     ),
  .irq_kill_req_o ( irq_kill_req_o ),
  .irq_kill_ack_i ( irq_kill_ack_i )
);

endmodule : rt_irq
