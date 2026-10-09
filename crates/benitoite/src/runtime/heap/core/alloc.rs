//! 塊と大きさ別の空き領域を管理する非移動の確保器（設計書 02-09「メモリの管理」、ADR 0260）。
//! H1・H2・H10: 確保は対象を動かさず、返却は HeapCore の可変借用からだけ行う。
//! A1: Region は記録した Layout で一度確保し、その所有者だけが同じ Layout で一度返す。
//! A2: 塊の切り出しと空きの並びは、重ならない整列済みの範囲だけを返す。
//! A3: Allocation の返却は一度だけで、まだ借用された中身を持たない（O4）。
//! A4: 個別の領域の添字は separate の所有者を指し、返却後だけ vacant に一度置く。

// 生の領域を取得・分割・返却する内部の層である（ADR 0260）。
#![allow(unsafe_code)]

use super::size_overflow;
use crate::runtime::Stop;
use std::alloc::{Layout, alloc, dealloc, handle_alloc_error};
use std::ptr::NonNull;

pub(super) const ALIGN: usize = 16;
pub(super) const CHUNK_BYTES: usize = 65_536;
pub(super) const SIZE_CLASSES: [usize; 14] = [
    32, 64, 96, 128, 192, 256, 384, 512, 768, 1024, 1536, 2048, 3072, 4096,
];

struct Region {
    ptr: NonNull<u8>,
    layout: Layout,
}

impl Region {
    fn new(layout: Layout) -> Self {
        // SAFETY: A1。Layout は検査済みで大きさは正、返された領域を Region が一意に所有する。
        let raw = unsafe { alloc(layout) };
        let Some(ptr) = NonNull::new(raw) else {
            handle_alloc_error(layout)
        };
        Self { ptr, layout }
    }
}

impl Drop for Region {
    fn drop(&mut self) {
        // SAFETY: A1・A3。Region は写さず、確保時の Layout で一度だけ返す。対象の借用は終わっている。
        unsafe { dealloc(self.ptr.as_ptr(), self.layout) };
    }
}

#[cfg(not(feature = "heap-per-object"))]
struct Chunk {
    region: Region,
    used: usize,
}

#[derive(Clone, Copy)]
pub(super) struct Allocation {
    pub(super) ptr: NonNull<u8>,
    pub(super) capacity: usize,
    #[cfg(not(feature = "heap-per-object"))]
    class: Option<usize>,
    separate_index: Option<usize>,
}

pub(super) struct Allocator {
    // 個別の領域も所有者を並びに残すので、Rust の中身の drop が panic しても記憶域は返る。
    separate: Vec<Option<Region>>,
    vacant: Vec<usize>,
    #[cfg(not(feature = "heap-per-object"))]
    chunks: Vec<Chunk>,
    #[cfg(not(feature = "heap-per-object"))]
    free: [Vec<NonNull<u8>>; SIZE_CLASSES.len()],
}

impl Allocator {
    pub(super) fn new() -> Self {
        Self {
            separate: Vec::new(),
            vacant: Vec::new(),
            #[cfg(not(feature = "heap-per-object"))]
            chunks: Vec::new(),
            #[cfg(not(feature = "heap-per-object"))]
            free: std::array::from_fn(|_| Vec::new()),
        }
    }

    fn checked_layout(layout: Layout) -> Result<Layout, Stop> {
        if layout.size() == 0 || layout.align() > ALIGN {
            return Err(size_overflow());
        }
        let size = layout
            .size()
            .checked_add(ALIGN.saturating_sub(1))
            .ok_or_else(size_overflow)?
            & !ALIGN.saturating_sub(1);
        Layout::from_size_align(size, ALIGN).map_err(|_| size_overflow())
    }

    pub(super) fn capacity(layout: Layout) -> Result<usize, Stop> {
        let layout = Self::checked_layout(layout)?;
        #[cfg(not(feature = "heap-per-object"))]
        if let Some(capacity) = SIZE_CLASSES
            .iter()
            .find(|capacity| **capacity >= layout.size())
        {
            return Ok(*capacity);
        }
        Ok(layout.size())
    }

    pub(super) fn allocate(&mut self, layout: Layout) -> Result<Allocation, Stop> {
        let layout = Self::checked_layout(layout)?;
        #[cfg(not(feature = "heap-per-object"))]
        if let Some(class) = SIZE_CLASSES
            .iter()
            .position(|capacity| *capacity >= layout.size())
        {
            let capacity = *SIZE_CLASSES.get(class).ok_or_else(size_overflow)?;
            if let Some(ptr) = self.free.get_mut(class).and_then(Vec::pop) {
                return Ok(Allocation {
                    ptr,
                    capacity,
                    class: Some(class),
                    separate_index: None,
                });
            }
            if !self.chunks.last().is_some_and(|chunk| {
                chunk
                    .used
                    .checked_add(capacity)
                    .is_some_and(|end| end <= CHUNK_BYTES)
            }) {
                let chunk_layout =
                    Layout::from_size_align(CHUNK_BYTES, ALIGN).map_err(|_| size_overflow())?;
                self.chunks.push(Chunk {
                    region: Region::new(chunk_layout),
                    used: 0,
                });
            }
            let chunk = self.chunks.last_mut().ok_or_else(size_overflow)?;
            let end = chunk
                .used
                .checked_add(capacity)
                .filter(|end| *end <= CHUNK_BYTES)
                .ok_or_else(size_overflow)?;
            // SAFETY: A1・A2。used と end は塊の範囲内、区分と used は ALIGN の倍数で、未使用の領域である。
            let raw = unsafe { chunk.region.ptr.as_ptr().add(chunk.used) };
            let ptr = NonNull::new(raw).ok_or_else(size_overflow)?;
            chunk.used = end;
            return Ok(Allocation {
                ptr,
                capacity,
                class: Some(class),
                separate_index: None,
            });
        }
        let region = Region::new(layout);
        let index = self.vacant.pop().unwrap_or(self.separate.len());
        let allocation = Allocation {
            ptr: region.ptr,
            capacity: layout.size(),
            #[cfg(not(feature = "heap-per-object"))]
            class: None,
            separate_index: Some(index),
        };
        if let Some(slot) = self.separate.get_mut(index) {
            *slot = Some(region);
        } else {
            self.separate.push(Some(region));
        }
        Ok(allocation)
    }

    /// HeapCore が生きている対象の並びから取り除いた領域だけを一度返す（A3）。
    pub(super) fn release(&mut self, allocation: Allocation) {
        #[cfg(not(feature = "heap-per-object"))]
        if let Some(class) = allocation.class {
            if let Some(free) = self.free.get_mut(class) {
                free.push(allocation.ptr);
            }
            return;
        }
        if let Some(index) = allocation.separate_index
            && let Some(slot) = self.separate.get_mut(index)
        {
            let region = slot.take();
            self.vacant.push(index);
            drop(region);
        }
    }
}
