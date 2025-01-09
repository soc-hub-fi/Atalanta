// Testbench template, modelled from https://github.com/ZipCPU/zipcpu/blob/master/sim/verilator/testb.h
template <class VA>
class Testbench {
public:
    VA             *m_dut;
    VerilatedFstC*  m_trace;
    uint64_t        m_tickcount;

    Testbench(void) : m_trace(NULL), m_tickcount(01) {
        m_dut = new VA;
        Verilated::traceEverOn(true);
		m_dut->clk_i = 0;
		eval(); // set initial values
    }

    virtual ~Testbench(void){
        close_trace();
        delete m_dut;
        m_dut = NULL;
    }

    virtual void open_trace(const char* fst_name){
        if (!m_trace) {
            m_trace = new VerilatedFstC;
            m_dut->trace(m_trace, 99);
            m_trace->open(fst_name);
        }
    }

    virtual void close_trace(void) {
        if (m_trace){
            m_trace->close();
            delete m_trace;
            m_trace = NULL;
        }
    }
    
    virtual void eval(void) {
        m_dut->eval();
    }

    virtual void tick(void) {
        m_tickcount++;
        eval();
        if (m_trace) m_trace->dump((vluint64_t)(10*m_tickcount-2));
        m_dut->clk_i = 1;
        eval();
        if (m_trace) m_trace->dump((vluint64_t)(10*m_tickcount));
        m_dut->clk_i = 0;
        eval();
        if (m_trace){
            m_trace->dump((vluint64_t)(10*m_tickcount+5));
            m_trace->flush();
        }
    }

    virtual void reset(void) {
        m_dut->rst_ni = 0;
        tick();
        m_dut->rst_ni = 1;
    }

    uint64_t tickcount(void) {
		return m_tickcount;
	}

    // TODO:separate JTAG functionality to other class/file?
    virtual void jtag_tick(void) {
        m_dut->jtag_tck_i = 0;
        for (int i=0; i<JTAG_CLK_PER; i++) tick();
        m_dut->jtag_tck_i = 1;
        for (int i=0; i<JTAG_CLK_PER; i++) tick();
        m_dut->jtag_tck_i = 0;
    }

    virtual void goto_shift_ir(void) {
        m_dut->jtag_tms_i   = 1;
        m_dut->jtag_td_i    = 0;
        m_dut->jtag_trst_ni = 1;
        jtag_tick();
        jtag_tick();
        m_dut->jtag_tms_i   = 0;
        jtag_tick();
        jtag_tick();
    }
    virtual void shift_shift_ir(const uint32_t instr) {
        const uint32_t JtagInstrWidth = 5;
        m_dut->jtag_trst_ni = 1;
        m_dut->jtag_tms_i   = 0;
        for (int i=0; i<JtagInstrWidth; i++){
            if (i==(JtagInstrWidth-1)){
                m_dut->jtag_tms_i = 1;
            }
            int tmp = (instr >> i) & 0x1;
            m_dut->jtag_td_i = tmp;
            jtag_tick();
        }
    }

    virtual void goto_shift_dr (void) {
        m_dut->jtag_tms_i   = 1;
        m_dut->jtag_trst_ni = 1;
        m_dut->jtag_td_i    = 0;
        jtag_tick();
        m_dut->jtag_tms_i   = 0;
        jtag_tick();
        jtag_tick();
    }

    virtual std::vector<uint32_t> shift_nbits_shift_dr (std::vector<uint32_t> data, uint32_t size) {
        std::vector<uint32_t> result = {0};
        const uint32_t NumBits = size * 32;
        m_dut->jtag_trst_ni = 1;
        m_dut->jtag_tms_i   = 0;
        for (int i=0; i<NumBits; i++){
            int idx = i / 32;
            if (i == NumBits-1){
                m_dut->jtag_tms_i = 1;
            }
            m_dut->jtag_td_i = (data[idx] >> i) & 0x1;
            jtag_tick();
            result[idx] |= (m_dut->jtag_td_o) << i;
        }
        return result;
    }

