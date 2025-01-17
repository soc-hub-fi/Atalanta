#include <iostream>
#include <memory>
#include <stdio.h>
//#include <svdpi.h>
#include <vector>
#include <map>


// preprocessor hack to deal with strings
#define xstr(s) str(s)
#define str(s) #s

#define CLK_PER      4
#define RST_DELAY    80
#define CLK_DELAY    20
#define JTAG_START   120
#define JTAG_CLK_PER 1

extern "C" char read_elf(const char *filename);
extern "C" char get_entry(long long *entry_ret);
extern "C" char get_section(long long *address_ret, long long *len_ret);

// address and size
extern std::vector<std::pair<uint64_t, uint64_t>> sections;

// memory based address and content
extern std::map<uint64_t, std::vector<uint8_t>> mems;

#include "Vrt_top_unpacked.h"
#include "verilated_fst_c.h"
#include "verilated.h"
#include "vip/src/Testbench.h"

class TbRtTop : public Testbench<Vrt_top_unpacked> {};

int main(int argc, char** argv) {

  Verilated::commandArgs(argc, argv);
  TbRtTop* tb = new TbRtTop();
  const std::string TestName = xstr(TEST);
  const std::string ElfPath  = "./tmp_elf";

  tb->open_trace("./waveform.fst");
  for (int it=0;it<100;it++) tb->tick();

  if (TestName == "") {
    printf("TEST not set, exiting\n");
  } else {
    tb->reset();
    tb->jtag_reset_master();
    tb->jtag_init();
    if (TestName == "jtag_access") {
      tb->jtag_memory_test();
    } else { // software test
      tb->jtag_elf_run(ElfPath, JTAG_LOAD);
      tb->jtag_wait_eoc();
    }
  }

  delete tb;

  return 0;
}