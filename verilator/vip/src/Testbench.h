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
            jtag_tick();
        }
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
        //JtagReg jtag_bypass(LocalSize, JtagSoCBypass);
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