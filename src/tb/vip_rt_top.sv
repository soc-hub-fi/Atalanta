`include "axi/assign.svh"
`include "axi/typedef.svh"

module vip_rt_top #(
  parameter time             ClkPerSys     = 0ns,
  parameter time             ClkPerJtag    = 0ns,
  parameter longint unsigned RstClkCycles  = 0,
  parameter longint unsigned TimeoutCycles = 0,
  parameter  int unsigned    AxiAw         = 32,
  parameter  int unsigned    AxiDw         = 32,
  parameter  int unsigned    AxiIw         = 9,
  parameter  int unsigned    AxiUw         = 4
)(
  output logic       clk_o,
  output logic       rst_no,
  AXI_BUS.Master     axi_mst,
  AXI_BUS.Slave      axi_slv,
  output logic       jtag_tck_o,
  output logic       jtag_tms_o,
  output logic       jtag_trst_no,
  output logic       jtag_tdi_o,
  input  logic       jtag_tdo_i,
  input  logic [3:0] gpio_dut_out,
  output logic [3:0] gpio_dut_in,
  output logic       uart_dut_rx_o,
  input  logic       uart_dut_tx_i
);

import "DPI-C" function byte read_elf(input string filename);
import "DPI-C" function byte get_entry(output longint entry);
import "DPI-C" function byte get_section(output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[], input longint len);

localparam real TAppl = 0.1;
localparam real TTest = 0.9;

typedef axi_test::axi_rand_master #(
  // AXI interface parameters
  .AW ( AxiAw ),
  .DW ( AxiDw ),
  .IW ( AxiIw ),
  .UW ( AxiUw ),
  // Stimuli application and test time
  .TA ( TAppl ),
  .TT ( TTest ),
  // Maximum number of read and write transactions in flight
  .MAX_READ_TXNS  ( 20 ),
  .MAX_WRITE_TXNS ( 20 ),
  .AXI_EXCLS      ( 0 ),
  .AXI_ATOPS      ( 0 ),
  .UNIQUE_IDS     ( 0 )
) axi_rand_master_t;

logic clk, rst_n;

assign clk_o = clk;
assign rst_no = rst_n;

JTAG_DV jtag (jtag_tck_o);

AXI_BUS_DV #(
  .AXI_ADDR_WIDTH ( AxiAw ),
  .AXI_DATA_WIDTH ( AxiDw ),
  .AXI_ID_WIDTH   ( AxiIw ),
  .AXI_USER_WIDTH ( AxiUw )
) axi_master_dv (clk_o);

AXI_BUS_DV #(
  .AXI_ADDR_WIDTH ( AxiAw ),
  .AXI_DATA_WIDTH ( AxiDw ),
  .AXI_ID_WIDTH   ( AxiIw ),
  .AXI_USER_WIDTH ( AxiUw )
) axi_slave_dv (clk_o);

`AXI_ASSIGN(axi_mst, axi_master_dv)
`AXI_ASSIGN(axi_slave_dv, axi_slv)

axi_rand_master_t axi_drv = new(axi_master_dv);

localparam dm::sbcs_t JtagInitSbcs = dm::sbcs_t'{
  sbautoincrement: 1'b1, sbreadondata: 1'b1, sbaccess: 2, default: '0};

typedef jtag_test::riscv_dbg #(
  .IrLength ( 5 ),
  .TA       ( ClkPerJtag * TAppl ),
  .TT       ( ClkPerJtag * TTest )
) riscv_dbg_t;

typedef bit [31:0] word;
typedef bit [15:0] half;

riscv_dbg_t::jtag_driver_t  jtag_dv   = new (jtag);
riscv_dbg_t                 jtag_dbg  = new (jtag_dv);

assign jtag_trst_no = jtag.trst_n;
assign jtag_tms_o   = jtag.tms;
assign jtag_tdi_o   = jtag.tdi;
assign jtag.tdo     = jtag_tdo_i;

