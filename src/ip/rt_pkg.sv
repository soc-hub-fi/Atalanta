package rt_pkg;

typedef struct packed {
  int unsigned NumM;
  int unsigned NumS;
  // bootROM
  int unsigned RomEnd;
  int unsigned RomStart;
  // Debugger
  int unsigned DbgEnd;
  int unsigned DbgStart;
  // Imem SPM
  int unsigned ImemEnd;
  int unsigned ImemStart;
  // Dmem SPM
  int unsigned DmemEnd;
  int unsigned DmemStart;
  // SRAM Banks
  int unsigned SramEnd;
  int unsigned SramStart;
  // APB Peripherals
  int unsigned ApbEnd;
  int unsigned ApbStart;
  // AXI Region
  int unsigned AxiEnd;
  int unsigned AxiStart;
} xbar_cfg_t;


localparam int unsigned NumMemBanks = 2;
localparam xbar_cfg_t   ObiXbarCfg = '{
  NumM      : 3,
  NumS      : 6 + NumMemBanks,
  RomStart  : 32'h0000_0000,
  RomEnd    : 32'h0000_0300,
  DbgStart  : 32'h0000_0300,
  DbgEnd    : 32'h0000_1000,
  ImemStart : 32'h0000_1000,
  ImemEnd   : 32'h0000_5000,
  DmemStart : 32'h0000_5000,
  DmemEnd   : 32'h0000_9000,
  ApbStart  : 32'h0003_0000,
  ApbEnd    : 32'h0003_1000,
  AxiStart  : 32'hFFFF_0000,
  AxiEnd    : 32'hFFFF_FFFF
};

function automatic int unsigned get_addr_size (
  int unsigned start_addr,
  int unsigned end_addr
);
  return (end_addr - start_addr);

endfunction

endpackage : rt_pkg
