struct SimCtx {
  Vrt_top_unpacked *dut;
  VerilatedFstC *trace;
  vluint64_t &sim_time;
  SimCtx(Vrt_top_unpacked *dut, VerilatedFstC *trace, vluint64_t &sim_time) :
        dut(dut),
        trace(trace),
        sim_time(sim_time){}
};

void timestep(SimCtx* cx) {
    cx->dut->eval();
    cx->trace->dump(cx->sim_time);
    cx->sim_time++;
}