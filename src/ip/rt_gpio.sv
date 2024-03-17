module rt_gpio
#(
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter int unsigned AXI_ADDR_WIDTH = 32
)(

  input  logic        clk_i,
  input  logic        rst_ni,
  output logic        fetch_enable_o,
  output logic        cpu_rst_o,
  output logic [23:0] cpu_boot_addr_o,
  output logic [ 3:0] gpio_output_o,
  input  logic [ 3:0] gpio_input_i,
  AXI_LITE.Slave     axi_lite_s
);

logic                          we;
logic [    AXI_ADDR_WIDTH-1:0] addr;
logic [    AXI_DATA_WIDTH-1:0] wdata;
logic [(AXI_DATA_WIDTH/8)-1:0] be;
logic [    AXI_DATA_WIDTH-1:0] rdata;

mem_axi_bridge #(
  .MEM_AW     ( AXI_ADDR_WIDTH        ),
  .MEM_DW     ( AXI_DATA_WIDTH        ),
  .AXI_AW     ( AXI_ADDR_WIDTH        ),
  .AXI_DW     ( AXI_DATA_WIDTH        )
) i_mem_axi_bridge (
  .clk_i      ( clk_i                 ),
  .rst_ni     ( rst_ni                ),
  // memory side
  .req_o      ( /*NC*/                ),
  .we_o       ( we                    ),
  .addr_o     ( addr                  ),
  .wdata_o    ( wdata                 ),
  .be_o       ( be                    ),
  .rdata_i    ( rdata                 ),
  // AXI side
  .aw_addr_i  ( axi_lite_s.aw_addr    ),
  .aw_valid_i ( axi_lite_s.aw_valid   ),
  .aw_ready_o ( axi_lite_s.aw_ready   ),
  .w_data_i   ( axi_lite_s.w_data     ),
  .w_strb_i   ( axi_lite_s.w_strb     ),
  .w_valid_i  ( axi_lite_s.w_valid    ),
  .w_ready_o  ( axi_lite_s.w_ready    ),
  .b_resp_o   ( axi_lite_s.b_resp     ),
  .b_valid_o  ( axi_lite_s.b_valid    ),
  .b_ready_i  ( axi_lite_s.b_ready    ),
  .ar_addr_i  ( axi_lite_s.ar_addr    ),
  .ar_valid_i ( axi_lite_s.ar_valid   ),
  .ar_ready_o ( axi_lite_s.ar_ready   ),
  .r_data_o   ( axi_lite_s.r_data     ),
  .r_resp_o   ( axi_lite_s.r_resp     ),
  .r_valid_o  ( axi_lite_s.r_valid    ),
  .r_ready_i  ( axi_lite_s.r_ready    )
);
rt_register_interface #() i_reg_if (
  .clk_i          ( clk_i                 ),
  .rst_ni         ( rst_ni                ),
  .addr_i         ( addr[4:2]             ),
  .wdata_i        ( wdata                 ),
  .rdata_o        ( rdata                 ),
  .write_enable_i ( we                    ),
  .fetch_enable_o ( fetch_enable_o        ),
  .cpu_rst_o      ( cpu_rst_o             ),
  .cpu_boot_addr_o( cpu_boot_addr_o       ),
  .gpio_input_i   ( gpio_input_i          ),
  .gpio_output_o  ( gpio_output_o         )
);

endmodule
