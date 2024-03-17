
#define JTAG_CLOCK_PER       2   // in relation to clk period
#define DMI_SIZE             32+7+2
#define JTAG_SOC_INSTR_WIDTH 5
#define JTAG_SOC_IDCODE      0b00001
#define JTAG_SOC_DTMCSR      0b10000
#define JTAG_SOC_DMIACCESS   0b10001
#define JTAG_SOC_AXIREG      0b11111
#define JTAG_SOC_BBMUXREG    0b00101
#define JTAG_SOC_CONFREG     0b00110
#define JTAG_SOC_TESTMODEREG 0b01000
#define JTAG_SOC_BISTREG     0b01001
#define JTAG_SOC_BYPASS      0b11111

namespace jtag_pkg {

void jtag_clock( utils_pkg::SimVars vars, uint cycles ){
  for(int i=0; i<cycles; i=i+1){ 
    vars.dut->jtag_tck_i = 0;
    utils_pkg::timestep_half_clock(vars, JTAG_CLOCK_PER);
    vars.dut->jtag_tck_i = 1;
    utils_pkg::timestep_half_clock(vars, JTAG_CLOCK_PER);
    vars.dut->jtag_tck_i = 0;
  }

}

void jtag_reset( utils_pkg::SimVars vars ){
    vars.dut->jtag_tck_i     = 0;
    vars.dut->jtag_tms_i     = 0;
    vars.dut->jtag_td_i      = 0;
    vars.dut->jtag_trst_ni   = 0;
    utils_pkg::timestep_half_clock(vars, 2);
    vars.dut->jtag_trst_ni   = 1;
}

void jtag_softreset( utils_pkg::SimVars vars ){
    vars.dut->jtag_tms_i     = 1;
    vars.dut->jtag_td_i      = 0;
    vars.dut->jtag_trst_ni   = 1;
    jtag_pkg::jtag_clock(vars, 5);
    vars.dut->jtag_tms_i     = 0;
    jtag_pkg::jtag_clock(vars, 1);
    printf("[RT_JTAG_TB] %ld ns - softreset done\n", vars.sim_time);
}


class JTAG_reg {
  public:
    const uint32_t size; // multiple of 32 bits
    const uint32_t instr;

    JTAG_reg( uint32_t size, uint32_t instr) : size(size), instr(instr){};

    void idle( utils_pkg::SimVars vars ){
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_tms_i   = 1;
      vars.dut->jtag_td_i    = 0;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 1);
    }

