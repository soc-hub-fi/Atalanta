

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

    virtual void jtag_connectivity_test (void) {
        printf("[JTAG] Performing connectivity tests - tick %ld\n", m_tickcount);
    }
    
    virtual void jtag_memory_test (void) {
        
    }

    virtual void jtag_load_elf (void) {

    }

    virtual void jtag_wait_eoc (void) {
        
    }
};