/*
axi_sim_mem_intf #(
  .AXI_ADDR_WIDTH      (AxiAw),
  .AXI_DATA_WIDTH      (AxiDw),
  .AXI_ID_WIDTH        (AxiIw),
  .AXI_USER_WIDTH      (AxiUw),
  .WARN_UNINITIALIZED  (1),
  .APPL_DELAY          (TAppl),
  .ACQ_DELAY           (TTest)
) i_sim_mem (
  .clk_i   (clk),
  .rst_ni  (rst_n),
  .axi_slv (axi_slv),
  .mon_w_valid_o     (),
  .mon_w_addr_o      (),
  .mon_w_data_o      (),
  .mon_w_id_o        (),
  .mon_w_user_o      (),
  .mon_w_beat_count_o(),
  .mon_w_last_o      (),
  .mon_r_valid_o     (),
  .mon_r_addr_o      (),
  .mon_r_data_o      (),
  .mon_r_id_o        (),
  .mon_r_user_o      (),
  .mon_r_beat_count_o(),
  .mon_r_last_o      ()
);*/

initial begin
  @(negedge rst_n);
  jtag_dbg.reset_master();
  axi_drv.reset();
end

clk_rst_gen #(
  .ClkPeriod    (ClkPerSys),
  .RstClkCycles (RstClkCycles)
) i_sys_clk_rst_gen (
  .clk_o  (clk),
  .rst_no (rst_n)
);

clk_rst_gen #(
  .ClkPeriod    (ClkPerJtag),
  .RstClkCycles (RstClkCycles)
) i_jtag_clk_rst_gen (
  .clk_o  (jtag_tck_o),
  .rst_no ()
);

uart_bus #(
  .BAUD_RATE( 3000000 ),
  .PARITY_EN(    0 )
) i_uart (
  // Note invertion of signals from dut->uart
  .rx    ( uart_dut_tx_i ),
  .tx    ( uart_dut_rx_o ),
  .rx_en ( 1'b1    )
);


//sim_timeout #(
//  .Cycles (TimeoutCycles),
//  .ResetRestartsTimeout (1)
//) i_watchdog (
//  .clk_i  (clk),
//  .rst_ni (rst_n)
//);

task automatic wait_for_reset;
  @(posedge rst_n);
  @(posedge clk);
endtask

task automatic jtag_write(
  input dm::dm_csr_e addr,
  input bit [31:0] data,
  input bit wait_cmd = 0,
  input bit wait_sba = 0
);
  jtag_dbg.write_dmi(addr, data);
  if (wait_cmd) begin
    dm::abstractcs_t acs;
    do begin
      jtag_dbg.read_dmi_exp_backoff(dm::AbstractCS, acs);
      if (acs.cmderr) $fatal(1, "[JTAG] Abstract command error!");
    end while (acs.busy);
  end
  if (wait_sba) begin
    dm::sbcs_t sbcs;
    do begin
      jtag_dbg.read_dmi_exp_backoff(dm::SBCS, sbcs);
      if (sbcs.sberror | sbcs.sbbusyerror) $fatal(1, "[JTAG] System bus error!");
    end while (sbcs.sbbusy);
  end
endtask

// Initialize the debug module
task automatic jtag_init;
  rt_pkg::jtag_idcode_t idcode;
  dm::dmcontrol_t dmcontrol = '{dmactive: 1, default: '0};
  // Check ID code
  repeat(100) @(posedge jtag_tck_o);
  jtag_dbg.get_idcode(idcode);
  if (idcode != rt_pkg::DbgIdCode)
      $fatal(1, "[JTAG] Unexpected ID code: expected 0x%h, got 0x%h!", rt_pkg::DbgIdCode, idcode);
  // Activate, wait for debug module
  jtag_write(dm::DMControl, dmcontrol);
  do jtag_dbg.read_dmi_exp_backoff(dm::DMControl, dmcontrol);
  while (~dmcontrol.dmactive);
  // Activate, wait for system bus
  jtag_write(dm::SBCS, JtagInitSbcs, 0, 1);
  $display("[JTAG] Initialization done");
endtask

