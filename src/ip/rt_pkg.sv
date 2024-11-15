package rt_pkg;

typedef struct packed {
  int unsigned NumM;
  int unsigned NumS;
  int unsigned MaxTrans;
} xbar_cfg_t;

typedef struct packed {
  int unsigned Start;
  int unsigned End;
} addr_rule_t;

/// GENERAL ADDRESS MAPPING
localparam addr_rule_t DbgRule  = '{ Start: 32'h0000_0000, End: 32'h0000_1000 };
localparam addr_rule_t ImemRule = '{ Start: 32'h0000_1000, End: 32'h0000_5000 };
localparam addr_rule_t DmemRule = '{ Start: 32'h0000_5000, End: 32'h0000_9000 };
localparam addr_rule_t RomRule  = '{ Start: 32'h0000_9000, End: 32'h0000_9300 };
localparam addr_rule_t SramRule = '{ Start: 32'h0002_0000, End: 32'h0003_0000 };
localparam addr_rule_t ApbRule  = '{ Start: 32'h0003_0000, End: 32'h0006_0000 };
localparam addr_rule_t AxiRule  = '{ Start: 32'hFFFF_0000, End: 32'hFFFF_FFFF };


// APB MAPPING, INCLUSIVE END ADDR
localparam int unsigned GpioStartAddr   = 32'h0003_0000;
localparam int unsigned GpioEndAddr     = 32'h0003_00FF;
localparam int unsigned UartStartAddr   = 32'h0003_0100;
localparam int unsigned UartEndAddr     = 32'h0003_01FF;
localparam int unsigned MTimerStartAddr = 32'h0003_0200;
localparam int unsigned MTimerEndAddr   = 32'h0003_0210;
localparam int unsigned ClicStartAddr   = 32'h0005_0000;
localparam int unsigned ClicEndAddr     = 32'h0005_FFFF;
localparam int unsigned SpiStartAddr    = 32'h0006_0000;
localparam int unsigned SpiEndAddr      = 32'h0006_FFFF;

localparam int unsigned NumMemBanks = 1;

localparam xbar_cfg_t CoreXbarCfg = '{
  NumM      : 3,
  NumS      : 3,
  MaxTrans  : 3
};

localparam xbar_cfg_t MainXbarCfg = '{
  NumM      : 3,
  NumS      : 4 + NumMemBanks,
  MaxTrans  : 3
};

typedef struct packed {
  int unsigned idx;
  int unsigned start_addr;
  int unsigned end_addr;
} xbar_rule_t;

localparam xbar_rule_t [(CoreXbarCfg.NumS+1)-1:0] CoreAddrMap = '{
  // Rule 0 covers everything outside IMEM & DMEM
  '{idx: 0, start_addr: DbgRule.Start,  end_addr: DbgRule.End},
  '{idx: 0, start_addr: DmemRule.End,   end_addr: AxiRule.End},
  '{idx: 1, start_addr: ImemRule.Start, end_addr: ImemRule.End},
  '{idx: 2, start_addr: DmemRule.Start, end_addr: DmemRule.End}
};


function automatic int unsigned get_addr_size (
  int unsigned start_addr,
  int unsigned end_addr
);
  return (end_addr - start_addr);
endfunction

// Default JTAG ID code type
typedef struct packed {
  bit [ 3:0]  version;
  bit [15:0]  part_num;
  bit [10:0]  manufacturer;
  bit         _one;
} jtag_idcode_t;

localparam int unsigned DbgIdCode     = 32'hFEEDC0D3;
localparam int unsigned ImemSizeBytes = get_addr_size(ImemRule.Start, ImemRule.End);
localparam int unsigned DmemSizeBytes = get_addr_size(DmemRule.Start, DmemRule.End);
localparam int unsigned SramSizeBytes = get_addr_size(SramRule.Start, SramRule.End);


endpackage : rt_pkg
