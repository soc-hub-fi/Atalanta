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

    virtual void jtag_reset(void) {
        m_dut->jtag_tms_i   = 1;
        m_dut->jtag_td_i    = 0;
        m_dut->jtag_trst_ni = 0;
        jtag_tick();
        jtag_tick();
        m_dut->jtag_trst_ni = 1;
        jtag_tick();
    }
    virtual void jtag_softreset(void) {
        m_dut->jtag_tms_i   = 1;
        m_dut->jtag_td_i    = 0;
        for(int i=0;i<6;i++) jtag_tick();
        m_dut->jtag_tms_i   = 0;
        jtag_tick();
    }

    virtual void jtag_reset_master (void) {
        jtag_reset();
        jtag_softreset();
    }

    virtual void write_tms(bool val) {
        m_dut->jtag_tms_i = val;
        jtag_tick();
    }

    virtual void write_bits (uint32_t wdata, uint32_t size, bool tms_last) {
        for (int i = 0; i < size; i++){
            m_dut->jtag_td_i = (wdata >> i) & 0x1;
            if (i == size-1) m_dut->jtag_tms_i = tms_last;
            jtag_tick();
        }
        m_dut->jtag_tms_i = 0;
    }

    virtual void set_ir(uint32_t opcode) {
        write_tms(1); // select DR scan
        write_tms(1); // select IR scan
        write_tms(0); // capture IR
        write_tms(0); // shift IR
        write_bits(opcode, 5, 1);
        write_tms(1); // update IR
        write_tms(0); // run test idle
    }

    virtual void shift_dr(void) {
        write_tms(1); // select DR scan
        write_tms(0); // capture DR
        write_tms(0); // shift DR
    }

    virtual uint64_t readwrite_bits(uint64_t wdata, uint32_t size, bool tms_last) {
        uint32_t res = 0;

        for (int i = 0; i < size; i++) {
            m_dut->jtag_td_i = (wdata >> i) & 0x1;
            if (i == size-1) m_dut->jtag_tms_i = tms_last;
            jtag_tick();
            res |= (m_dut->jtag_td_o << i) & (0x1 << i);
        }
        return res;
    }

    virtual void update_dr(bool exit_1_dr) {
        // depending on the state `exit_1_dr` is already reached when shifting data (`tms_on_last`).
        if (exit_1_dr) write_tms(1);
        write_tms(1);   // update DR
        write_tms(0);   // run test idle
    }

    virtual uint32_t get_idcode(uint32_t idcode) {
        uint32_t wdata = 0;
        set_ir(idcode);
        shift_dr();
        uint32_t res = readwrite_bits(wdata, 32, 0);
        update_dr(1);
        return res;
    }

    virtual void jtag_write_dmi(uint8_t csr_addr, uint32_t data) {
        const uint32_t DMIWidth = 7 + 2 + 32; // addr + op + data
        const uint8_t  DtmWrite  = 0b11;
        const uint32_t DmiAccess = 0b10001;
        uint64_t write_data = 0;
        write_data |= (DtmWrite << 0);  // op
        write_data |= (data     << 2);  // data
        write_data |= ((uint64_t) csr_addr << 34); // addr
        set_ir(DmiAccess);
        shift_dr();
        write_bits(write_data, DMIWidth, 1);
        update_dr(0);

    }

    virtual void jtag_write(uint8_t csr_addr, uint32_t data, 
                            bool wait_cmd = 0, bool wait_sba = 0){
        const uint8_t AbstractCSAddr = 0x16;
        const uint8_t SbcsAddr       = 0x38;
        jtag_write_dmi(csr_addr, data);
        if (wait_cmd) {
            uint32_t acs      = 0;
            uint8_t  acs_busy = 0;
            do {
                acs = jtag_read_dmi_exp_backoff(AbstractCSAddr);
                uint8_t acs_err  = (acs >> 8)  & 0b111;
                acs_busy = (acs >> 12) & 0b1;
                if(acs_err) printf("[ERROR] Abstract command error!\n");
            } while (acs_busy);
        }
        if (wait_sba) {
            uint32_t sbcs   = 0;
            uint8_t  sbbusy = 0;
            do {
                sbcs = jtag_read_dmi_exp_backoff(SbcsAddr);
                uint8_t sberror     = (sbcs >> 12) & 0b111;
                uint8_t sbbusyerror = (sbcs >> 22) & 0b1;
                sbbusy              = (sbcs >> 21) & 0b1;
                if (sberror | sbbusyerror ) printf("[ERROR] System bus error!\n");
            } while (sbbusy);
        }
    }

    virtual void wait_idle (uint32_t wait_cycles) {
        for (int i = 0; i<wait_cycles; i++) jtag_tick();
    }

    virtual void write_dtmcs(uint32_t data) {
        const uint32_t DtmCsr = 0b10000;
        set_ir(DtmCsr);
        shift_dr();
        write_bits(data, 32, 1);
        update_dr(0);
    }

    virtual void reset_dmi(void) {
        uint32_t dmireset = 1 << 16;
        write_dtmcs(dmireset);
    }

    virtual uint64_t jtag_read_dmi (uint8_t addr, uint32_t wait_cycles) {
        const uint32_t DMIWidth = 7 + 2 + 32; // addr + op + data
        const uint8_t  DtmNop    = 0b00;
        const uint8_t  DtmRead   = 0b01;
        const uint32_t DmiAccess = 0b10001;
        uint64_t write_data = 0;
        write_data |= (DtmRead << 0);  // op
        //write_data |= (data  << 2);  // data = 0
        write_data |= ((uint64_t) addr << 34); // addr
        set_ir(DmiAccess);
        // send read command
        shift_dr();
        printf("writedata1 : %016lx\n", write_data);
        write_bits(write_data, DMIWidth, 1);
        update_dr(0);
        wait_idle(wait_cycles);
        // shift out read data
        shift_dr();
        write_data = 0;
        write_data |= (DtmNop << 0);  // op
        //write_data |= (data << 2);  // data = 0
        write_data |= ((uint64_t) addr << 34); // addr
        printf("writedata1 : %016lx\n", write_data);
        uint64_t data_out = readwrite_bits(write_data, DMIWidth, 1);
        update_dr(0);
        printf("data out: %x\n", data_out);

        return data_out;
    }

    virtual uint32_t jtag_read_dmi_exp_backoff (uint8_t addr) {
        const uint8_t DtmSuccess = 0b00;
        const uint8_t DtmBusy    = 0b11;
        uint64_t read_data       = 0;
        uint32_t read_result     = 0;
        uint32_t trial_idx       = 0;
        uint32_t wait_cycles     = 8;
        uint8_t  op              = DtmSuccess;

        do
        {
            if (trial_idx != 0){
                // Not entered upon first iteration, resets the
                // sticky error state if previous read was unsuccessful
                reset_dmi();
            }
            read_data = jtag_read_dmi(addr, wait_cycles);
            op = read_data & 0b11;
            read_result = (uint32_t)(read_data>>2);
            wait_cycles *= 2;
            trial_idx++;
        } while ( op == DtmBusy );
        
        return read_result;
    }

    virtual void jtag_init (void) {
        printf("[JTAG] perform init \t-\t time %ld\n", m_tickcount);
        const uint32_t IdCodeInstr = 0b00001;
        const uint32_t IdCode      = 0xfeedc0d3;

        for (int i=0;i<100;i++) jtag_tick();
        uint32_t idcode = get_idcode(IdCodeInstr);

        if (idcode != IdCode)
            printf("[JTAG] idcode ERROR: read %x, expected %x\n", idcode, IdCode);
        else
            printf("[JTAG] idcode %x OK\n", idcode);

        // Activate, wait for debug module
        const uint8_t  DMControlAddr = 0x10;
        uint32_t       DMControlData = 0;
        DMControlData               |= 0x1; // set dmactive [bit 0] 
        jtag_write(DMControlAddr, DMControlData);
        uint32_t dmcontrol = 0; 
        bool  dmcontrol_active = 0;
        int test = 0;
        do{
            dmcontrol = jtag_read_dmi_exp_backoff(DMControlAddr);
            dmcontrol_active = dmcontrol & 0x1;
            printf("dmcontrol: %08x\n", dmcontrol);
            test++;
        }while(test<10);//!dmcontrol_active);



        printf("[JTAG] init ok      \t-\t time %ld\n", m_tickcount);

    }

    
    virtual void jtag_memory_test (void) {
        
    }

    virtual void jtag_load_elf (void) {

    }

    virtual void jtag_wait_eoc (void) {
        
    }
};