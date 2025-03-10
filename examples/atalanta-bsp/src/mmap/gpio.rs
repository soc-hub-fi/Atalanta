//! Register maps for [PULP APB GPIO](https://github.com/pulp-platform/apb_gpio/) (v0.2.0)
//!
//! Based on [Excel](https://github.com/pulp-platform/apb_gpio/blob/master/docs/APB_reference.xlsx)

pub const GPIO_BASE: usize = 0x3_0000;

#[repr(C)]
pub struct RegisterBlock {
    /// Platform implements two sets of 32 GPIO pins (offset 0x00..0x64)
    pub pads: [PadRegisterBlock; 2],
}

#[repr(C)]
pub struct PadRegisterBlock {
    /// GPIO pad direction configuration register (offset 0x00..0x04)
    ///
    /// `GPIO[31:0]` direction configuration bitfield:
    ///
    /// - `bit[i] = 0b0`: Input mode for `GPIO[i]`
    /// - `bit[i] = 0b1`: Output mode for `GPIO[i]`
    pub dir: u32,

    /// GPIO enable register (offset 0x04..0x08)
    ///
    /// `GPIO[31:0]` clock enable configuration bitfield:
    ///
    /// - `bit[i] = 0b0`: disable clock for `GPIO[i]`
    /// - `bit[i] = 0b1`: enable clock for `GPIO[i]`
    ///
    /// GPIOs are gathered by groups of 4. The clock gating of one group is done
    /// only if all 4 GPIOs are disabled. Clock must be enabled for a GPIO
    /// if it's direction is configured in input mode.
    pub en: u32,

    /// GPIO pad input value register (offset 0x08..0x0C) read only
    ///
    /// `GPIO[31:0]` input data read bitfield. `data_in[i]` corresponds to input
    /// data of `GPIO[i]`.
    pub data_in: u32,

    /// GPIO pad output value register (offset 0x0C..0x10)
    ///
    /// `GPIO[31:0]` output data read bitfield. `data_out[i]` corresponds to
    /// output data set on `GPIO[i]`.
    pub data_out: u32,

    /// GPIO pad output set register (offset 0x10..0x14)
    ///
    /// `GPIO[31:0]` set bitfield:
    ///
    /// - `bit[i] = 0b0`: No change for `GPIO[i]`
    /// - `bit[i] = 0b1`: Sets `GPIO[i]` to 1
    pub out_set: u32,

    /// GPIO pad output clear register (offset 0x14..0x18)
    ///
    /// `GPIO[31:0]` clear bitfield:
    ///
    /// - `bit[i] = 0b0`: No change for `GPIO[i]`
    /// - `bit[i] = 0b1`: Clears `GPIO[i]`
    pub out_clr: u32,

    /// GPIO pad interrupt enable configuration register (offset 0x18..0x1C)
    ///
    /// `GPIO[31:0]` interrupt enable configuration bitfield:
    ///
    /// - `bit[i] = 0b0`: disable interrupt for `GPIO[i]`
    /// - `bit[i] = 0b1`: enable interrupt for `GPIO[i]`
    pub int_en: u32,

    /// GPIO pad interrupt type registers (offset 0x1C..0x24)
    ///
    /// `GPIO[31:0]` interrupt type configuration bitfield:
    ///
    /// - `bit[2*i+1 : 2*i] = 0b00`: interrupt on falling edge for `GPIO[i]`
    /// - `bit[2*i+1 : 2*i] = 0b01`: interrupt on rising edge for `GPIO[i]`
    /// - `bit[2*i+1 : 2*i] = 0b10`: interrupt on rising and falling edge for
    ///   `GPIO[i]`
    /// - `bit[2*i+1 : 2*i] = 0b11`: RFU
    pub int_type: [u32; 2],

    /// GPIO pad interrupt status register (offset 0x24..0x28)
    ///
    /// `GPIO[31:0]` Interrupt status flags bitfield. `INTSTATUS[i] = 1` when
    /// interrupt received on `GPIO[i]`. INTSTATUS is cleared when it is read.
    /// GPIO interrupt line is also cleared when INTSTATUS register is read.
    pub int_status: u32,

    /// GPIO pad configuration registers (offset 0x28..0x38)
    ///
    /// `GPIO[i]` pull activation & drive strength configuration bitfield:
    ///
    /// - `bit[8*i+1 : 8*i] = 0b0`: pull disabled
    /// - `bit[8*i+1 : 8*i] = 0b1`: pull enabled
    /// - `bit[8*i+5 : 8*i+4] = 0b0`: low drive strength
    /// - `bit[8*i+5 : 8*i+4] = 0b1`: high drive strength
    pub pad_cfg: [u32; 4],
}
