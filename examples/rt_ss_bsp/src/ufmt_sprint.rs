use crate::uart::ApbUart;

#[macro_export]
macro_rules! sprint {
    ($s:expr) => {{
        ufmt::uwrite!($crate::uart::ApbUart {}, $s).unwrap()
    }};
    ($($tt:tt)*) => {{
        ufmt::uwrite!($crate::uart::ApbUart, $($tt)*).unwrap()
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

impl ufmt::uWrite for ApbUart {
    type Error = core::convert::Infallible;

    fn write_str(&mut self, s: &str) -> Result<(), Self::Error> {
        ApbUart::write_str(self, s);
        Ok(())
    }
}
