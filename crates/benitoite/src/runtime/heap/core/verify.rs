//! ヒープの頭と到達先を安全点で検査する（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
//! H2・H4・H5: 区間の外で、根と全対象の内部参照を検査する。到達先は明示の積み重ねで辿る。
//! O1・O2・O4: 生存対象一覧の頭と配置を先に検査し、検査中は確保・解放・書き換えを行わない。
//! O5: 参照先の世代は領域外の表で確かめ、死んだ対象の頭や中身を読まない。

// 検査済みの頭と Host の所有値だけを内部層で読む（設計書 02-09「メモリの管理」）。
#![allow(unsafe_code)]

use std::collections::HashSet;

use super::super::trace::{Trace, Tracer};
use super::{
    Epoch, HeapCore, HeapFault, HeapFaultKind, HostData, ObjHeader, ObjKind, TraceSink, Value,
    make_ref, retime,
};

struct VerifySink<'a> {
    core: &'a HeapCore,
    reachable: bool,
    pending: Vec<Value<'static>>,
    seen: HashSet<usize>,
    fault: Option<HeapFault>,
}

impl<'a> VerifySink<'a> {
    fn new(core: &'a HeapCore, reachable: bool) -> Self {
        Self {
            core,
            reachable,
            pending: Vec::new(),
            seen: HashSet::new(),
            fault: None,
        }
    }
    fn value(&mut self, value: Value<'_>) {
        let Some(object) = value.as_obj() else {
            return;
        };
        let addr = object.ptr().addr().get();
        // O5: Miri の対象ごとの確保でも、解放した領域に触れる前に拒む。
        if !self
            .core
            .generations
            .borrow()
            .get(&addr)
            .is_some_and(|life| life.alive && life.generation == object.generation())
        {
            self.fail(
                if self.reachable {
                    HeapFaultKind::ReachableFreed
                } else {
                    HeapFaultKind::StaleReference
                },
                "reference does not point to a live allocation generation",
            );
            return;
        }
        if self.reachable && self.seen.insert(addr) {
            self.pending.push(retime(value, Epoch::new()));
        }
    }
    fn fail(&mut self, kind: HeapFaultKind, detail: &str) {
        if self.fault.is_none() {
            self.fault = Some(HeapFault {
                kind,
                detail: detail.into(),
            });
        }
    }
    fn children(&mut self, value: Value<'_>) {
        let value = retime(value, Epoch::new());
        match self.core.kind(value) {
            Some(ObjKind::Fields(_)) => {
                if let Some(len) = self.core.len(value) {
                    for i in 0..len {
                        if let Some(child) = self.core.field(Epoch::new(), value, i) {
                            self.value(child);
                        }
                    }
                }
            }
            Some(ObjKind::Cell) => {
                if let Some(body) = self.core.cell(value) {
                    self.value(body.value.get());
                }
            }
            Some(ObjKind::Host) => {
                if let Some((payload, _)) = self.core.payload(value, ObjKind::Host) {
                    // SAFETY: H2・H5・O2・O4・O5。頭と生存を検査した Host の初期化済みの Box。検査中は書き換えない。
                    let host = unsafe { payload.cast::<Box<dyn HostData>>().as_ref() };
                    host.trace(&mut Tracer::new(self));
                }
            }
            Some(ObjKind::Str | ObjKind::Bytes | ObjKind::Decimal | ObjKind::Opaque) | None => {}
        }
    }
}
impl TraceSink for VerifySink<'_> {
    fn core(&self) -> &HeapCore {
        self.core
    }
    fn visit(&mut self, slot: &super::Slot) {
        self.value(slot.raw().0);
    }
    fn foreign_slot(&mut self) {
        self.fail(HeapFaultKind::ForeignHeap, "slot belongs to another heap");
    }
}

impl HeapCore {
    pub(super) fn verify_live_objects(&self, roots: &dyn Trace) -> Result<(), HeapFault> {
        let objects = self.objects.borrow();
        let mut values = Vec::with_capacity(objects.len());
        // O2: 壊れた長さを使って中身を読む前に、全対象の頭を確かめる。
        for (index, record) in objects.iter().enumerate() {
            let ptr = record.allocation.ptr.cast::<ObjHeader>();
            // SAFETY: H2・O1・O2・O4。生存対象一覧の初期化済みの頭。検証中に解放しない。
            let head = unsafe { ptr.as_ref() };
            if head.kind != record.layout.kind
                || head.len != record.layout.len
                || usize::try_from(head.index.get()).ok() != Some(index)
                || !self
                    .generations
                    .borrow()
                    .get(&ptr.addr().get())
                    .is_some_and(|life| life.alive && life.generation == head.generation.get())
            {
                return Err(HeapFault {
                    kind: HeapFaultKind::CorruptHeader,
                    detail: "object header differs from allocation metadata".into(),
                });
            }
            values.push(Value::Obj(make_ref(
                ptr,
                Epoch::new(),
                head.generation.get(),
            )));
        }
        // 根からの経路を先に調べ、到達可能な解放済みの対象を専用の種類で報告する（R11）。
        let mut reachable = VerifySink::new(self, true);
        roots.trace(&mut Tracer::new(&mut reachable));
        while reachable.fault.is_none() {
            let Some(value) = reachable.pending.pop() else {
                break;
            };
            reachable.children(value);
        }
        if let Some(fault) = reachable.fault {
            return Err(fault);
        }
        // 到達しない親も次の回収まで生きているので、その内部参照も検査する（H5）。
        let mut all = VerifySink::new(self, false);
        for value in &values {
            all.children(*value);
        }
        roots.trace(&mut Tracer::new(&mut all));
        if let Some(fault) = all.fault {
            return Err(fault);
        }
        Ok(())
    }
}
