module rt_cpu #(
    parameter int unsigned AxiAddrWidth = 32,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned MemSize      = 1024,
    parameter bit          IbexRve       = 0,
    parameter int unsigned NumInterrupts = 64,
    localparam int         SrcW          = $clog2(NumInterrupts)
)(
    input logic             clk_i,
    input logic             rst_ni,
    input logic [31:0]      hart_id_i,
    input logic [31:0]      boot_addr_i,
    input logic             debug_req_i,
    input logic             fetch_enable_i,
    AXI_LITE.Slave          axi_mem_slv,
    AXI_LITE.Master         axi_dmem_m,
    AXI_LITE.Master         axi_imem_m,
    input  logic            irq_valid_i,
    output logic            irq_ready_o,
    input  logic [SrcW-1:0] irq_id_i,
    input  logic [     7:0] irq_level_i,
    input  logic            irq_shv_i,
    input  logic [     1:0] irq_priv_i
);

// TODO: move to pkg
typedef struct packed {
    logic                    req;
    logic                    gnt;
    logic                    vld;
    logic                    we;
    logic [             3:0] be;
    logic [AxiAddrWidth-1:0] addr;
    logic [AxiDataWidth-1:0] wdata;
    logic [AxiDataWidth-1:0] rdata;
} mem_t;

mem_t cpu_im_mux, cpu_dmem_mux;
mem_t axi_dmem, axi_imem;

mem_t mux_rom;
mem_t mux_imem;
mem_t mux_im_axi;

mem_t mux_axi;
mem_t mux_dmem;
// TODO: tie off unused signals

logic axi_mux_aw_sel, axi_mux_ar_sel, dmem_mux_sel;

logic [1:0] imem_mux_sel;

logic [NumInterrupts-1:0] core_irq_x;

AXI_LITE #(
  .AXI_ADDR_WIDTH ( AxiAddrWidth ),
  .AXI_DATA_WIDTH ( AxiDataWidth )
) mem_bus_m [1:0] ();

AXI_LITE #(
  .AXI_ADDR_WIDTH ( AxiAddrWidth ),
  .AXI_DATA_WIDTH ( AxiDataWidth )
) mem_bus_s [1:0] ();

