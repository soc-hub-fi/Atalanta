package rt_pkg;

typedef struct packed {
  int unsigned NumM;
  int unsigned NumS;
  int unsigned MaxTrans;
  // bootROM
  int unsigned RomStart;
  int unsigned RomEnd;
  // Debugger
  int unsigned DbgStart;
  int unsigned DbgEnd;
  // Imem SPM
  int unsigned ImemStart;
  int unsigned ImemEnd;
  // Dmem SPM
  int unsigned DmemStart;
  int unsigned DmemEnd;
  // SRAM Banks
  int unsigned SramStart;
  int unsigned SramEnd;
  // APB Peripherals
  int unsigned ApbStart;
  int unsigned ApbEnd;
  // AXI Region
  int unsigned AxiStart;
  int unsigned AxiEnd;
} xbar_cfg_t;


localparam int unsigned NumMemBanks = 2;
localparam xbar_cfg_t   ObiXbarCfg = '{
  NumM      : 4,
  NumS      : 6 + NumMemBanks,
  MaxTrans  : 3,
  /// Subsystem Address Mapping
  DbgStart  : 32'h0000_0000,
  DbgEnd    : 32'h0000_1000,
  ImemStart : 32'h0000_1000,
  ImemEnd   : 32'h0000_5000,
  DmemStart : 32'h0000_5000,
  DmemEnd   : 32'h0000_9000,
  RomStart  : 32'h0000_9000,
  RomEnd    : 32'h0000_9300,
  SramStart : 32'h0002_0000,
  SramEnd   : 32'h0003_0000,
  ApbStart  : 32'h0003_0000,
  ApbEnd    : 32'h0006_0000,
  AxiStart  : 32'hFFFF_0000,
  AxiEnd    : 32'hFFFF_FFFF
};

typedef struct packed {
  int unsigned idx;
  int unsigned start_addr;
  int unsigned end_addr;
} rule_t;

//localparam rule_t SramRules [NumMemBanks] = '{idx: 32'd5, start_addr: ObiXbarCfg.AxiStart,  end_addr: ObiXbarCfg.AxiEnd  };

localparam rule_t SramRule = '{idx: 32'd6, start_addr: ObiXbarCfg.SramStart,  end_addr: ObiXbarCfg.SramEnd  };
localparam rule_t AxiRule  = '{idx: 32'd5, start_addr: ObiXbarCfg.AxiStart,  end_addr: ObiXbarCfg.AxiEnd  };
localparam rule_t ApbRule  = '{idx: 32'd4, start_addr: ObiXbarCfg.ApbStart,  end_addr: ObiXbarCfg.ApbEnd  };
localparam rule_t DmemRule = '{idx: 32'd3, start_addr: ObiXbarCfg.DmemStart, end_addr: ObiXbarCfg.DmemEnd };
localparam rule_t ImemRule = '{idx: 32'd2, start_addr: ObiXbarCfg.ImemStart, end_addr: ObiXbarCfg.ImemEnd };
localparam rule_t RomRule  = '{idx: 32'd1, start_addr: ObiXbarCfg.RomStart,  end_addr: ObiXbarCfg.RomEnd  };
localparam rule_t DbgRule  = '{idx: 32'd0, start_addr: ObiXbarCfg.DbgStart,  end_addr: ObiXbarCfg.DbgEnd  };

//localparam rule_t [ObiXbarCfg.NumS-1:0] AddrMap = '{
//  '{idx: 32'd6, start_addr: ObiXbarCfg.AxiStart,   end_addr: ObiXbarCfg.AxiEnd  },
//  '{idx: 32'd5, start_addr: ObiXbarCfg.ApbStart,   end_addr: ObiXbarCfg.ApbEnd  },
//  '{idx: 32'd4, start_addr: ObiXbarCfg.SramStart,  end_addr: ObiXbarCfg.SramEnd },
//  '{idx: 32'd3, start_addr: ObiXbarCfg.DmemStart,  end_addr: ObiXbarCfg.DmemEnd },
//  '{idx: 32'd2, start_addr: ObiXbarCfg.ImemStart,  end_addr: ObiXbarCfg.ImemEnd },
//  '{idx: 32'd1, start_addr: ObiXbarCfg.DbgStart,   end_addr: ObiXbarCfg.DbgEnd  },
//  '{idx: 32'd0, start_addr: ObiXbarCfg.RomStart,   end_addr: ObiXbarCfg.RomEnd  }
//};

function automatic int unsigned get_addr_size (
  int unsigned start_addr,
  int unsigned end_addr
);
  return (end_addr - start_addr);

endfunction

endpackage : rt_pkg
