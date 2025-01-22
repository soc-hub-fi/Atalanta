use crate::uart::ApbUartHal;

#[macro_export]
macro_rules! sprint {
    ($s:expr) => {{
        use core::fmt::Write;
        write!($crate::uart::ApbUartHal::<{ $crate::mmap::UART_BASE }> {}, $s).unwrap()
    }};
    ($($tt:tt)*) => {{
        use core::fmt::Write;
        write!($crate::uart::ApbUartHal::<{ $crate::mmap::UART_BASE }>, $($tt)*).unwrap()
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

impl<const BASE_ADDR: usize> core::fmt::Write for ApbUartHal<BASE_ADDR> {
    fn write_str(&mut self, s: &str) -> Result<(), core::fmt::Error> {
        ApbUartHal::write_str(self, s);
        Ok(())
    }
}