    void update_and_goto_shift( utils_pkg::SimVars vars ){
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_tms_i   = 1;
      vars.dut->jtag_td_i    = 0;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 1;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 1);
      jtag_clock(vars, 1);
    }

    void jtag_goto_SHIFT_IR( utils_pkg::SimVars vars ){
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_tms_i   = 1;
      vars.dut->jtag_td_i    = 0;
      jtag_clock(vars, 2);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 2);
    }

    void jtag_goto_SHIFT_DR( utils_pkg::SimVars vars ){
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_tms_i   = 1;
      vars.dut->jtag_td_i    = 0;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 2);
    }

    void jtag_goto_UPDATE_DR_FROM_SHIFT_DR( utils_pkg::SimVars vars ){
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_tms_i   = 1;
      vars.dut->jtag_td_i    = 1;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 50);
    }

    uint64_t jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA( utils_pkg::SimVars vars ){
      uint64_t dataout = 0;
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_td_i    = 1;
      vars.dut->jtag_tms_i   = 1;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 1;
      jtag_clock(vars, 2);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 1;
      jtag_clock(vars, 1);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 2);
      for (int i=0; i<DMI_SIZE; i++){
        if (i == (DMI_SIZE-1)){
          vars.dut->jtag_tms_i = 1;
        }
        vars.dut->jtag_td_i = 0;
        jtag_clock(vars, 1);
        dataout |= (vars.dut->jtag_td_o) << i;
      }
      return dataout;
    }

    uint64_t jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA( utils_pkg::SimVars vars ){
      uint64_t dataout = 0;
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_td_i    = 1;
      vars.dut->jtag_tms_i   = 1;
      jtag_clock(vars, 2);
      vars.dut->jtag_tms_i   = 0;
      jtag_clock(vars, 1);
      jtag_clock(vars, 1);
      for (int i=0; i<DMI_SIZE; i++){
        if (i == (DMI_SIZE-1)){
          vars.dut->jtag_tms_i = 1;
        }
        vars.dut->jtag_td_i = 0;
        jtag_clock(vars, 1);
        dataout |= (vars.dut->jtag_td_o) << i;
      }
      return dataout;
    }

    void jtag_shift_SHIFT_IR( utils_pkg::SimVars vars ){
      vars.dut->jtag_trst_ni = 1;
      vars.dut->jtag_tms_i   = 0;
      for (int i=0; i<JTAG_SOC_INSTR_WIDTH; i++){
        if (i==(JTAG_SOC_INSTR_WIDTH-1)){
          vars.dut->jtag_tms_i = 1;
        }
        int tmp = (instr >> i) & 0x1;
        vars.dut->jtag_td_i = tmp;
        jtag_clock(vars, 1);
      }
    }

    uint32_t* jtag_shift_NBITS_SHIFT_DR( 
      utils_pkg::SimVars vars, 
      uint32_t* datain,
      uint32_t numbits){
        uint32_t* dataout = new uint32_t[size]();
        vars.dut->jtag_trst_ni = 1;
        vars.dut->jtag_tms_i   = 0;
        for (int i=0; i<numbits; i++){
          int arr_idx = i / 32;
          if (i == (numbits-1)){
            vars.dut->jtag_tms_i = 1;
          }
          vars.dut->jtag_td_i = (datain[arr_idx] >> i) & 0x1;
          jtag_clock(vars, 1);
          dataout[arr_idx] |= (vars.dut->jtag_td_o) << i;
        }
        return dataout;
    }

    uint32_t* shift_nbits_noex( 
      utils_pkg::SimVars vars, 
      uint32_t* datain,
      uint32_t numbits){
        uint32_t* dataout = new uint32_t(size);
        vars.dut->jtag_trst_ni = 1;
        vars.dut->jtag_tms_i   = 0;
        for (int i=0; i<numbits; i++){
          int arr_idx = i / 32;
          vars.dut->jtag_td_i = (datain[size] >> i) & 0x1;
          jtag_clock(vars, 1);
          dataout[size] |= (vars.dut->jtag_td_o) << i;
        }
        return dataout;
    }

    void start_shift( utils_pkg::SimVars vars ){
      this->jtag_goto_SHIFT_DR( vars );
    }

    uint32_t* shift_nbits( utils_pkg::SimVars vars, uint32_t* datain, uint32_t numbits){
        return this->jtag_shift_NBITS_SHIFT_DR( vars, datain, numbits );
    }

    void setIR( utils_pkg::SimVars vars ){
      this->jtag_goto_SHIFT_IR(  vars );
      this->jtag_shift_SHIFT_IR( vars );
      this->idle( vars );
    }

    uint32_t* shift( utils_pkg::SimVars vars, uint32_t* datain){
        if(datain == NULL) printf("ERROR: datain is NULL\n");
        uint32_t* dataout = new uint32_t[size]();
        this->jtag_goto_SHIFT_DR( vars );
        dataout = this->jtag_shift_NBITS_SHIFT_DR( vars, datain, size*32 );
        this->idle( vars );
        return dataout;
    }
};

