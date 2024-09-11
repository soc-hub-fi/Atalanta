
module rt_register_interface
#(
   parameter int unsigned DATA_WIDTH = 32,
   parameter int unsigned ADDR_WIDTH = 3
)(

   input  logic                  clk_i,
   input  logic                  rst_ni,
   input  logic [ADDR_WIDTH-1:0] addr_i,
   input  logic [DATA_WIDTH-1:0] wdata_i,
   output logic [DATA_WIDTH-1:0] rdata_o,
   input  logic                  write_enable_i,
   output logic [           3:0] gpio_output_o,
   input  logic [           3:0] gpio_input_i
);

localparam int unsigned CPU_CTRL_ADDR = 3'b000;
localparam int unsigned GPIO_I_ADDR   = 3'b001;
localparam int unsigned GPIO_O_ADDR   = 3'b010;

// field data FF registers
logic        fetch_enable_reg;
logic        cpu_rst_reg;
logic [23:0] cpu_boot_addr_reg;
logic [ 3:0] gpio_input_reg;
logic [ 3:0] gpio_output_reg;
//logic [31:0] mtvec_addr_reg;
//logic [31:0] mtvt_addr_reg;

always_ff @( posedge clk_i or negedge rst_ni )
begin : write_read_registers
  if ( ~rst_ni )
   begin
      gpio_output_reg  <= '0;
   end
   else if (write_enable_i) begin
      case(addr_i)
      CPU_CTRL_ADDR: begin
         fetch_enable_reg <= wdata_i[0];
         cpu_rst_reg      <= wdata_i[4];
         cpu_boot_addr_reg <= wdata_i[31:8];
      end
      GPIO_O_ADDR: begin
          gpio_output_reg <= {
                           wdata_i[24],
                           wdata_i[16],
                           wdata_i[ 8],
                           wdata_i[ 0]
                           };
      end

      default: begin
         // nothing
      end
      endcase
    end
end : write_read_registers


always_ff @( posedge clk_i or negedge rst_ni )
begin : read_only_registers
   if ( ~rst_ni ) begin
      gpio_input_reg <= '0;
   end
   else begin
      gpio_input_reg <= gpio_input_i;
   end
end : read_only_registers


always_comb begin : read_logic
   case(addr_i)
   CPU_CTRL_ADDR: begin
      rdata_o = { cpu_boot_addr_reg,
                  3'h0, cpu_rst_reg,
                  3'h0, fetch_enable_reg };
   end
   GPIO_I_ADDR: begin
      rdata_o = {
            7'h0, gpio_input_reg[3],
            7'h0, gpio_input_reg[2],
            7'h0, gpio_input_reg[1],
            7'h0, gpio_input_reg[0]
         };
   end
   GPIO_O_ADDR: begin
      rdata_o = {
         7'h0, gpio_output_reg[3],
         7'h0, gpio_output_reg[2],
         7'h0, gpio_output_reg[1],
         7'h0, gpio_output_reg[0]
      };
   end

   default: begin
      rdata_o = '0;
   end
   endcase
end : read_logic

//always_comb
//  construct_data :begin
//     // unused fields return 0;
//     reg0_data = 0;
//     reg1_data = 0;
//
//     reg0_data[REG0_FIELD0_CONTROL_BITOFFSET+REG0_FIELD0_CONTROL_BITWIDTH-1:REG0_FIELD0_CONTROL_BITOFFSET] = reg0_field0_control_reg; 
//
//     reg1_data[REG1_FIELD0_CONTROL_BITOFFSET+REG1_FIELD0_CONTROL_BITWIDTH-1:REG1_FIELD0_CONTROL_BITOFFSET] = reg1_field0_control_reg;
//     reg1_data[REG1_FIELD1_STATUS_BITOFFSET+REG1_FIELD1_STATUS_BITWIDTH-1:REG1_FIELD1_STATUS_BITOFFSET] = reg1_field1_status_reg;
//  end



always_comb begin : drive_output
   gpio_output_o   = gpio_output_reg;
   //mtvec_addr_o    = mtvec_addr_reg;
   //mtvt_addr_o     = mtvt_addr_reg;
end : drive_output

   /////////////////////////////////// SVA Properties for verificaytion ////////////////////////////////////////


   // Properties for control registers
   /*property reg0_field0_control_output_write;
      @(posedge clk) reg0_field0_control_output!=reg0_field0_control_reset_value;
   endproperty // reg0_field0_control_output_debug

   property reg1_field0_control_output_write;
      @(posedge clk) reg1_field0_control_output!=reg1_field0_control_reset_value;
   endproperty // reg1_field0_control_output_debug

   
    property address_is_always_valid;
       @(posedge clk) addr == reg0_addr || addr == reg1_addr;
   endproperty
   
   // When write is enabled and we have correct address then on next cycle (|=>) the output must equal to write data on prvevious clock cycle
    property reg0_field0_control_output_check;
      @(posedge clk) disable iff (!rstn) 
   write_not_read == 1'b1 && addr == reg0_addr |=> 
         reg0_field0_control_output == 
         $past(wdata_i[REG0_FIELD0_CONTROL_BITOFFSET+REG0_FIELD0_CONTROL_BITWIDTH-1:REG0_FIELD0_CONTROL_BITOFFSET]);
   endproperty // reg0_field0_control_output_check

   // Guarantee that *_outputs are written only due to bus write to correct address
   property no_reg0_field0_control_output_change_without_write;
      @(posedge clk) disable iff (!rstn) 
   addr != reg0_addr |=> 
         $stable(reg0_field0_control_output);
   endproperty // no_reg0_field0_control_output_change_without_write

   // Properties for status registers

   property rdata_is_always_valid;
      @(posedge clk) disable iff (!rstn)
   rdata_o == reg0_data || rdata_o == reg1_data;
   endproperty

   // Assertion fails without || reg1_field1_status_reset_value. disable iff doesn't work? as expected
   property reg1_field1_status_reg_read;
     @(posedge clk) disable iff (!rstn) 
   addr == reg1_addr |=> 
         rdata_o[REG1_FIELD1_STATUS_BITOFFSET+REG1_FIELD1_STATUS_BITWIDTH-1:REG1_FIELD1_STATUS_BITOFFSET] ==
         $past(reg1_field1_status_input) || reg1_field1_status_reset_value;
   endproperty // reg1_field1_status_reg_read



   // This assertion could not be proven because still rdata_o could return correct values with wrong address if status input
   // addressed by wrong address are equal.
   property no_reg1_field1_status_reg_rdata_without_correct_address;
       @(posedge clk) disable iff (!rstn)
    addr != reg1_addr |=> 
         rdata_o[REG1_FIELD1_STATUS_BITOFFSET+REG1_FIELD1_STATUS_BITWIDTH-1:REG1_FIELD1_STATUS_BITOFFSET] !=
         $past(reg1_field1_status_input);
   endproperty
   
   
   cover_reg0_field0_control_write: cover property (reg0_field0_control_output_write);
   cover_reg1_field0_control_write: cover property (reg1_field0_control_output_write);
   
   assume_address_is_valid: assume property (address_is_always_valid);
   
   
   assert_reg0_field0_control_output: assert property (reg0_field0_control_output_check);
   assert_no_reg0_field0_control_output_change_without_write: assert property (no_reg0_field0_control_output_change_without_write); 
   assert_rdata_is_always_valid: assert property (rdata_is_always_valid);
 
   assert_reg1_field1_status_reg_read: assert property (reg1_field1_status_reg_read);*/
   
   
endmodule

   
