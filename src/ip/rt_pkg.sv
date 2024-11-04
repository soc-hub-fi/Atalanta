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

localparam xbar_rule_t [CoreXbarCfg.NumS+1] CoreAddrMap = '{
  // Rule 0 covers everything outside IMEM & DMEM
  '{idx: 0, start_addr: DbgRule.Start,  end_addr: DbgRule.End},
  '{idx: 0, start_addr: DmemRule.End,   end_addr: AxiRule.End},
  '{idx: 1, start_addr: ImemRule.Start, end_addr: ImemRule.End},
  '{idx: 2, start_addr: DmemRule.Start, end_addr: DmemRule.End}
};

//localparam rule_t SramRules [NumMemBanks] = '{idx: 32'd5, start_addr: ObiXbarCfg.AxiStart,  end_addr: ObiXbarCfg.AxiEnd  };
/*
localparam rule_t SramRule = '{idx: 32'd6, start_addr: ObiXbarCfg.SramStart,  end_addr: ObiXbarCfg.SramEnd  };
localparam rule_t AxiRule  = '{idx: 32'd5, start_addr: ObiXbarCfg.AxiStart,  end_addr: ObiXbarCfg.AxiEnd  };
localparam rule_t ApbRule  = '{idx: 32'd4, start_addr: ObiXbarCfg.ApbStart,  end_addr: ObiXbarCfg.ApbEnd  };
localparam rule_t DmemRule = '{idx: 32'd3, start_addr: ObiXbarCfg.DmemStart, end_addr: ObiXbarCfg.DmemEnd };
localparam rule_t ImemRule = '{idx: 32'd2, start_addr: ObiXbarCfg.ImemStart, end_addr: ObiXbarCfg.ImemEnd };
localparam rule_t RomRule  = '{idx: 32'd1, start_addr: ObiXbarCfg.RomStart,  end_addr: ObiXbarCfg.RomEnd  };
localparam rule_t DbgRule  = '{idx: 32'd0, start_addr: 32'h0000_0000,  end_addr: 32'h0000_1000  };
*/

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

localparam int unsigned DbgIdCode      = 32'hFEEDC0D3;
localparam int unsigned ImemSizeBytes  = get_addr_size(ImemRule.Start, ImemRule.End);
localparam int unsigned DmemSizeBytes  = get_addr_size(DmemRule.Start, DmemRule.End);

endpackage : rt_pkg