/*class debug_mode_if_t {
  public:
    void init_dmi_access( utils_pkg::SimVars vars ){
      JTAG_reg jtag_soc_dbg( 1, JTAG_SOC_IDCODE );
      jtag_soc_dbg.setIR( vars );
    }
    void init_dtmcs( utils_pkg::SimVars vars ){
      JTAG_reg jtag_soc_dbg( 1, JTAG_SOC_DTMCSR );
      jtag_soc_dbg.setIR( vars );
    }

    void dump_dm_info();

    uint64_t set_dmi( utils_pkg::SimVars vars, char op_i, uint32_t address_i, uint32_t data_i ){
      uint64_t buffer = 0;
      JTAG_reg jtag_soc_dbg( 2, JTAG_SOC_DMIACCESS );

    }

    uint32_t read_debug_reg( utils_pkg::SimVars vars, uint32_t dmi_addr_i ){
      char     dm_op   = 0;
      uint32_t dm_addr = 0;
      uint32_t dm_data = 0;

      do {

      }
      while();
    }

    void set_haltreq( utils_pkg::SimVars vars, bool haltreq ){
      char     dm_op   = 0;
      uint32_t dm_addr = 0;
      uint32_t dm_data = 0;

      this.init_dmi_access( vars );
    }
};*/

void jtag_bypass_test( utils_pkg::SimVars vars ){
  const int local_size = 8;
  bool success = true;
  JTAG_reg jtag_bypass(local_size, JTAG_SOC_BYPASS);
  uint32_t* result_data = new uint32_t(local_size);
  uint32_t test_data[local_size] = { 0x00001111,
                                     0xEEEEFFFF,
                                     0xCCCCDDDD,
                                     0xAAAABBBB,
                                     0x89ABCDEF,
                                     0x01234567,
                                     0x0BADF00D,
                                     0xDEADBEEF };
  jtag_bypass.setIR( vars );

  result_data = jtag_bypass.shift( vars, test_data );

  // shift whole array right 1 place, account for partitioning
  for (int it = 0; it<local_size; it++){ 
    uint testvar = result_data[it+1] & 0x1;
    if (it == local_size - 1 ) testvar = 0x1; // hardcoded, not optimal
    result_data[it] = (result_data[it] >> 1) | testvar << 31;
  }

  for (int it = 0; it<local_size; it++){
    if (test_data[it] != result_data[it])
      success = false;
  }

  if(success)
    printf("[RT_JTAG_TB] Bypass Test Passed! (%0ld ps)\n", vars.sim_time);
  else{
    printf("fail!\n");
    for(int it=0; it<8; it++){
      printf("test[%d]: %08x result[%d]: %08x \n",it, test_data[it], it, result_data[it]);
    }
  }
}

void jtag_get_idcode( utils_pkg::SimVars vars ){
  JTAG_reg jtag_idcode(1, JTAG_SOC_IDCODE);
  uint32_t* s_idecode = new uint32_t;
  jtag_idcode.setIR( vars );
  uint32_t zero_data[] = { 0x00000000 };
  s_idecode = jtag_idcode.shift( vars, zero_data );

  printf("[RT_JTAG_TB] Tap ID: %X (%0ld ps)\n", *s_idecode, vars.sim_time );
  if (*s_idecode != 0xFEEDC0D3){
    printf( "[RT_JTAG_TB] Tap ID test [FAILED] (%0ld)\n", vars.sim_time );
  } else {
    printf( "[RT_JTAG_TB] Tap ID test [PASSED] (%0ld)\n", vars.sim_time );
  }
}

void run_jtag_conn_test( utils_pkg::SimVars vars ){
  printf("[RT_JTAG_TB] %0ld ps - Performing JTAG Reset Test.\n", vars.sim_time      );
  jtag_reset( vars );
  utils_pkg::timestep_half_clock(vars, 10);

  printf("[RT_JTAG_TB] %0ld ps - Performing JTAG Soft-Reset Test.\n", vars.sim_time );
  jtag_softreset( vars );
  utils_pkg::timestep_half_clock(vars, 10);

  printf("[RT_JTAG_TB] %0ld ps - Performing JTAG Bypass Test.\n", vars.sim_time     );
  jtag_bypass_test( vars );
  utils_pkg::timestep_half_clock(vars, 10);

  printf("[RT_JTAG_TB] %0ld ps - Performing JTAG Get IDCODE Test.\n", vars.sim_time );
  jtag_get_idcode( vars );
  utils_pkg::timestep_half_clock(vars, 10);

}

}