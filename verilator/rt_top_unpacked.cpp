#include <iostream>
#include <memory>
#include <stdio.h>

#include "Vrt_top_unpacked.h"
//#include "verilated.h"

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

int main(int argc, char** argv) {

  //Verilated::commandArgs(argc, argv);
  //Verilated::traceEverOn(true);
  
  //const std::unique_ptr<Vrt_top_unpacked> top{new Vrt_top_unpacked};

  printf("Hello there\n");
  //while ( !Verilated::gotFinish() ) { 
  //  if(main_time != -1) {
  //    top->eval();    
  //  }
  //  main_time = top->nextTimeSlot();
  //}
//
  //top->final();

  return 0;
}