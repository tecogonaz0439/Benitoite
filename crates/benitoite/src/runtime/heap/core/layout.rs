//! 対象の頭に続く中身の配置（設計書 02-08「値の表現」、ADR 0258・0281）。
//! H1・H10 と O2: 不変の種類と長さから確保時と読み出し時に同じ配置を計算する。
//! L1: 頭と中身は重ならず、offset は中身の整列を満たし、全体の Layout の中に収まる。
//! L2: 長さの乗算、頭との加算、切り上げを検査し、全体は u32 の範囲に限る。

// 中身の開始ポインタを計算する内部の層である（ADR 0260）。
#![allow(unsafe_code)]

use super::super::value::{HostData, ObjKind, OpaqueData, Value};
use super::{ObjHeader, size_overflow};
use crate::base::Decimal;
use crate::runtime::Stop;
use std::alloc::Layout;
use std::cell::Cell;
use std::ptr::NonNull;

/// 区間の寿命を外した値だけを内部に保ち、書き込みは公開層の障壁を経由する（H6・H7）。
#[repr(C)]
pub(in crate::runtime::heap) struct CellPayload {
    pub(in crate::runtime::heap) value: Cell<Value<'static>>,
    pub(in crate::runtime::heap) version: Cell<u64>,
}

pub(super) const FIELD_BYTES: usize = std::mem::size_of::<Value<'static>>();
pub(super) const CELL_BYTES: usize = std::mem::size_of::<CellPayload>();
pub(super) const DECIMAL_BYTES: usize = std::mem::size_of::<Decimal>();
pub(super) const BOX_BYTES: usize = std::mem::size_of::<Box<dyn OpaqueData>>();
const _: () = assert!(BOX_BYTES == std::mem::size_of::<Box<dyn HostData>>());

#[derive(Clone, Copy)]
pub(super) struct ObjectLayout {
    pub(super) layout: Layout,
    pub(super) offset: usize,
    pub(super) kind: ObjKind,
    pub(super) len: u32,
    pub(super) tag: u32,
}

impl ObjectLayout {
    pub(super) fn new(kind: ObjKind, len: u32, tag: u32) -> Result<Self, Stop> {
        let n = usize::try_from(len).map_err(|_| size_overflow())?;
        let body = match kind {
            ObjKind::Str | ObjKind::Bytes => Layout::array::<u8>(n),
            ObjKind::Fields(_) => Layout::array::<Value<'static>>(n),
            ObjKind::Decimal => {
                if len != 1 {
                    return Err(size_overflow());
                }
                Ok(Layout::new::<Decimal>())
            }
            ObjKind::Cell => {
                if len != 1 {
                    return Err(size_overflow());
                }
                Ok(Layout::new::<CellPayload>())
            }
            ObjKind::Opaque => {
                if len != 1 {
                    return Err(size_overflow());
                }
                Ok(Layout::new::<Box<dyn OpaqueData>>())
            }
            ObjKind::Host => {
                if len != 1 {
                    return Err(size_overflow());
                }
                Ok(Layout::new::<Box<dyn HostData>>())
            }
        }
        .map_err(|_| size_overflow())?;
        let (layout, offset) = Layout::new::<ObjHeader>()
            .extend(body)
            .map_err(|_| size_overflow())?;
        let layout = layout.pad_to_align();
        // 頭の長さは u32 なので、全体の計算にも同じ上限を置き巨大な誤った要求を確保前に拒む（L2）。
        u32::try_from(layout.size()).map_err(|_| size_overflow())?;
        Ok(Self {
            layout,
            offset,
            kind,
            len,
            tag,
        })
    }

    pub(super) fn payload(self, ptr: NonNull<u8>) -> NonNull<u8> {
        // SAFETY: O2・L1。ptr はこの Layout 以上の領域の先頭。空の中身では末尾も許す。
        unsafe { ptr.add(self.offset) }
    }
}
