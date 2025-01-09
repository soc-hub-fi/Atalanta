#include <iostream>
#include <memory>
#include <stdio.h>

#define CLK_PER      4
#define RST_DELAY    80
#define CLK_DELAY    20
#define JTAG_START   120
#define JTAG_CLK_PER 5

#include "Vrt_top_unpacked.h"
#include "verilated_fst_c.h"
#include "verilated.h"
#include "vip/src/Testbench.h"
//#include "SimCxt.h"
//#include "vip/src/ClkRstDrv.h"
//#include "vip/src/JtagDrv.h"

//enum Sequence {
//  JTAG,
//  IDLE,
//  DONE
//};

class TbRtTop : public Testbench<Vrt_top_unpacked> {};

int main(int argc, char** argv) {

  Verilated::commandArgs(argc, argv);
  //Verilated::traceEverOn(true);

  TbRtTop* tb = new TbRtTop();

  tb->open_trace("./waveform.fst");
  for (int it=0;it<10;it++)
    tb->tick();

  tb->reset();
  tb->jtag_init();

  //uint64_t sim_time = 0;
  //SimCtx cx(new Vrt_top_unpacked, new VerilatedFstC, sim_time);
  //enum Sequence seq = JTAG;
  
  //cx.dut->trace(cx.trace, 5);
  //cx.trace->open("./waveform.fst");
//
  //ClkRstDrv* cr_drv = new ClkRstDrv(&cx);
  //JtagDrv* jtag_drv = new JtagDrv(&cx, JTAG_CLK_PER);

  //int runtime=0;
  //while(runtime < 5000) {
  //  bool after_re = (cx.dut->clk_i  && cx.dut->rst_ni &&
  //                  (sim_time % (CLK_PER*2) == 0));
  //  cr_drv->clock(CLK_DELAY, CLK_PER);
  //  cr_drv->reset(RST_DELAY);
//
  //  // drive inputs with slight delay after RE
  //  if (after_re) {
  //    switch (seq)
  //    {
  //    case JTAG:
  //      if(jtag_drv->connectivity_test(&cx, JTAG_START))
  //        seq = IDLE;
  //      break;
//
  //    case IDLE: 
  //      printf("DONE\n");
  //      seq = DONE; 
  //      break;
  //    default: break;
  //    }
  //  }
//
  //  // TODO: Update sequence state
//
  //  cx.timestep();
  //  runtime++;
  //}

  delete tb;
  //cx.trace->close();
  //delete cr_drv;

  return 0;
}