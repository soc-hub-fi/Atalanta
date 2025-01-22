use crate::uart::ApbUart;

#[macro_export]
macro_rules! sprint {
    ($s:expr) => {{
        use core::fmt::Write;
        write!($crate::uart::ApbUart {}, $s).unwrap()
    }};
    ($($tt:tt)*) => {{
        use core::fmt::Write;
        write!($crate::uart::ApbUart, $($tt)*).unwrap()
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

impl core::fmt::Write for ApbUart {
    fn write_str(&mut self, s: &str) -> Result<(), core::fmt::Error> {
        ApbUart::write_str(self, s);
        Ok(())
    }
}
