// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.


// This module takes data over UART and prints them to the console
// A string is printed to the console as soon as a '\n' character is found
interface uart_bus
  #(
    parameter BAUD_RATE = 115200,
    parameter PARITY_EN = 0
    )
  (
    input  logic rx,
    output logic tx,

    input  logic rx_en
  );

  localparam time UartBaudPeriod = 1000ns*1000*1000/BAUD_RATE;

  logic [7:0]       character;
  logic             parity;

  initial
  begin
    tx   = 1'b0;
  end

  always
  begin
    if (rx_en)
    begin
      @(negedge rx);
      #(UartBaudPeriod/2) ;
      for (int i=0;i<=7;i++)
      begin
        #UartBaudPeriod character[i] = rx;
      end

      if(PARITY_EN == 1)
      begin
        // check parity
        #UartBaudPeriod parity = rx;

        for (int i=7;i>=0;i--)
        begin
          parity = character[i] ^ parity;
        end

        if(parity == 1'b1)
        begin
          $display("Parity error detected");
        end
      end

      // STOP BIT
      #UartBaudPeriod;
      $write("%c", character);
    end else
      #10;
  end

  task send_char(input logic [7:0] c);
    int i;

    // start bit
    tx = 1'b0;

    for (i = 0; i < 8; i++) begin
      #(UartBaudPeriod);
      tx = c[i];
      $display("[UART] Sent %x at time %t",c[i],$time);
    end

    // stop bit
    #(UartBaudPeriod);
    tx = 1'b1;
    #(UartBaudPeriod);
  endtask
endinterface
