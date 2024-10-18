use crate::mmap::LED_ADDR;
use crate::{read_u32, write_u32};

#[derive(Clone, Copy)]
#[repr(u32)]
pub enum Led {
    Ld0 = 0b1,
    Ld1 = 0b1 << 8,
    Ld2 = 0b1 << 16,
    Ld3 = 0b1 << 24,
}

#[inline]
pub fn led_on(led: Led) {
    write_u32(LED_ADDR, read_u32(LED_ADDR) | led as u32);
}

#[inline]
pub fn led_off(led: Led) {
    write_u32(LED_ADDR, read_u32(LED_ADDR) & !(led as u32));
}

#[inline]
pub fn led_toggle(led: Led) {
    write_u32(LED_ADDR, read_u32(LED_ADDR) ^ led as u32);
}

#[inline]
pub fn led_set(led: Led, set: bool) {
    if set {
        write_u32(LED_ADDR, read_u32(LED_ADDR) | led as u32);
    } else {
        write_u32(LED_ADDR, read_u32(LED_ADDR) & !(led as u32));
    }
}
