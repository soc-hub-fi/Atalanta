// Description: SRAM Behavioral Model

module dp_sram #(
  parameter       INIT_FILE  = "",
  parameter int unsigned DataWidth = 64,
  parameter int unsigned NumWords  = 1024
)(
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         areq_i,
  input  logic                         breq_i,
  input  logic                         awe_i,
  input  logic                         bwe_i,
  input  logic [$clog2(NumWords)-1:0] aaddr_i,
  input  logic [$clog2(NumWords)-1:0] baddr_i,
  input  logic [       DataWidth-1:0] awdata_i,
  input  logic [       DataWidth-1:0] bwdata_i,
  input  logic [ (DataWidth+7)/8-1:0] abe_i,
  input  logic [ (DataWidth+7)/8-1:0] bbe_i,
  output logic [       DataWidth-1:0] ardata_o,
  output logic [       DataWidth-1:0] brdata_o
  // ports for compatability only
  //output logic                         ruser_o,
  //input  logic                         wuser_i
);

`ifndef FPGA /************************* ASIC MODEL ****************************/

  localparam int unsigned AddrWidth = $clog2(NumWords);

  logic [DataWidth-1:0] abe_s, bbe_s;
  logic [DataWidth-1:0] ram [NumWords-1:0];
  logic [AddrWidth-1:0] araddr_q, braddr_q;

  genvar i;
  generate
    for (i = 0; i < (DataWidth+7)/8; i++) begin
      if (i == (DataWidth+7)/8-1) begin
        assign abe_s[DataWidth-1:i*8] = {(DataWidth-i*8){abe_i[i]}};
        assign bbe_s[DataWidth-1:i*8] = {(DataWidth-i*8){bbe_i[i]}};
      end else begin
         assign abe_s[(i+1)*8-1 : i*8] = {8{abe_i[i]}};
         assign bbe_s[(i+1)*8-1 : i*8] = {8{bbe_i[i]}};
      end
    end
  endgenerate

  generate

    initial begin
      for (int ram_index = 0; ram_index < NumWords; ram_index = ram_index + 1)
        ram[ram_index] = {DataWidth{1'b0}};

      if (INIT_FILE != "") begin: use_InitFile
       $readmemh(INIT_FILE, ram);
      end
    end

  endgenerate

  always @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin
    araddr_q <= '0;
    braddr_q <= '0;
  end else begin
    if (areq_i) begin
      if (!awe_i)
        araddr_q <= aaddr_i;
      else
        for (int i = 0; i < DataWidth; i++)
          if (abe_s[i]) ram[aaddr_i][i] <= awdata_i[i];
    end
    if (breq_i) begin
      if (!bwe_i)
        braddr_q <= baddr_i;
      else
        for (int i = 0; i < DataWidth; i++)
          if (bbe_s[i]) ram[baddr_i][i] <= bwdata_i[i];
      end
    end
  end

  assign ardata_o = ram[araddr_q];
  assign brdata_o = ram[braddr_q];


`else /****************************** FPGA MODEL ******************************/

  xilinx_dp_BRAM #(
    .RAM_WIDTH ( DataWidth ),
    .RAM_DEPTH ( NumWords  ),
    .INIT_FILE ( INIT_FILE  )
  ) i_xilinx_dp_bram (
    .addra ( aaddr_i  ),
    .addrb ( baddr_i  ),
    .dina  ( awdata_i ),
    .dinb  ( bwdata_i ),
    .clka  ( clk_i   ),
    .wea   ( awe_i    ),
    .web   ( bwe_i    ),
    .ena   ( 1'b1    ),
    .enb   ( 1'b1    ),
    .rsta  ( 1'b0    ),
    .rstb  ( 1'b0    ),
    .regcea( 1'b0     ),
    .regceb( 1'b0     ),
    .douta ( ardata_o ),
    .doutb ( brdata_o )
  );

`endif /***********************************************************************/

endmodule
