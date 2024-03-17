module rt_uart_wrapper #()(
    input  logic     clk_i,
    input  logic     rst_ni,
    AXI_LITE.Slave   slv,
    output logic     event_o,
    input  logic     uart_rx_i,
    output logic     uart_tx_o
);

localparam int unsigned NR_ADDRS = 1;

localparam axi_pkg::xbar_rule_32_t [NR_ADDRS-1:0] AddrMap  = '{
    //'{idx: 32'd1, start_addr: 32'h0000_0004, end_addr: 32'h0000_0008}, // TX?
    '{idx: 32'd0, start_addr: 32'h0000_0000, end_addr: 32'h0000_0004} // RX?
};

logic [31:0] paddr;
logic [31:0] pwdata;
logic [31:0] prdata;
logic        pwrite;
logic        psel;
logic        penable;
logic        pready;
logic        pslverr;

axi_lite_to_apb_intf #(
    .NoApbSlaves        (                   32'd1 ),  // Number of connected APB slaves
    .NoRules            (           32'(NR_ADDRS) ),  // Number of APB address rules
    .AddrWidth          (                   32'd32), // Address width
    .DataWidth          (                   32'd32), // Data width
    .PipelineRequest    (                       0 ),   // Pipeline request path
    .PipelineResponse   (                       0 ),   // Pipeline response path
    .rule_t             ( axi_pkg::xbar_rule_32_t )  // Address Decoder rule from `common_cells`
) i_axi2abp (
    .clk_i       ( clk_i   ),     
    .rst_ni      ( rst_ni  ),    
    .slv         ( slv     ),
    .paddr_o     ( paddr   ),
    .pprot_o     ( /*NC*/  ),
    .pselx_o     ( psel    ),
    .penable_o   ( penable ),
    .pwrite_o    ( pwrite  ),
    .pwdata_o    ( pwdata  ),
    .pstrb_o     ( /*NC*/  ),
    .pready_i    ( pready  ),
    .prdata_i    ( prdata  ),
    .pslverr_i   ( pslverr ),
    // APB Slave Address Map
    .addr_map_i  ( AddrMap )
);

apb_uart i_apb_uart (
    .CLK      ( clk_i       ),
    .RSTN     ( rst_ni      ),
    // APB
    .PSEL     ( psel        ),
    .PENABLE  ( penable     ),
    .PWRITE   ( pwrite      ),
    .PADDR    ( paddr[4:2]  ),
    .PWDATA   ( pwdata      ),
    .PRDATA   ( prdata      ),
    .PREADY   ( pready      ),
    .PSLVERR  ( pslverr     ),
    .INT      ( event_o     ),
    .OUT1N    ( /*NC*/      ),
    .OUT2N    ( /*NC*/      ),
    .RTSN     ( /*NC*/      ),
    .DTRN     ( /*NC*/      ),
    .CTSN     ( 1'b0        ),
    .DSRN     ( 1'b0        ),
    .DCDN     ( 1'b0        ),
    .RIN      ( 1'b0        ),
    .SIN      ( uart_rx_i   ), //RX
    .SOUT     ( uart_tx_o   )  //TX
);

endmodule : rt_uart_wrapper