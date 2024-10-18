pub const CLIC_BASE_ADDR: usize = 0x50000;

/* Register width */
pub const CLIC_PARAM_REG_WIDTH: usize = 8;

/* CLIC Configuration */
pub const CLIC_CLICCFG_REG_OFFSET: usize = 0x0;
pub const CLIC_CLICCFG_NVBITS_BIT: usize = 0;
pub const CLIC_CLICCFG_NLBITS_MASK: usize = 0xf;
pub const CLIC_CLICCFG_NLBITS_OFFSET: usize = 1;
pub const CLIC_CLICCFG_NMBITS_MASK: usize = 0x3;
pub const CLIC_CLICCFG_NMBITS_OFFSET: usize = 5;

/* CLIC Information */
pub const CLIC_CLICINFO_REG_OFFSET: usize = 0x4;
pub const CLIC_CLICINFO_NUM_INTERRUPT_MASK: usize = 0x1fff;
pub const CLIC_CLICINFO_NUM_INTERRUPT_OFFSET: usize = 0;

pub const CLIC_CLICINFO_VERSION_MASK: usize = 0xff;
pub const CLIC_CLICINFO_VERSION_OFFSET: usize = 13;

pub const CLIC_CLICINFO_CLICINTCTLBITS_MASK: usize = 0xf;
pub const CLIC_CLICINFO_CLICINTCTLBITS_OFFSET: usize = 21;

pub const CLIC_CLICINFO_NUM_TRIGGER_MASK: usize = 0x3f;
pub const CLIC_CLICINFO_NUM_TRIGGER_OFFSET: usize = 25;

/* CLIC Interrupt Trigger */
pub const fn CLIC_INTTRIGG_REG_OFFSET(id: usize) -> usize {
    0x40 + 0x4 * id
}
pub const CLIC_INTTRIGG_ENABLE_BIT: usize = 31;
pub const CLIC_INTTRIGG_INT_NUMBER_OFFSET: usize = 0;
pub const CLIC_INTTRIGG_INT_NUMBER_MASK: usize = 0xFFF;

/* CLIC Interrupt registers (4-bytes) */
pub const fn CLIC_INTREG_OFFSET(id: u32) -> usize {
    0x1000 + 0x4 * id as usize
}

/* CLIC enable mnxti irq forwarding logic */
pub const CLIC_CLICXNXTICONF_REG_OFFSET: usize = 0x8;
pub const CLIC_CLICXNXTICONF_CLICXNXTICONF_BIT: usize = 0;

/* CLIC interrupt id pending */
pub const CLIC_CLICINTIE_IP_BIT: usize = 0;
pub const CLIC_CLICINTIE_IP_MASK: usize = 0x1;

/* CLIC interrupt id enable */
pub const CLIC_CLICINTIE_IE_BIT: usize = 8;
pub const CLIC_CLICINTIE_IE_MASK: usize = 0x1;

/* CLIC interrupt id attributes */
pub const CLIC_CLICINTATTR_SHV_MASK: usize = 0x1;
pub const CLIC_CLICINTATTR_SHV_BIT: usize = 16;
pub const CLIC_CLICINTATTR_TRIG_MASK: usize = 0x3;
pub const CLIC_CLICINTATTR_TRIG_OFFSET: usize = 17;
pub const CLIC_CLICINTATTR_MODE_MASK: usize = 0x3;
pub const CLIC_CLICINTATTR_MODE_OFFSET: usize = 22;