task automatic jtag_read_reg32(
  input  word addr,
  output word data,
  input int unsigned idle_cycles = 20,
  input bit verbose = 0
);
  automatic dm::sbcs_t sbcs = dm::sbcs_t'{sbreadonaddr: 1'b1, sbaccess: 2, default: '0};
  jtag_write(dm::SBCS, sbcs, 0, 1);
  jtag_write(dm::SBAddress1, addr[63:32]);
  jtag_write(dm::SBAddress0, addr[31:0]);
  jtag_dbg.wait_idle(idle_cycles);
  jtag_dbg.read_dmi_exp_backoff(dm::SBData0, data);
  if (verbose) $display("[JTAG] Read 0x%h from 0x%h", data, addr);
endtask

task automatic jtag_write_reg32(
  input word addr,
  input word data,
  input bit check_write,
  input int unsigned check_write_wait_cycles = 20,
  input bit verbose = 0
);
  automatic dm::sbcs_t sbcs = dm::sbcs_t'{sbaccess: 2, default: '0};
  if (verbose) $display("[JTAG] Writing 0x%h to 0x%h", data, addr);
  jtag_write(dm::SBCS, sbcs, 0, 1);
  jtag_write(dm::SBAddress1, addr[63:32]);
  jtag_write(dm::SBAddress0, addr[31:0]);
  jtag_write(dm::SBData0, data);
  jtag_dbg.wait_idle(check_write_wait_cycles);
  if (check_write) begin
    word rdata;
    jtag_read_reg32(addr, rdata, check_write_wait_cycles, verbose);
    if (rdata != data) $fatal(1,"[JTAG] - Read [FAILED], incorrect data 0x%h!", rdata);
    else if (verbose) $display("[JTAG] - Read back correct data");
  end
endtask

// Load binary with $readmemh()
task automatic readmem_elf_preload(input string binary);
  word sec_addr, sec_len;
  $display("[WARNING]: READMEM is not valid for real chips, NEVER rely only on this loading mode");
  $fatal(1, "[ERROR]: READMEM mode currently not supported, exiting");
  if (read_elf(binary))
    $fatal(1, "[READMEM] Failed to load ELF!");
  while (get_section(sec_addr, sec_len)) begin
    byte bf[] = new [sec_len];
    $display("[READMEM] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
    if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[READMEM] Failed to read ELF section!");
    //jtag_write(dm::SBCS, JtagInitSbcs, 1, 1);
    //jtag_write(dm::SBAddress0, sec_addr[31:0]);
    for (longint i = 0; i <= sec_len ; i += 4) begin
      bit checkpoint = (i != 0 && i % 512 == 0);
      if (checkpoint)
        $display("[READMEM] - %0d/%0d bytes (%0d%%)", i, sec_len, i*100/(sec_len>1 ? sec_len-1 : 1));
    end
  end
endtask

// Load a binary
task automatic jtag_elf_preload(input string binary, output word entry);
  word sec_addr, sec_len;
  $display("[JTAG] Preloading ELF binary: %s", binary);
  if (read_elf(binary))
    $fatal(1, "[JTAG] Failed to load ELF!");
  while (get_section(sec_addr, sec_len)) begin
    byte bf[] = new [sec_len];
    $display("[JTAG] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
    if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[JTAG] Failed to read ELF section!");
    jtag_write(dm::SBCS, JtagInitSbcs, 1, 1);
    jtag_write(dm::SBAddress0, sec_addr[31:0]);
    for (longint i = 0; i <= sec_len ; i += 4) begin
      bit checkpoint = (i != 0 && i % 512 == 0);
      if (checkpoint)
        $display("[JTAG] - %0d/%0d bytes (%0d%%)", i, sec_len, i*100/(sec_len>1 ? sec_len-1 : 1));
      jtag_write(dm::SBData0, {bf[i+3], bf[i+2], bf[i+1], bf[i]}, checkpoint, checkpoint);
    end
  end
  void'(get_entry(entry));
  $display("[JTAG] Preload complete");
endtask

// Halt the core and preload a binary
task automatic jtag_elf_halt_load(input string binary, output word entry);
  dm::dmstatus_t status;
  // Halt hart 0
  jtag_write(dm::DMControl, dm::dmcontrol_t'{haltreq: 1, dmactive: 1, default: '0});
  do jtag_dbg.read_dmi_exp_backoff(dm::DMStatus, status);
  while (~status.allhalted);
  $display("[JTAG] Halted hart 0");
  // Preload binary
  jtag_elf_preload(binary, entry);
endtask


// access (write) csr, gpr by means of abstract command
task automatic write_reg_abstract_cmd(input half regno_i, input word data_i);
  automatic word dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno_i};
  jtag_write(dm::Data0, data_i);
  jtag_write(dm::Command, dmi_command);
