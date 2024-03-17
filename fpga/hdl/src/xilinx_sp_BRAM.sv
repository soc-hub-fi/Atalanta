//------------------------------------------------------------------------------
// Module   : xilinx_sp_BRAM.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 22-Nov-2022
//
// Description: Modified code taken from the single port BRAM taken from
// Xilinx templates.
//
// Parameters:
//  - RAM_WIDTH: Bit width of each row
//  - RAM_DEPTH: Number of rows
//  - INIT_FILE: Path to .mem file which is used to initialise RAM contents
//
// Inputs:
//  - addra: Address line
//  - dina: Write data in
//  - clka: Clock
//  - wea: Write enable
//  - ena: Read enable
//
// Outputs:
//  - douta: Read data out
//
// Revision History:
//  - Version 1.0: Initial release
//  - Version 1.1: Corrected formatting (03-Dec-2023 - Tom Szymkowiak)
//
//------------------------------------------------------------------------------

module xilinx_sp_BRAM #(
  parameter integer RAM_WIDTH = 18,
  parameter integer RAM_DEPTH = 1024,
  parameter         INIT_FILE = ""
) (
  input  logic [$clog2(RAM_DEPTH-1)-1:0] addra,
  input  logic [RAM_WIDTH-1:0]           dina,
  input  logic                           clka,
  input  logic                           wea,
  input  logic                           ena,

  output logic [RAM_WIDTH-1:0]           douta
);

  logic [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate

    initial begin
      for (int ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
        BRAM[ram_index] = {RAM_WIDTH{1'b0}};

      if (INIT_FILE != "") begin: use_init_file
       $readmemh(INIT_FILE, BRAM);
      end
    end

  endgenerate

  always @(posedge clka) begin
    if (ena) begin
      if (wea)
        BRAM[addra] <= dina;
      else 
        douta <= BRAM[addra];
    end
  end

endmodule
