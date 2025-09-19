use crate::PQueue;

impl PQueue for bsp::timer_queue::TimerQueue {
    type Entry = bsp::timer_queue::Entry;

    #[inline(always)]
    fn enqueue_rel(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| todo!())
    }

    #[inline(always)]
    fn enqueue_abs(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| todo!())
    }

    #[inline(always)]
    fn drop(&mut self, handle: u8) {
        bsp::riscv::interrupt::free(|| todo!());
    }
}