endtask

// Run a binary
task automatic jtag_elf_run(input string binary);
  word entry;
  jtag_elf_halt_load(binary, entry);
  // Repoint execution
  write_reg_abstract_cmd(dm::CSR_DPC, rt_pkg::ImemRule.Start);
  // Resume hart 0
  jtag_write(dm::DMControl, dm::dmcontrol_t'{resumereq: 1, dmactive: 1, default: '0});
  $display("[JTAG] Resumed hart 0 from 0x%h", entry);
endtask



// Wait for termination signal and get return code
task automatic jtag_wait_for_eoc();
  word exit_code = 0;
  while (exit_code[31] != 1) begin
    jtag_dbg.read_dmi_exp_backoff(dm::Data0, exit_code);
  end

  #10us;

  if (exit_code[30:0] == 31'b0)
    $display("[TB] Program returned EXIT_SUCCESS");
  else begin
    $display("[TB] Exit code: %h", exit_code);
    $display("[TB] Program execution [FAILED]!");
    $fatal(1,"[TB] Program execution unsuccessful");
  end

endtask



/// Sanity tests
task automatic run_dbg_mem_test();
  localparam int unsigned IterCnt = 200;
  int unsigned imem_start = rt_pkg::ImemRule.Start;
  int unsigned dmem_end   = rt_pkg::DmemRule.End;
  int unsigned sram_start = rt_pkg::SramRule.Start;
  int unsigned sram_end   = rt_pkg::SramRule.End;
  int unsigned size_spm   = rt_pkg::get_addr_size(imem_start, dmem_end);
  int unsigned size_sram  = rt_pkg::get_addr_size(sram_start, sram_end);
  int unsigned rand_addr  = 32'h0000_0000;

  $display("[test:dbg_mem] Scratchpads size is %08H, range %08H to %08H", size_spm, imem_start, dmem_end);
  $display("[test:dbg_mem] Performing %d word-alligned random address accesses to SPMs", IterCnt);

  for (int i=0; i<IterCnt; i++) begin : spm_alligned_loop
    rand_addr = (($urandom()%size_spm) & 32'hFFFF_FFFC) + imem_start;
    jtag_write_reg32(rand_addr, $urandom(), 1, 20, 0);
  end : spm_alligned_loop

  $display("[test:dbg_mem] SRAM size is %08H, range %08H to %08H", size_sram, sram_start, sram_end);
  $display("[test:dbg_mem] Performing %d word-alligned random address accesses to SRAM", IterCnt);

  for (int i=0; i<IterCnt; i++) begin : alligned_loop
    rand_addr = (($urandom()%size_sram) & 32'hFFFF_FFFC) + sram_start;
    jtag_write_reg32(rand_addr, $urandom(), 1, 20, 0);
  end : alligned_loop

  $display("[test:dbg_mem] No memory access errors, debugger test [PASSED]");

  //$display("[test:dbg_mem] Performing %d unalligned random address accesses", IterCnt);
  //for (int i=0; i<IterCnt; i++) begin : unalligned_loop
  //  rand_addr = ($urandom()%size) + imem_start;
  //  jtag_write_reg32(rand_addr, $urandom(), 1, 20, 0);
  //end : unalligned_loop
endtask

task automatic gpio_sanity_test ();
  fork
    begin
      wait (gpio_dut_out != '0);
      $display("[TB] GPIO output high, blink [PASSED]");
    end

    begin // Timeout
      #1ms;
      $error("[TB] No GPIO output received, [FAILED]!");
    end

  join_any
endtask

task automatic uart_rx_test ();
  #100us;
  i_uart.send_char("T");
  i_uart.send_char("e");
  i_uart.send_char("s");
  i_uart.send_char("t");

endtask

endmodule : vip_rt_top
