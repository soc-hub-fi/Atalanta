module rt_mem #(
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned MEM_WORD_SIZE  = 1024,
		parameter int unsigned BASE_OFFSET    = 2048
)(
    input logic     clk_i,
    input logic     rst_ni,
    AXI_LITE.Slave  axi_lite_s 
);



logic        	  	             req;
logic      	  	               we;
logic [    AXI_ADDR_WIDTH-1:0] addr;
logic [    AXI_DATA_WIDTH-1:0] wdata;
logic [(AXI_DATA_WIDTH/8)-1:0] be;
logic [    AXI_DATA_WIDTH-1:0] rdata;
logic [    AXI_ADDR_WIDTH-1:0] sram_addr;

mem_axi_bridge #(
    .MEM_AW     ( AXI_ADDR_WIDTH        ),
    .MEM_DW     ( AXI_DATA_WIDTH        ),
    .AXI_AW     ( AXI_ADDR_WIDTH        ),
    .AXI_DW     ( AXI_DATA_WIDTH        )
) i_mem_bridge (
    .clk_i      ( clk_i                 ),
    .rst_ni     ( rst_ni                ),
    // memory side
    .req_o      ( req                   ),
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

sram #(
  .DATA_WIDTH   ( AXI_DATA_WIDTH        ),
  .NUM_WORDS    ( MEM_WORD_SIZE         )
) i_mem (
  .clk_i        ( clk_i    	                               ),
  .rst_ni       ( rst_ni   	                               ),
  .req_i        ( req                                      ),
  .we_i         ( we                                       ),
  .addr_i       ( sram_addr[($clog2(MEM_WORD_SIZE)-1)+2:2] ),
  .wdata_i      ( wdata    	                               ),
  .be_i         ( be       	                               ),
  .rdata_o      ( rdata    	                               )
);

assign sram_addr = addr - BASE_OFFSET;

endmodule 
