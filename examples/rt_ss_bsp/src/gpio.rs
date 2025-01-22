use crate::{
    mmap::gpio::{RegisterBlock, GPIO_BASE},
    write_u32,
};

pub struct GpioHal<const BASE_ADDR: usize>;

/// [GpioHal]
pub type Gpio = GpioHal<GPIO_BASE>;

impl<const BASE_ADDR: usize> GpioHal<BASE_ADDR> {}
