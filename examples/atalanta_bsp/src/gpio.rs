use crate::{
    mask_u32,
    mmap::gpio::{RegisterBlock, GPIO_BASE},
    toggle_u32, unmask_u32,
};
use core::mem;

pub const GPIO_LO_BASE: usize = GPIO_BASE;
pub const GPIO_HI_BASE: usize = GPIO_BASE + 0x38;

pub struct GpioHal<const BASE_ADDR: usize>;

/// Pins 0..=31, sa. [GpioHal]
pub type GpioLo = GpioHal<GPIO_LO_BASE>;
/// Pins 32..=63, sa. [GpioHal]
pub type GpioHi = GpioHal<GPIO_HI_BASE>;

impl<const BASE_ADDR: usize> GpioHal<BASE_ADDR> {
    /// Enable clocks
    pub fn en(mask: u32) {
        let gpio = GPIO_BASE as *mut RegisterBlock;

        // Enable clocks for gpios 0..=3
        mask_u32(unsafe { mem::transmute(&mut (*gpio).pads[0].en) }, mask);
    }

    /// Set GPIOs as output
    pub fn set_output(mask: u32) {
        let gpio = GPIO_BASE as *mut RegisterBlock;

        // Set DIR = 1 (output)
        mask_u32(unsafe { mem::transmute(&mut (*gpio).pads[0].dir) }, mask);
    }

    /// Set GPIOs as input
    pub fn set_input(mask: u32) {
        let gpio = GPIO_BASE as *mut RegisterBlock;

        // Set DIR = 0 (input)
        unmask_u32(unsafe { mem::transmute(&mut (*gpio).pads[0].dir) }, mask);
    }

    pub fn set_high(mask: u32) {
        let gpio = GPIO_BASE as *mut RegisterBlock;
        mask_u32(
            unsafe { mem::transmute(&mut (*gpio).pads[0].data_out) },
            mask,
        );
    }

    pub fn set_low(mask: u32) {
        let gpio = GPIO_BASE as *mut RegisterBlock;
        unmask_u32(
            unsafe { mem::transmute(&mut (*gpio).pads[0].data_out) },
            mask,
        );
    }

    pub fn toggle(mask: u32) {
        let gpio = GPIO_BASE as *mut RegisterBlock;
        toggle_u32(
            unsafe { mem::transmute(&mut (*gpio).pads[0].data_out) },
            mask,
        );
    }
}
