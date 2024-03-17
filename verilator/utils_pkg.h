namespace utils_pkg {

struct SimVars {
  Vrt_top *dut;
  VerilatedVcdC *m_trace;
  vluint64_t &sim_time;
  SimVars(Vrt_top *dut, VerilatedVcdC *m_trace, vluint64_t &sim_time) :
        dut(dut),
        m_trace(m_trace),
        sim_time(sim_time){}
};

void timestep_half_clock( SimVars vars, vluint64_t count){
  for(int it = 0; it < count; it++){
    vars.dut->clk_i ^= 1;
    vars.dut->eval();
    vars.m_trace->dump(vars.sim_time);
    vars.sim_time++;
  }
}

void dut_reset( SimVars vars ){
    vars.dut->rst_ni         = 0;
    vars.dut->jtag_tck_i     = 1;
    vars.dut->jtag_tms_i     = 1;
    vars.dut->jtag_trst_ni   = 1;
    vars.dut->jtag_td_i      = 1;
    vars.dut->gpio_input_i   = 1;
    timestep_half_clock( vars, 1 );
    //vars.dut->rst_ni         = 0;
    vars.dut->jtag_tck_i     = 0;
    vars.dut->jtag_tms_i     = 0;
    vars.dut->jtag_trst_ni   = 0;
    vars.dut->jtag_td_i      = 0;
    vars.dut->gpio_input_i   = 0;
}


}