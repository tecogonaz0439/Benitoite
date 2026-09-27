//! ヒープの対象の確保（設計書 02-09「メモリの管理」、ADR 0078）。

use crate::bytecode::program::ProtoIdx;
use crate::ir::core_ir::VarId;

use super::value::{FuncObj, FuncRef, IoErrorRef, ListRef, RefCode, StrRef, Value};
use super::{MAX_LIST_LEN, ResourceError, SizeUnit, Stop};

#[cfg(feature = "alloc-stats")]
thread_local! {
    static FREED_COUNT: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
}

/// 確保の統計。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct AllocStats {
    pub allocations: u64,
    /// 確保した対象の大きさの合計（文字列はバイト数、並びは要素の数に 32 を掛けた値、そのほかは 32）
    pub bytes: u64,
}

/// 実行ごとのヒープ。
#[derive(Debug, Default)]
pub struct Heap {
    stats: AllocStats,
}

impl Heap {
    /// 新しい実行用ヒープを作る。
    pub fn new() -> Heap {
        Heap::default()
    }

    /// 確保の統計を返す。
    pub fn stats(&self) -> AllocStats {
        self.stats
    }

    /// 文字列の値を作る。大きさの上限は呼び出し側が値を作る前に確かめる（02-09「一つの操作で作る値の大きさの上限」）。
    pub fn string(&mut self, s: &str) -> Value {
        let value = Value::Str(StrRef::new(s));
        self.record_allocation(bytes_for_length(s.len()));
        value
    }

    /// VM の関数の値を作る。
    pub fn func_proto(&mut self, proto: ProtoIdx, captures: Vec<Value>) -> Value {
        let bytes = bytes_for_elements(captures.len());
        let value = Value::Func(FuncRef::new(FuncObj::Proto { proto, captures }));
        self.record_allocation(bytes);
        value
    }

    /// 参照インタプリタの関数の値を作る。
    pub fn func_ref(&mut self, code: RefCode, env: Vec<(VarId, Value)>) -> Value {
        let bytes = bytes_for_elements(env.len());
        let value = Value::Func(FuncRef::new(FuncObj::Ref { code, env }));
        self.record_allocation(bytes);
        value
    }

    /// 構成子を適用した値を作る。
    pub fn ctor(&mut self, tag: u32, fields: Vec<Value>) -> Value {
        if !fields.is_empty() {
            self.record_allocation(bytes_for_elements(fields.len()));
        }
        Value::Ctor(super::value::CtorRef::new(tag, fields))
    }

    /// 先頭に一つ加えたリストを作る。
    pub fn cons(
        &mut self,
        head: Value,
        tail: &ListRef,
        function: &'static str,
    ) -> Result<Value, Stop> {
        let size = u64::from(tail.len()).saturating_add(1);
        if size > MAX_LIST_LEN {
            return Err(Stop::Resource(ResourceError::ValueTooLarge {
                function,
                size,
                unit: SizeUnit::Elements,
                limit: MAX_LIST_LEN,
            }));
        }

        let value = Value::List(ListRef::cons(head, tail));
        self.record_allocation(32);
        Ok(value)
    }

    /// 要素の並びからリストを作る。末尾から順にセルを確保する。
    pub fn list_from_vec(
        &mut self,
        items: Vec<Value>,
        function: &'static str,
    ) -> Result<Value, Stop> {
        let size = length_as_u64(items.len());
        if size > MAX_LIST_LEN {
            return Err(Stop::Resource(ResourceError::ValueTooLarge {
                function,
                size,
                unit: SizeUnit::Elements,
                limit: MAX_LIST_LEN,
            }));
        }

        let mut list = ListRef::empty();
        for item in items.into_iter().rev() {
            list = ListRef::cons(item, &list);
            self.record_allocation(32);
        }
        Ok(Value::List(list))
    }

    /// IO エラーの値を作る。
    pub fn io_error(&mut self, message: String) -> Value {
        let value = Value::IoError(IoErrorRef::new(message));
        self.record_allocation(32);
        value
    }

    fn record_allocation(&mut self, bytes: u64) {
        self.stats.allocations = self.stats.allocations.saturating_add(1);
        self.stats.bytes = self.stats.bytes.saturating_add(bytes);
    }
}

fn length_as_u64(length: usize) -> u64 {
    u64::try_from(length).unwrap_or(u64::MAX)
}

fn bytes_for_length(length: usize) -> u64 {
    length_as_u64(length)
}

fn bytes_for_elements(length: usize) -> u64 {
    length_as_u64(length).saturating_mul(32)
}

/// 解放したヒープの対象の数。機能 alloc-stats のときだけある。
#[cfg(feature = "alloc-stats")]
pub fn freed_count() -> u64 {
    FREED_COUNT.with(std::cell::Cell::get)
}

#[cfg(feature = "alloc-stats")]
pub(super) fn record_freed() {
    let result = FREED_COUNT.try_with(|count| {
        count.set(count.get().saturating_add(1));
    });
    match result {
        Ok(()) | Err(_) => {}
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // テスト失敗は panic で表し、Heap の公開関数が返す値と統計を確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::bytecode::program::ProtoIdx;
    use crate::ir::core_ir::VarId;
    use crate::runtime::value::{RefCode, Value};

    use super::{AllocStats, Heap};

    #[test]
    fn allocations_record_target_counts_and_documented_sizes() {
        let mut heap = Heap::new();
        let _string = heap.string("あい");
        assert_eq!(
            heap.stats(),
            AllocStats {
                allocations: 1,
                bytes: 6,
            }
        );

        let _proto = heap.func_proto(ProtoIdx(0), vec![Value::Int(1), Value::Int(2)]);
        assert_eq!(
            heap.stats(),
            AllocStats {
                allocations: 2,
                bytes: 70,
            }
        );

        let _ref_func = heap.func_ref(
            RefCode::Builtin(crate::builtins::BuiltinId::AddInt),
            vec![(VarId(0), Value::Unit)],
        );
        assert_eq!(
            heap.stats(),
            AllocStats {
                allocations: 3,
                bytes: 102,
            }
        );

        let _ctor = heap.ctor(1, vec![Value::Unit, Value::Int(2)]);
        assert_eq!(
            heap.stats(),
            AllocStats {
                allocations: 4,
                bytes: 166,
            }
        );

        let _empty_ctor = heap.ctor(2, Vec::new());
        let empty_list = heap.list_from_vec(Vec::new(), "test").unwrap();
        assert_eq!(empty_list.as_list().map(|list| list.len()), Some(0));
        assert_eq!(heap.stats().allocations, 4);

        let list = heap
            .list_from_vec(vec![Value::Int(3), Value::Int(4)], "test")
            .unwrap();
        let list_ref = list.as_list().unwrap();
        let _prepended = heap.cons(Value::Int(2), list_ref, "List.prepend").unwrap();
        assert_eq!(
            heap.stats(),
            AllocStats {
                allocations: 7,
                bytes: 262,
            }
        );

        let _io_error = heap.io_error(String::from("failed"));
        assert_eq!(
            heap.stats(),
            AllocStats {
                allocations: 8,
                bytes: 294,
            }
        );
    }

    #[cfg(feature = "alloc-stats")]
    #[test]
    fn freed_count_counts_released_list_cells() {
        let before = super::freed_count();
        let mut heap = Heap::new();
        let list = heap
            .list_from_vec((0_i64..100_i64).map(Value::Int).collect(), "test")
            .unwrap();
        drop(list);
        assert_eq!(super::freed_count().saturating_sub(before), 100);
    }
}
