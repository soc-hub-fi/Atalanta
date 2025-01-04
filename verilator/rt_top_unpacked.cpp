#include <iostream>
#include <memory>
#include <stdio.h>

#include "Vrt_top_unpacked.h"
#include "verilated_fst_c.h"
#include "verilated.h"
#include "SimCxt.h"

int main(int argc, char** argv) {

  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  vluint64_t sim_time = 0;
  SimCtx cx(new Vrt_top_unpacked, new VerilatedFstC, sim_time);
  
  cx.dut->trace(cx.trace, 5);
  cx.trace->open("./waveform.fst");
  //const std::unique_ptr<Vrt_top_unpacked> top{new Vrt_top_unpacked};

  timestep(&cx);
  timestep(&cx);
  timestep(&cx);

  //timestep(&cx);
  printf("Hello there\n");
  //while ( !Verilated::gotFinish() ) { 
  //  if(main_time != -1) {
  //    top->eval();    
  //  }
  //  main_time = top->nextTimeSlot();
  //}
//
  //top->final();

  cx.trace->close();

  return 0;
}