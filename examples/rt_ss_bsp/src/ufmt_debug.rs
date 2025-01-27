use ufmt::uDebug;

struct Mstatus(riscv::register::mstatus::Mstatus);

impl From<riscv::register::mstatus::Mstatus> for Mstatus {
    fn from(value: riscv::register::mstatus::Mstatus) -> Self {
        Self(value)
    }
}

impl uDebug for Mstatus {
    fn fmt<W>(&self, f: &mut ufmt::Formatter<'_, W>) -> Result<(), W::Error>
    where
        W: ufmt::uWrite + ?Sized,
    {
        f.debug_struct("Mstatus")?
            .field("sie", &self.0.sie())?
            .field("mie", &self.0.mie())?
            .field("spie", &self.0.spie())?
            .field("ube", &(self.0.ube() as u8))?
            .field("mpie", &self.0.mpie())?
            .field("spp", &(self.0.spp() as u8))?
            .field("mpp", &(self.0.mpp() as u8))?
            .field("fs", &(self.0.fs() as u8))?
            .field("xs", &(self.0.xs() as u8))?
            .field("mprv", &self.0.mprv())?
            .field("sum", &self.0.sum())?
            .field("mxr", &self.0.mxr())?
            .field("tvm", &self.0.tvm())?
            .field("tw", &self.0.tw())?
            .field("tsr", &self.0.tsr())?
            .field("uxl", &(self.0.uxl() as u8))?
            .field("sxl", &(self.0.sxl() as u8))?
            .field("sbe", &(self.0.sbe() as u8))?
            .field("mbe", &(self.0.mbe() as u8))?
            .field("sd", &self.0.sd())?
            .finish()
    }
}

impl uDebug for crate::Interrupt {
    fn fmt<W>(&self, f: &mut ufmt::Formatter<'_, W>) -> Result<(), W::Error>
    where
        W: ufmt::uWrite + ?Sized,
    {
        f.write_str(match self {
            crate::Interrupt::MachineSoft => "MachineSoft",
            crate::Interrupt::MachineTimer => "MachineTimer",
            crate::Interrupt::MachineExternal => "MachineExternal",
            crate::Interrupt::Uart => "Uart",
            crate::Interrupt::Gpio => "Gpio",
            crate::Interrupt::SpiRxTxIrq => "SpiRxTxIrq",
            crate::Interrupt::SpiEotIrq => "SpiEotIrq",
            crate::Interrupt::Timer0Ovf => "Timer0Ovf",
            crate::Interrupt::Timer0Cmp => "Timer0Cmp",
            crate::Interrupt::Timer1Ovf => "Timer1Ovf",
            crate::Interrupt::Timer1Cmp => "Timer1Cmp",
            crate::Interrupt::Timer2Ovf => "Timer2Ovf",
            crate::Interrupt::Timer2Cmp => "Timer2Cmp",
            crate::Interrupt::Timer3Ovf => "Timer3Ovf",
            crate::Interrupt::Timer3Cmp => "Timer3Cmp",
            crate::Interrupt::Nmi => "Nmi",
            crate::Interrupt::Dma0 => "Dma0",
            crate::Interrupt::Dma1 => "Dma1",
            crate::Interrupt::Dma2 => "Dma2",
            crate::Interrupt::Dma3 => "Dma3",
            crate::Interrupt::Dma4 => "Dma4",
            crate::Interrupt::Dma5 => "Dma5",
            crate::Interrupt::Dma6 => "Dma6",
            crate::Interrupt::Dma7 => "Dma7",
            crate::Interrupt::Dma8 => "Dma8",
            crate::Interrupt::Dma9 => "Dma9",
            crate::Interrupt::Dma10 => "Dma10",
            crate::Interrupt::Dma11 => "Dma11",
            crate::Interrupt::Dma12 => "Dma12",
            crate::Interrupt::Dma13 => "Dma13",
            crate::Interrupt::Dma14 => "Dma14",
            crate::Interrupt::Dma15 => "Dma15",
        })
    }
}
