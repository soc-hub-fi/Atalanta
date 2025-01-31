//! Haphazard thin API for blinking leds, based on [GpioLo]
//!
//! Each API call here also inits the leds as appropriate, incurring some
//! overhead.
use crate::gpio::GpioLo;
use bitmask_enum::bitmask;

/// Matches layout of bits in [GpioLo]
#[bitmask(u32)]
pub enum Led {
    Ld0 = 0b1,
    Ld1 = 0b1 << 8,
    Ld2 = 0b1 << 16,
    Ld3 = 0b1 << 24,
}

#[inline]
pub fn led_on(led: Led) {
    // Init
    let bits = led.bits;
    GpioLo::en(bits);
    GpioLo::set_output(bits);

    // Actuate
    GpioLo::set_high(bits);
}

#[inline]
pub fn led_off(led: Led) {
    // Init
    let bits = led.bits;
    GpioLo::en(bits);
    GpioLo::set_output(bits);

    // Actuate
    GpioLo::set_low(led.bits);
}

#[inline]
pub fn led_toggle(led: Led) {
    // Init
    let bits = led.bits;
    GpioLo::en(bits);
    GpioLo::set_output(bits);

    // Actuate
    GpioLo::toggle(led.bits);
}

#[inline]
pub fn led_set(led: Led, set: bool) {
    if set {
        led_on(led);
    } else {
        led_off(led);
    }
}