axi_lite_demux_intf #(
  .AxiAddrWidth ( AxiAddrWidth ),
  .AxiDataWidth ( AxiDataWidth ),
  .NoMstPorts   ( 32'd2        ),
  .MaxTrans     ( 32'd1        ),
  .FallThrough  ( 1'b1         ),
  .SpillAw      ( 1'b0         ),
  .SpillW       ( 1'b0         ),
  .SpillB       ( 1'b0         ),
  .SpillAr      ( 1'b0         ),
  .SpillR       ( 1'b0         )
) i_mem_demux (
  .clk_i           ( clk_i      ),
  .rst_ni          ( rst_ni     ),
  .test_i          ( '0         ),
  .slv_aw_select_i ( axi_mux_aw_sel    ), // has to be stable, when aw_valid
  .slv_ar_select_i ( axi_mux_ar_sel    ), // has to be stable, when ar_valid
  .slv             ( axi_mem_slv),
  .mst             ( mem_bus_m  )
);

axi_lite_join_intf#() i_imem_join (
  .in ( mem_bus_m[0] ),
  .out( mem_bus_s[0] )
);

axi_lite_join_intf#() i_dmem_join (
  .in ( mem_bus_m[1] ),
  .out( mem_bus_s[1] )
);

rt_mem_axi_intf #(
  .MEM_AW     ( AxiAddrWidth ),
  .MEM_DW     ( AxiDataWidth ),
  .AXI_AW     ( AxiAddrWidth ),
  .AXI_DW     ( AxiDataWidth )
) i_axi_imem (
  .clk_i      ( clk_i          ),
  .rst_ni     ( rst_ni         ),
  // memory side
  .req_o      ( axi_imem.req   ),
  .we_o       ( axi_imem.we    ),
  .addr_o     ( axi_imem.addr  ),
  .wdata_o    ( axi_imem.wdata ),
  .be_o       ( axi_imem.be    ),
  .rdata_i    ( axi_imem.rdata ),
  // AXI side
  .axi_lite_s  ( mem_bus_s[0] )
);

rt_mem_axi_intf #(
    .MEM_AW     ( AxiAddrWidth ),
    .MEM_DW     ( AxiDataWidth ),
    .AXI_AW     ( AxiAddrWidth ),
    .AXI_DW     ( AxiDataWidth )
) i_axi_dmem (
    .clk_i      ( clk_i  ),
    .rst_ni     ( rst_ni ),
    // memory side
    .req_o      ( axi_dmem.req   ),
    .we_o       ( axi_dmem.we    ),
    .addr_o     ( axi_dmem.addr  ),
    .wdata_o    ( axi_dmem.wdata ),
    .be_o       ( axi_dmem.be    ),
    .rdata_i    ( axi_dmem.rdata ),
    // AXI side
    .axi_lite_s  ( mem_bus_s[1] )
);

rt_dpmem #(
  .AddrWidth  (AxiAddrWidth),
  .DataWidth  (AxiDataWidth),
  .MemSize    (MemSize),
  .BaseOffset (32'h1000)
) i_imem (
  .clk_i         (clk_i),
  .rst_ni        (rst_ni),
  // CPU side
  .cpu_req_i     (mux_imem.req),
  .cpu_gnt_o     (mux_imem.gnt),
  .cpu_rvalid_o  (mux_imem.vld),
  .cpu_we_i      (1'b0),
  .cpu_be_i      (4'b1111),
  .cpu_addr_i    (mux_imem.addr),
  .cpu_wdata_i   (32'b0),
  .cpu_rdata_o   (mux_imem.rdata),
  // AXI side
  .axi_req_i     ( axi_imem.req   ),
  .axi_we_i      ( axi_imem.we    ),
  .axi_be_i      ( axi_imem.be    ),
  .axi_addr_i    ( axi_imem.addr  ),
  .axi_wdata_i   ( axi_imem.wdata ),
  .axi_rdata_o   ( axi_imem.rdata )
);

rt_dpmem #(
  .AddrWidth  (AxiAddrWidth),
  .DataWidth  (AxiDataWidth),
  .MemSize    (MemSize),
  .BaseOffset (32'h2000)
) i_dmem (
  .clk_i         (clk_i),
  .rst_ni        (rst_ni),
  // CPU side
  .cpu_req_i     (mux_dmem.req),
  .cpu_gnt_o     (mux_dmem.gnt),
  .cpu_rvalid_o  (mux_dmem.vld),
  .cpu_we_i      (mux_dmem.we),
  .cpu_be_i      (mux_dmem.be),
  .cpu_addr_i    (mux_dmem.addr),
  .cpu_wdata_i   (mux_dmem.wdata),
  .cpu_rdata_o   (mux_dmem.rdata),
  // AXI side
  .axi_req_i     ( axi_dmem.req   ),
  .axi_we_i      ( axi_dmem.we    ),
  .axi_be_i      ( axi_dmem.be    ),
  .axi_addr_i    ( axi_dmem.addr  ),
  .axi_wdata_i   ( axi_dmem.wdata ),
  .axi_rdata_o   ( axi_dmem.rdata )
);

rt_mem_mux_threeway #(
  .AddrWidth (AxiAddrWidth),
  .DataWidth (AxiDataWidth)
) i_imem_mux (
  .clk_i     (clk_i),
  .rst_ni    (rst_ni),
  .select_i  (imem_mux_sel),
  // CPU side
  .cpu_req_i    (cpu_im_mux.req),
  .cpu_gnt_o    (cpu_im_mux.gnt),
  .cpu_rvalid_o (cpu_im_mux.vld),
  .cpu_we_i     (cpu_im_mux.we),
  .cpu_be_i     (cpu_im_mux.be),
  .cpu_addr_i   (cpu_im_mux.addr),
  .cpu_wdata_i  (cpu_im_mux.wdata),
  .cpu_rdata_o  (cpu_im_mux.rdata),
  // A side
  .a_req_o      (mux_imem.req),
  .a_gnt_i      (mux_imem.gnt),
  .a_rvalid_i   (mux_imem.vld),
  .a_we_o       (mux_imem.we),
  .a_be_o       (mux_imem.be),
  .a_addr_o     (mux_imem.addr),
  .a_wdata_o    (mux_imem.wdata),
  .a_rdata_i    (mux_imem.rdata),
  // B side
  .b_req_o      (mux_rom.req),
  .b_gnt_i      (mux_rom.gnt),
  .b_rvalid_i   (mux_rom.vld),
  .b_we_o       (mux_rom.we),
  .b_be_o       (mux_rom.be),
  .b_addr_o     (mux_rom.addr),
  .b_wdata_o    (mux_rom.wdata),
  .b_rdata_i    (mux_rom.rdata),
  //C side
  .c_req_o      (mux_im_axi.req),
  .c_gnt_i      (mux_im_axi.gnt),
  .c_rvalid_i   (mux_im_axi.vld),
  .c_we_o       (mux_im_axi.we),
  .c_be_o       (mux_im_axi.be),
  .c_addr_o     (mux_im_axi.addr),
  .c_wdata_o    (mux_im_axi.wdata),
  .c_rdata_i    (mux_im_axi.rdata)
);

rt_mem_mux #(
  .AddrWidth (AxiAddrWidth),
  .DataWidth (AxiDataWidth)
) d_imem_mux (
  .clk_i     (clk_i),
  .rst_ni    (rst_ni),
  .select_i  (dmem_mux_sel),
  // CPU side
  .cpu_req_i    (cpu_dmem_mux.req),
  .cpu_gnt_o    (cpu_dmem_mux.gnt),
  .cpu_rvalid_o (cpu_dmem_mux.vld),
  .cpu_we_i     (cpu_dmem_mux.we),
  .cpu_be_i     (cpu_dmem_mux.be),
  .cpu_addr_i   (cpu_dmem_mux.addr),
  .cpu_wdata_i  (cpu_dmem_mux.wdata),
  .cpu_rdata_o  (cpu_dmem_mux.rdata),
  // A side
  .a_req_o      (mux_dmem.req),
  .a_gnt_i      (mux_dmem.gnt),
  .a_rvalid_i   (mux_dmem.vld),
  .a_we_o       (mux_dmem.we),
  .a_be_o       (mux_dmem.be),
  .a_addr_o     (mux_dmem.addr),
  .a_wdata_o    (mux_dmem.wdata),
  .a_rdata_i    (mux_dmem.rdata),
  // B side
  .b_req_o      (mux_axi.req),
  .b_gnt_i      (mux_axi.gnt),
  .b_rvalid_i   (mux_axi.vld),
  .b_we_o       (mux_axi.we),
  .b_be_o       (mux_axi.be),
  .b_addr_o     (mux_axi.addr),
  .b_wdata_o    (mux_axi.wdata),
  .b_rdata_i    (mux_axi.rdata)
);


ibex_axi_bridge #(
    .AXI_AW ( AxiAddrWidth ),
    .AXI_DW ( AxiDataWidth ),
    .IBEX_AW( AxiAddrWidth ),
    .IBEX_DW( AxiDataWidth )
) i_dmem_bridge (
    .clk_i      ( clk_i               ),
    .rst_ni     ( rst_ni              ),
    .req_i      ( mux_axi.req         ),
    .gnt_o      ( mux_axi.gnt         ),
    .rvalid_o   ( mux_axi.vld      ),
    .we_i       ( mux_axi.we          ),
    .be_i       ( mux_axi.be          ),
    .addr_i     ( mux_axi.addr        ),
    .wdata_i    ( mux_axi.wdata       ),
    .rdata_o    ( mux_axi.rdata       ),
    .err_o      ( /* NC */            ),
    .aw_addr_o  ( axi_dmem_m.aw_addr  ),
    .aw_valid_o ( axi_dmem_m.aw_valid ),
    .aw_ready_i ( axi_dmem_m.aw_ready ),
    .w_data_o   ( axi_dmem_m.w_data   ),
    .w_strb_o   ( axi_dmem_m.w_strb   ),
    .w_valid_o  ( axi_dmem_m.w_valid  ),
    .w_ready_i  ( axi_dmem_m.w_ready  ),
    .b_resp_i   ( axi_dmem_m.b_resp   ),
    .b_valid_i  ( axi_dmem_m.b_valid  ),
    .b_ready_o  ( axi_dmem_m.b_ready  ),
    .ar_addr_o  ( axi_dmem_m.ar_addr  ),
    .ar_valid_o ( axi_dmem_m.ar_valid ),
    .ar_ready_i ( axi_dmem_m.ar_ready ),
    .r_data_i   ( axi_dmem_m.r_data   ),
    .r_resp_i   ( axi_dmem_m.r_resp   ),
    .r_valid_i  ( axi_dmem_m.r_valid  ),
    .r_ready_o  ( axi_dmem_m.r_ready  )
);

ibex_axi_bridge #(
    .AXI_AW ( AxiAddrWidth ),
    .AXI_DW ( AxiDataWidth ),
    .IBEX_AW( AxiAddrWidth ),
    .IBEX_DW( AxiDataWidth )
) i_imem_bridge (
    .clk_i      ( clk_i               ),
    .rst_ni     ( rst_ni              ),
    .req_i      ( mux_im_axi.req         ),
    .gnt_o      ( mux_im_axi.gnt         ),
    .rvalid_o   ( mux_im_axi.vld      ),
    .we_i       ( mux_im_axi.we          ),
    .be_i       ( mux_im_axi.be          ),
    .addr_i     ( mux_im_axi.addr        ),
    .wdata_i    ( mux_im_axi.wdata       ),
    .rdata_o    ( mux_im_axi.rdata       ),
    .err_o      ( /* NC */            ),
    .aw_addr_o  ( axi_imem_m.aw_addr  ),
    .aw_valid_o ( axi_imem_m.aw_valid ),
    .aw_ready_i ( axi_imem_m.aw_ready ),
    .w_data_o   ( axi_imem_m.w_data   ),
    .w_strb_o   ( axi_imem_m.w_strb   ),
    .w_valid_o  ( axi_imem_m.w_valid  ),
    .w_ready_i  ( axi_imem_m.w_ready  ),
    .b_resp_i   ( axi_imem_m.b_resp   ),
    .b_valid_i  ( axi_imem_m.b_valid  ),
    .b_ready_o  ( axi_imem_m.b_ready  ),
    .ar_addr_o  ( axi_imem_m.ar_addr  ),
    .ar_valid_o ( axi_imem_m.ar_valid ),
    .ar_ready_i ( axi_imem_m.ar_ready ),
    .r_data_i   ( axi_imem_m.r_data   ),
    .r_resp_i   ( axi_imem_m.r_resp   ),
    .r_valid_i  ( axi_imem_m.r_valid  ),
    .r_ready_o  ( axi_imem_m.r_ready  )
);


rt_ibex_bootrom #(
    .ADDR_WIDTH ( AxiAddrWidth ),
    .DATA_WIDTH ( AxiDataWidth )
) i_bootrom (
    .clk_i      ( clk_i     ),
    .rst_ni     ( rst_ni    ),
    .req_i      (mux_rom.req),
    .gnt_o      (mux_rom.gnt),
    .rvalid_o   (mux_rom.vld),
    .addr_i     (mux_rom.addr),
    .rdata_o    (mux_rom.rdata)
);


`ifdef DEBUG
ibex_top_tracing #(
`else
ibex_top #(
`endif
    .PMPEnable        ( 0                                ),
    .PMPGranularity   ( 0                                ),
    .PMPNumRegions    ( 4                                ),
    .MHPMCounterNum   ( 0                                ),
    .MHPMCounterWidth ( 40                               ),
    .RV32E            ( IbexRve                         ),
    .RV32M            ( ibex_pkg::RV32MFast              ),
    .RV32B            ( ibex_pkg::RV32BNone              ),
    .WritebackStage   ( 1'b0                             ),
`ifndef FPGA          // ASIC Implementation
    .RegFile          ( ibex_pkg::RegFileFF              ),
`else                 // FPGA Implementation
    .RegFile          ( ibex_pkg::RegFileFPGA            ),
`endif
    .ICache           ( 0                                ),
    .ICacheECC        ( 0                                ),
    .ICacheScramble   ( 0                                ),
    .BranchPredictor  ( 0                                ),
    .SecureIbex       ( 0                                ),
    .CLIC             ( 1                                ),
    .NUM_INTERRUPTS   ( NumInterrupts                   ),
    .RndCnstLfsrSeed  ( ibex_pkg::RndCnstLfsrSeedDefault ),
    .RndCnstLfsrPerm  ( ibex_pkg::RndCnstLfsrPermDefault ),
    .DbgTriggerEn     ( 0                                ),
    .DmHaltAddr       ( dm::HaltAddress                  ),
    .DmExceptionAddr  ( dm::ExceptionAddress             )
) i_cpu (
    // Clock and reset
    .clk_i                  ( clk_i  ),
    .rst_ni                 ( rst_ni ),
    .test_en_i              ( '0     ),
    .scan_rst_ni            ( '0     ),
    .ram_cfg_i              ( '0     ),

    // Configuration
    .hart_id_i              ( hart_id_i   ),
    .boot_addr_i            ( boot_addr_i ),

    // Instruction memory interface
    .instr_req_o            ( cpu_im_mux.req ),
    .instr_gnt_i            ( cpu_im_mux.gnt ),
    .instr_rvalid_i         ( cpu_im_mux.vld ),
    .instr_addr_o           ( cpu_im_mux.addr ),
    .instr_rdata_i          ( cpu_im_mux.rdata ),
    .instr_rdata_intg_i     ( '0 ),
    .instr_err_i            ( '0 ),

    // Data memory interface
    .data_req_o             ( cpu_dmem_mux.req   ),
    .data_gnt_i             ( cpu_dmem_mux.gnt   ),
    .data_rvalid_i          ( cpu_dmem_mux.vld   ),
    .data_we_o              ( cpu_dmem_mux.we    ),
    .data_be_o              ( cpu_dmem_mux.be    ),
    .data_addr_o            ( cpu_dmem_mux.addr  ),
    .data_wdata_o           ( cpu_dmem_mux.wdata ),
    .data_wdata_intg_o      ( /*NC*/         ),
    .data_rdata_i           ( cpu_dmem_mux.rdata ),
    .data_rdata_intg_i      ( '0 ),
    .data_err_i             ( '0 ),

    // Interrupt inputs
    .irq_i          ( core_irq_x ),
    .irq_id_o       ( /*NC*/     ),
    .irq_ack_o      ( irq_ready_o),
    .irq_level_i    ( irq_level_i ),
    .irq_shv_i      ( irq_shv_i   ),
    .irq_priv_i     ( irq_priv_i  ),

    // Debug interface
    .debug_req_i            ( debug_req_i       ),
    .crash_dump_o           ( /*NC*/            ),

    // Special control signals
    .fetch_enable_i         ( {3'b010, fetch_enable_i}),
    .alert_minor_o          ( /*NC*/            ),
    .alert_major_internal_o ( /*NC*/            ),
    .alert_major_bus_o      ( /*NC*/            ),
    .core_sleep_o           ( /*NC*/            ),

    .scramble_key_valid_i   ( '0                ),
    .scramble_key_i         ( '0                ),
    .scramble_nonce_i       ( '0                ),
    .scramble_req_o         ( /*NC*/            ),
    .double_fault_seen_o    ( /*NC*/            )
);

always_comb begin : gen_core_irq_x
    core_irq_x = '0;
    if (irq_valid_i) begin
        core_irq_x[irq_id_i] = 1'b1;
    end
end

// tie down unused signals
//assign axi_dmem_m.aw_prot = '0;
//assign axi_dmem_m.ar_prot = '0;
assign cpu_im_mux.we = 0;

assign axi_mux_aw_sel  = (axi_mem_slv.aw_addr < 32'h0000_2000) ? 0 : 1;
assign axi_mux_ar_sel  = (axi_mem_slv.ar_addr < 32'h0000_2000) ? 0 : 1;

assign dmem_mux_sel = (cpu_dmem_mux.addr >= 32'h0000_2000 &&
                       cpu_dmem_mux.addr < 32'h0000_3000) ? 1 : 0;

always_comb
  begin : imem_sel
    imem_mux_sel = 2'b00;
    if (cpu_im_mux.addr < 32'h0000_0200) begin
      imem_mux_sel = 2'b10;
    end
    else if (cpu_im_mux.addr > 32'h0000_0200
      && cpu_im_mux.addr < 32'h0000_1000) begin
      imem_mux_sel = 2'b11;
    end
    else if (cpu_im_mux.addr >= 32'h0000_1000
      && cpu_im_mux.addr < 32'h0000_2000) begin
      imem_mux_sel = 2'b01;
    end
  end

endmodule

