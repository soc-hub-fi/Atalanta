use riscv_peripheral::clic::InterruptNumber;

#[derive(Clone, Copy, PartialEq)]
#[repr(u16)]
pub enum Irq {
    SupervisorSoft = 1,
    MachineSoft = 3,
    SupervisorTimer = 5,
    MachineTimer = 7,
    SupervisorExternal = 9,
    MachineExternal = 11,

    Sixteen = 16,
    Seventeen = 17,
    // Reserved for clint NMI
    // Nmi = 31,
}

unsafe impl InterruptNumber for Irq {
    const MAX_INTERRUPT_NUMBER: u16 = 255;

    fn number(self) -> u16 {
        self as u16
    }

    fn from_number(value: u16) -> Result<Self, u16> {
        match value {
            1 => Ok(Self::SupervisorSoft),
            3 => Ok(Self::MachineSoft),
            5 => Ok(Self::SupervisorTimer),
            7 => Ok(Self::MachineTimer),
            9 => Ok(Self::SupervisorExternal),
            11 => Ok(Self::MachineExternal),
            16 => Ok(Self::Sixteen),
            17 => Ok(Self::Seventeen),
            _ => Err(value),
        }
    }
}