    virtual void idle(void) {
        m_dut->jtag_tms_i   = 1;
        m_dut->jtag_td_i    = 0;
        m_dut->jtag_trst_ni = 1;
        jtag_tick();
        m_dut->jtag_tms_i   = 0;
        jtag_tick();
    }

    virtual void set_ir (const uint32_t instr) {
        goto_shift_ir();
        shift_shift_ir(instr);
        idle();
    }

    virtual std::vector<uint32_t> shift(std::vector<uint32_t> data, uint32_t size) {
        std::vector<uint32_t> result = {0};
        if (data.empty()) printf("ERROR: data empty");
        goto_shift_dr();
        result = shift_nbits_shift_dr(data, size);
        idle();
        return result;
    }

    virtual void jtag_reset (void) {
        printf("[JTAG] Lifting JTAG reset        \t-\ttick %ld\n", m_tickcount);
        m_dut->jtag_tck_i   = 0;
        m_dut->jtag_tms_i   = 0;
        m_dut->jtag_td_i    = 0;
        m_dut->jtag_trst_ni = 0;
        tick();
        m_dut->jtag_trst_ni = 1;
    }
    virtual void jtag_softreset (void) {
        printf("[JTAG] Performing JTAG softreset \t-\ttick %ld\n", m_tickcount);
        m_dut->jtag_tms_i   = 1;
        m_dut->jtag_td_i    = 0;
        m_dut->jtag_trst_ni = 1;
        for (int i=0; i<5; i++) jtag_tick();
        m_dut->jtag_tms_i   = 0;
        jtag_tick();
        printf("[JTAG] JTAG softreset done       \t-\ttick %ld\n", m_tickcount);
    }
    virtual void jtag_bypass_test (void) {
        printf("[JTAG] Performing bypass test    \t-\ttick %ld\n", m_tickcount);
        const uint32_t LocalSize     = 8;
        const uint32_t JtagSoCBypass = 0b11111;
        std::vector<uint32_t> test_data = { 
            0x00001111,
            0xEEEEFFFF,
            0xCCCCDDDD,
            0xAAAABBBB,
            0x89ABCDEF,
            0x01234567,
            0x0BADF00D,
            0xDEADBEEF 
        };

        set_ir(JtagSoCBypass);
        std::vector<uint32_t> result_data = shift(test_data, LocalSize);

        printf("Pre shift\n");
        for (int i=0;i<LocalSize;i++) {
            printf("[JTAG] test[%d]: %08x result[%d]: %08x \n",i, test_data[i], i, result_data[i]);
        }


        // shift whole array right 1 place, account for partitioning
        bool tmp_bit = 0;
        for (int i=0; i<LocalSize; i++) {
            //uint32_t tmp = result_data[i+1] & 0x1;
            //if (i == LocalSize-1) tmp = 0x1;
            //result_data[i] = (result_data[i] >> 1) | tmp << 31;
            if (i == LocalSize-1){
                tmp_bit = 1;
            } else {
                tmp_bit = result_data[i+1] & 0x1;
            }
            result_data[i] = result_data[i] >> 1 | (tmp_bit << 31);

        }

        printf("post shift\n");
        // Check result
        for (int i=0;i<LocalSize;i++) {
            printf("[JTAG] test[%d]: %08x result[%d]: %08x \n",i, test_data[i], i, result_data[i]);
        }


    }
    virtual void jtag_get_idcode (void) {
        printf("[JTAG] Performing IDCODE test    \t-\ttick %ld\n", m_tickcount);

    }

    virtual void jtag_connectivity_test (void) {
        printf("[JTAG] Performing connectivity tests\t-\ttick %ld\n", m_tickcount);
        jtag_reset();
        for (int i=0; i<10;i++) tick();
        jtag_softreset();
        for (int i=0; i<10;i++) tick();

        jtag_bypass_test();
        for (int i=0; i<10;i++) tick();

        jtag_get_idcode();
        for (int i=0; i<10;i++) tick();
    }
    
    virtual void jtag_memory_test (void) {
        
    }

    virtual void jtag_load_elf (void) {

    }

    virtual void jtag_wait_eoc (void) {
        
    }
};