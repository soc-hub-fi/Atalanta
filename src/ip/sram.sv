// Description: SRAM Behavioral Model
`ifdef FPGA_MEM
  `define FPGA
`endif

module sram #(
  parameter              INIT_FILE     = "",
  parameter int unsigned DATA_WIDTH    = 64,
  parameter int unsigned NUM_WORDS     = 1024,
  // options for synthesisable memory: "SP" = Single Port, "RF" = Reg. File
  localparam             SynthMemType  = "SP"
)(
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         req_i,
  input  logic                         we_i,
  input  logic [$clog2(NUM_WORDS)-1:0] addr_i,
  input  logic [       DATA_WIDTH-1:0] wdata_i,
  input  logic [ (DATA_WIDTH+7)/8-1:0] be_i,
  output logic [       DATA_WIDTH-1:0] rdata_o
  // ports for compatability only
  //output logic                         ruser_o,
  //input  logic                         wuser_i
);

`ifndef FPGA /************************* ASIC MODEL ****************************/

  `ifndef SYNTH_MEM /************* SIMULATION *********************************/

    localparam ADDR_WIDTH = $clog2(NUM_WORDS);

    logic [DATA_WIDTH-1:0] be_s;
    logic [DATA_WIDTH-1:0] ram [NUM_WORDS-1:0];
    logic [ADDR_WIDTH-1:0] raddr_q;

    genvar i;
    generate
      for (i = 0; i < (DATA_WIDTH+7)/8; i++) begin
        if (i == (DATA_WIDTH+7)/8-1) begin
          assign be_s[DATA_WIDTH-1:i*8] = {(DATA_WIDTH-i*8){be_i[i]}};
        end else begin
           assign be_s[(i+1)*8-1 : i*8] = {8{be_i[i]}};
        end
      end
    endgenerate


    generate

      initial begin
        for (int ram_index = 0; ram_index < NUM_WORDS; ram_index = ram_index + 1)
          ram[ram_index] = {DATA_WIDTH{1'b0}};

        if (INIT_FILE != "") begin: use_init_file
         $readmemh(INIT_FILE, ram);
        end
      end

    endgenerate


    always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      raddr_q <= '0;
    end else begin
      if (req_i) begin
        if (!we_i)
          raddr_q <= addr_i;
        else
          for (int i = 0; i < DATA_WIDTH; i++)
            if (be_s[i]) ram[addr_i][i] <= wdata_i[i];
        end
      end
    end

    assign rdata_o = ram[raddr_q];
    //assign r_user_o = 1'b0;

  `else /********************** SYNTH_MEM *************************************/

    rt_ss_tech_mem #(
      .DATA_WIDTH (DATA_WIDTH),
      .NUM_WORDS  (NUM_WORDS)
    ) i_rt_ss_tech_mem_sram (
      .clk_i   ( clk_i   ),
      .req_i   ( req_i   ),
      .we_i    ( we_i    ),
      .addr_i  ( addr_i  ),
      .wdata_i ( wdata_i ),
      .be_i    ( be_i    ),
      .rdata_o ( rdata_o )
    );

  `endif

`else /****************************** FPGA MODEL ******************************/

  logic [3:0] bwe;
  assign bwe = be_i & {4{we_i}};


    xilinx_sp_BRAM #(
      .RAM_DEPTH (NUM_WORDS) // Specify RAM depth (number of entries)
    ) i_fpga_bram (
      .addra  (addr_i),   // Address bus, width determined from RAM_DEPTH
      .dina   (wdata_i),  // RAM input data
      .clka   (clk_i),    // Clock
      .wea    (bwe),     // Byte-write enable
      .ena    (1'b1),     // RAM Enable, for additional power savings, disable port when not in use
      .rsta   (~rst_ni),  // Output reset (does not affect memory contents)
      .regcea (1'b0),     // Output register enable
      .douta  (rdata_o)   // RAM output data
    );

`endif /***********************************************************************/

endmodule
