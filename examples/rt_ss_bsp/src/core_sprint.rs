use crate::uart::uart_write;

pub struct Uart;

#[macro_export]
macro_rules! sprint {
    ($s:expr) => {{
        use core::fmt::Write;
        write!($crate::sprint::Uart {}, $s).unwrap()
    }};
    ($($tt:tt)*) => {{
        use core::fmt::Write;
        write!($crate::sprint::Uart, $($tt)*).unwrap()
    }};
}

#[macro_export]
macro_rules! sprintln {
    () => {{
        use $crate::sprint;
        sprint!("\r\n");
    }};
    // IMPORTANT use `tt` fragments instead of `expr` fragments (i.e. `$($exprs:expr),*`)
    ($($tt:tt)*) => {{
        use $crate::sprint;
        sprint!($($tt)*);
        sprint!("\r\n");
    }};
}

impl core::fmt::Write for Uart {
    fn write_str(&mut self, s: &str) -> Result<(), core::fmt::Error> {
        uart_write(s);
        Ok(())
    }
}
