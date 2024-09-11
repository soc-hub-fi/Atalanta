module rt_gpio
#(
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter int unsigned AXI_ADDR_WIDTH = 32
)(

  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] paddr_i,
  input  logic        psel_i,
  input  logic [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,
  output logic  [3:0] gpio_output_o,
  input  logic  [3:0] gpio_input_i
);

// TODO: add handshake

always_comb begin
  pready_o = '0;
  pslverr_o = '0;
  if (penable_i) begin
    pready_o = 1;
  end
end

rt_register_interface #() i_reg_if (
  .clk_i          (clk_i),
  .rst_ni         (rst_ni),
  .addr_i         (paddr_i[4:2]),
  .wdata_i        (pwdata_i),
  .rdata_o        (prdata_o),
  .write_enable_i (penable_i),
  .gpio_input_i   (gpio_input_i),
  .gpio_output_o  (gpio_output_o)
);

endmodule
