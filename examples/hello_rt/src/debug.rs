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
