use crate::{Entry, PQueue};
use bsp::timer_queue::TimerQueue;

pub struct VQueue<const Q_LEN: usize, const B_LEN: usize> {
    pub tq: bsp::timer_queue::TimerQueue,
    pub bq: heapless::Deque<Entry, B_LEN>,
    pub bq_dropq: heapless::FnvIndexSet<u8, B_LEN>,
    pub free_handles: heapless::Deque<u8, B_LEN>,
}

impl<const Q_LEN: usize, const B_LEN: usize> Default for VQueue<Q_LEN, B_LEN> {
    fn default() -> Self {
        let tq = TimerQueue::init();

        let mut free_handles = heapless::Deque::new();
        let handle_bounds = tq.capacity()..(tq.capacity() + B_LEN as u32);
        for h in handle_bounds {
            free_handles.push_back(h as u8).unwrap()
        }

        Self {
            tq,
            bq: heapless::Deque::new(),
            bq_dropq: heapless::FnvIndexSet::new(),
            free_handles,
        }
    }
}

const MSG_BQ_OVF: &str = "backup queue overflow";

impl<const Q_LEN: usize, const B_LEN: usize> PQueue for VQueue<Q_LEN, B_LEN> {
    type Entry = bsp::timer_queue::Entry;

    #[inline(always)]
    fn enqueue_rel(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| {
            if !self.tq.is_full() {
                return self.tq.push_rel(entry);
            }

            // If queue is full, retrieve bottom element
            let btm = self.tq.drop(self.tq.btm_idx());

            let ts = bsp::mtimer::MTimer::instance().counter() + entry.ts;
            // If incoming is more urgent than 'bottom'
            if ts <= btm.ts {
                // Bottom => backup
                // Incoming => HW
                let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };
                self.bq
                    .push_back(Entry::with_handle(btm, h))
                    .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));

                self.tq.push_rel(entry)
            }
            // If bottom is more urgent than incoming
            else {
                // Bottom => HW
                // Incoming => backup
                self.tq.push_abs(btm);
                let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };
                self.bq
                    .push_back(Entry::with_handle(entry, h))
                    .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));
                h
            }
        })
    }

    #[inline(always)]
    fn enqueue_abs(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| {
            if !self.tq.is_full() {
                return self.tq.push_abs(entry);
            }

            // If queue is full, retrieve bottom element
            let btm = self.tq.drop(self.tq.btm_idx());

            let ts = entry.ts;
            // If incoming is more urgent than 'bottom'
            if ts <= btm.ts {
                // Bottom => backup
                // Incoming => HW
                let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };
                self.bq
                    .push_back(Entry::with_handle(btm, h))
                    .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));

                self.tq.push_rel(entry)
            }
            // If bottom is more urgent than incoming
            else {
                // Bottom => HW
                // Incoming => backup
                self.tq.push_abs(btm);
                let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };
                self.bq
                    .push_back(Entry::with_handle(entry, h))
                    .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));
                h
            }
        })
    }

    #[inline(always)]
    fn drop(&mut self, handle: u8) {
        bsp::riscv::interrupt::free(|| {
            if (handle as usize) < Q_LEN {
                // Drop from main queue (HW)
                self.tq.drop(handle);
            } else {
                // Record element should be dropped from backup (virtual backup)
                unsafe { self.bq_dropq.insert(handle).unwrap_unchecked() };
            }
        })
    }
}
