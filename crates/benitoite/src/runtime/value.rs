//! 実行時の値（設計書 02-08「値の表現」、03-06「List の内部の表現」）。

use std::rc::Rc;

use crate::base::BindingId;
use crate::builtins::BuiltinId;
use crate::bytecode::program::ProtoIdx;
use crate::ir::core_ir::{LambdaId, VarId};

use super::Stop;

#[derive(Clone, Debug)]
pub enum Value {
    Int(i64),
    Float(f64),
    Bool(bool),
    Char(char),
    Unit,
    Str(StrRef),
    Func(FuncRef),
    /// 構成子を適用した値。引数のない構成子は `fields` を持たない
    Ctor(CtorRef),
    List(ListRef),
    IoError(IoErrorRef),
}

/// 文字列の対象への参照。中身は常に正しい UTF-8。
#[derive(Clone, Debug)]
pub struct StrRef(Rc<str>);

/// 関数の値の対象への参照。
#[derive(Clone, Debug)]
pub struct FuncRef(Rc<FuncObj>);

/// 関数の値の対象。
#[derive(Debug)]
pub enum FuncObj {
    /// VM の関数の値: 原型と、捕捉した値の並び
    Proto {
        proto: ProtoIdx,
        captures: Vec<Value>,
    },
    /// 参照インタプリタの関数の値: 本体と、捕捉した変数の値
    Ref {
        code: RefCode,
        env: Vec<(VarId, Value)>,
    },
}

/// 参照インタプリタの関数の値の本体。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RefCode {
    Lambda(LambdaId),
    TopFn(BindingId),
    Builtin(BuiltinId),
}

/// 構成子を適用した値。
#[derive(Clone, Debug)]
pub struct CtorRef {
    tag: u32,
    fields: Option<Rc<CtorFields>>,
}

/// 構成子の引数の並び。解放は明示の積み重ねで行う（`Drop` を T06 が書く）。
#[derive(Debug)]
pub struct CtorFields {
    values: Vec<Value>,
}

/// リスト。空のリストはセルを持たない。
#[derive(Clone, Debug)]
pub struct ListRef(Option<Rc<Cell>>);

/// リストのセル（03-06「List の内部の表現」）。作った後に変更しない。解放は明示の積み重ねで行う（`Drop` を T06 が書く）。
#[derive(Debug)]
pub struct Cell {
    head: Value,
    tail: ListRef,
    /// このセルから始まるリストの長さ
    len: u32,
}

/// `IoError` の値の対象。
#[derive(Clone, Debug)]
pub struct IoErrorRef(Rc<IoErrorObj>);

#[derive(Debug)]
pub struct IoErrorObj {
    message: String,
}

/// `ListRef::iter` の返す反復子。`cur` はまだ返していない残りのリスト。
#[derive(Debug)]
pub struct ListIter<'a> {
    cur: &'a ListRef,
}

impl Value {
    /// 整数なら値を返す。
    pub fn as_int(&self) -> Option<i64> {
        match self {
            Self::Int(value) => Some(*value),
            Self::Float(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// 浮動小数点数なら値を返す。
    pub fn as_float(&self) -> Option<f64> {
        match self {
            Self::Float(value) => Some(*value),
            Self::Int(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// 真偽値なら値を返す。
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Self::Bool(value) => Some(*value),
            Self::Int(_)
            | Self::Float(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// 文字なら値を返す。
    pub fn as_char(&self) -> Option<char> {
        match self {
            Self::Char(value) => Some(*value),
            Self::Int(_)
            | Self::Float(_)
            | Self::Bool(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// 文字列なら中身を返す。
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Self::Str(value) => Some(value.as_str()),
            Self::Int(_)
            | Self::Float(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// リストなら参照を返す。
    pub fn as_list(&self) -> Option<&ListRef> {
        match self {
            Self::List(value) => Some(value),
            Self::Int(_)
            | Self::Float(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::IoError(_) => None,
        }
    }

    /// 構成子ならタグと引数の並びを返す。
    pub fn as_ctor(&self) -> Option<(u32, &[Value])> {
        match self {
            Self::Ctor(value) => Some((value.tag(), value.fields())),
            Self::Int(_)
            | Self::Float(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// 関数なら関数の値を返す。
    pub fn as_func(&self) -> Option<&FuncObj> {
        match self {
            Self::Func(value) => Some(value.obj()),
            Self::Int(_)
            | Self::Float(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Ctor(_)
            | Self::List(_)
            | Self::IoError(_) => None,
        }
    }

    /// IO エラーなら失敗の理由を返す。
    pub fn as_io_error(&self) -> Option<&str> {
        match self {
            Self::IoError(value) => Some(value.message()),
            Self::Int(_)
            | Self::Float(_)
            | Self::Bool(_)
            | Self::Char(_)
            | Self::Unit
            | Self::Str(_)
            | Self::Func(_)
            | Self::Ctor(_)
            | Self::List(_) => None,
        }
    }
}

impl StrRef {
    pub(super) fn new(s: &str) -> StrRef {
        StrRef(Rc::from(s))
    }

    /// 文字列の中身を返す。
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl FuncRef {
    pub(super) fn new(obj: FuncObj) -> FuncRef {
        FuncRef(Rc::new(obj))
    }

    /// 関数の値を返す。
    pub fn obj(&self) -> &FuncObj {
        &self.0
    }
}

impl CtorRef {
    pub(super) fn new(tag: u32, fields: Vec<Value>) -> CtorRef {
        let fields = if fields.is_empty() {
            None
        } else {
            Some(Rc::new(CtorFields { values: fields }))
        };
        CtorRef { tag, fields }
    }

    /// 構成子のタグを返す。
    pub fn tag(&self) -> u32 {
        self.tag
    }

    /// 構成子の引数を返す。
    pub fn fields(&self) -> &[Value] {
        self.fields
            .as_ref()
            .map_or(&[], |fields| fields.values.as_slice())
    }
}

impl ListRef {
    /// 空のリストを返す。
    pub fn empty() -> ListRef {
        ListRef(None)
    }

    pub(super) fn cons(head: Value, tail: &ListRef) -> ListRef {
        let len = tail.len().saturating_add(1);
        let tail = ListRef(tail.0.as_ref().map(Rc::clone));
        ListRef(Some(Rc::new(Cell { head, tail, len })))
    }

    /// このリストの長さを返す。
    pub fn len(&self) -> u32 {
        self.0.as_ref().map_or(0, |cell| cell.len)
    }

    /// 空なら真を返す。
    pub fn is_empty(&self) -> bool {
        self.0.is_none()
    }

    /// 先頭の値を返す。
    pub fn head(&self) -> Option<&Value> {
        self.0.as_ref().map(|cell| &cell.head)
    }

    /// 残りのリストを返す。
    pub fn tail(&self) -> Option<&ListRef> {
        self.0.as_ref().map(|cell| &cell.tail)
    }

    /// 先頭から順に要素を返す反復子を作る。
    pub fn iter(&self) -> ListIter<'_> {
        ListIter { cur: self }
    }

    /// 二つのリストが同じセルを指すか返す。
    pub fn same_cells(&self, other: &ListRef) -> bool {
        match (&self.0, &other.0) {
            (None, None) => true,
            (Some(left), Some(right)) => Rc::ptr_eq(left, right),
            (None, Some(_)) | (Some(_), None) => false,
        }
    }
}

impl<'a> Iterator for ListIter<'a> {
    type Item = &'a Value;

    fn next(&mut self) -> Option<&'a Value> {
        let cell = self.cur.0.as_ref().map(Rc::as_ref)?;
        self.cur = &cell.tail;
        Some(&cell.head)
    }
}

impl IoErrorRef {
    pub(super) fn new(message: String) -> IoErrorRef {
        IoErrorRef(Rc::new(IoErrorObj { message }))
    }

    /// IO エラーの理由を返す。
    pub fn message(&self) -> &str {
        &self.0.message
    }
}

/// 代数的データ型とリストを構造で比較する。
pub fn values_equal(a: &Value, b: &Value) -> Result<bool, Stop> {
    let mut pending = vec![(a, b)];
    while let Some((left, right)) = pending.pop() {
        match (left, right) {
            (Value::Int(left), Value::Int(right)) => {
                if left != right {
                    return Ok(false);
                }
            }
            (Value::Float(left), Value::Float(right)) => {
                if left != right {
                    return Ok(false);
                }
            }
            (Value::Bool(left), Value::Bool(right)) => {
                if left != right {
                    return Ok(false);
                }
            }
            (Value::Char(left), Value::Char(right)) => {
                if left != right {
                    return Ok(false);
                }
            }
            (Value::Unit, Value::Unit) => {}
            (Value::Str(left), Value::Str(right)) => {
                if left.as_str() != right.as_str() {
                    return Ok(false);
                }
            }
            (Value::Ctor(left), Value::Ctor(right)) => {
                if left.tag() != right.tag() {
                    return Ok(false);
                }
                let left_fields = left.fields();
                let right_fields = right.fields();
                if left_fields.len() != right_fields.len() {
                    return Ok(false);
                }
                pending.extend(left_fields.iter().zip(right_fields.iter()));
            }
            (Value::List(left), Value::List(right)) => {
                if left.len() != right.len() {
                    return Ok(false);
                }
                pending.extend(left.iter().zip(right.iter()));
            }
            (Value::Func(_), _)
            | (_, Value::Func(_))
            | (Value::IoError(_), _)
            | (_, Value::IoError(_)) => {
                return Err(Stop::Internal(String::from(
                    "equality received a non-equality value",
                )));
            }
            _ => {
                return Err(Stop::Internal(String::from(
                    "equality received values of different kinds",
                )));
            }
        }
    }
    Ok(true)
}

/// 値を落とすと、Rust の `Drop` が別の対象の解放へ連鎖するかを返す。
///
/// 連鎖するのは、参照の数が 1 のセル・構成子の引数の並び・関数の値を指す値だけである。
/// 参照の数が 2 以上なら数を一つ減らすだけで、文字列と `IoError` は子の値を持たない。
fn releases_children(value: &Value) -> bool {
    match value {
        Value::List(ListRef(Some(rc))) => Rc::strong_count(rc) == 1,
        Value::Ctor(CtorRef {
            fields: Some(rc), ..
        }) => Rc::strong_count(rc) == 1,
        Value::Func(FuncRef(rc)) => Rc::strong_count(rc) == 1,
        Value::List(ListRef(None))
        | Value::Ctor(CtorRef { fields: None, .. })
        | Value::Int(_)
        | Value::Float(_)
        | Value::Bool(_)
        | Value::Char(_)
        | Value::Unit
        | Value::Str(_)
        | Value::IoError(_) => false,
    }
}

/// 解放を待つ値の作業列。連鎖を起こす値だけを入れる。
///
/// リストの解放のように一本道の連鎖では、待つ値は常に一つなので `next` だけで足り、
/// `Vec` を確保しない。枝分かれして二つ以上を待つときだけ `rest` を使う
/// （解放のたびの確保を避ける。値の解放は再帰しない。設計書 02-08「値の表現」）。
struct ReleaseQueue {
    next: Option<Value>,
    rest: Vec<Value>,
}

impl ReleaseQueue {
    fn new() -> ReleaseQueue {
        ReleaseQueue {
            next: None,
            rest: Vec::new(),
        }
    }

    /// 値を作業列に入れる。連鎖を起こさない値はその場で落とす（参照の数を減らすだけで済む）。
    fn push(&mut self, value: Value) {
        if !releases_children(&value) {
            return;
        }
        if self.next.is_none() {
            self.next = Some(value);
        } else {
            self.rest.push(value);
        }
    }

    fn pop(&mut self) -> Option<Value> {
        self.next.take().or_else(|| self.rest.pop())
    }

    /// 作業列が空になるまで、一意に持つ対象から子の値を取り出して作業列へ移す。
    ///
    /// 子を取り出した後の対象は自明な値だけを持つので、その `Drop` は作業列に何も入れずに戻る。
    fn run(&mut self) {
        while let Some(value) = self.pop() {
            match value {
                Value::List(ListRef(Some(rc))) => {
                    if let Ok(mut cell) = Rc::try_unwrap(rc) {
                        let head = std::mem::replace(&mut cell.head, Value::Unit);
                        let tail = std::mem::replace(&mut cell.tail, ListRef::empty());
                        self.push(head);
                        self.push(Value::List(tail));
                    }
                }
                Value::Ctor(mut value) => {
                    if let Some(rc) = value.fields.take()
                        && let Ok(mut fields) = Rc::try_unwrap(rc)
                    {
                        for child in fields.values.drain(..) {
                            self.push(child);
                        }
                    }
                }
                Value::Func(value) => {
                    if let Ok(mut object) = Rc::try_unwrap(value.0) {
                        object.move_children_to(self);
                    }
                }
                Value::List(ListRef(None))
                | Value::Int(_)
                | Value::Float(_)
                | Value::Bool(_)
                | Value::Char(_)
                | Value::Unit
                | Value::Str(_)
                | Value::IoError(_) => {}
            }
        }
    }
}

impl FuncObj {
    /// 捕捉した値を作業列へ移し、自身には空の並びを残す。
    fn move_children_to(&mut self, queue: &mut ReleaseQueue) {
        match self {
            Self::Proto { captures, .. } => {
                for value in captures.drain(..) {
                    queue.push(value);
                }
            }
            Self::Ref { env, .. } => {
                for (_, value) in env.drain(..) {
                    queue.push(value);
                }
            }
        }
    }
}

// 各 `Drop` は、子の値を一つずつ作業列へ入れる。連鎖を起こさない子はその場で落ちるので、
// 子がどれも連鎖を起こさなければ `Vec` を確保せずに戻る。連鎖を起こす子だけを作業列に残し、
// 各 Rc の解放が深い値へ再帰しないようにする（設計書 02-08「値の表現」、ADR 0016）。
//
// 連鎖を起こすかは、兄弟の子を落とした後で調べる。同じ対象を二つの子が指すとき（参照の数が 2）、
// 先の子を落とした時点で数が 1 になり、後の子は作業列に入る。前もってまとめて調べると、
// この場合を見落として既定の解放で再帰する。
impl Drop for Cell {
    fn drop(&mut self) {
        #[cfg(feature = "alloc-stats")]
        super::heap::record_freed();

        let mut queue = ReleaseQueue::new();
        queue.push(std::mem::replace(&mut self.head, Value::Unit));
        queue.push(Value::List(std::mem::replace(
            &mut self.tail,
            ListRef::empty(),
        )));
        queue.run();
    }
}

impl Drop for CtorFields {
    fn drop(&mut self) {
        #[cfg(feature = "alloc-stats")]
        super::heap::record_freed();

        let mut queue = ReleaseQueue::new();
        for value in self.values.drain(..) {
            queue.push(value);
        }
        queue.run();
    }
}

impl Drop for FuncObj {
    fn drop(&mut self) {
        #[cfg(feature = "alloc-stats")]
        super::heap::record_freed();

        let mut queue = ReleaseQueue::new();
        self.move_children_to(&mut queue);
        queue.run();
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
    // テスト失敗は panic で表し、対象の値を直接組み立てて契約を確かめる（設計書 07-03「テストの設計の原則」）。
    use std::rc::Rc;

    use crate::bytecode::program::ProtoIdx;
    use crate::ir::core_ir::{LambdaId, VarId};
    use crate::runtime::heap::Heap;
    use crate::runtime::{MAX_LIST_LEN, ResourceError, SizeUnit, Stop};

    use super::{Cell, FuncObj, ListRef, RefCode, Value, values_equal};

    #[test]
    fn accessors_return_values_only_for_their_variant() {
        let mut heap = Heap::new();
        let string = heap.string("あい");
        assert_eq!(string.as_str(), Some("あい"));
        assert_eq!(string.as_int(), None);
        assert_eq!(Value::Int(7).as_int(), Some(7));
        assert_eq!(Value::Float(2.5).as_float(), Some(2.5));
        assert_eq!(Value::Bool(true).as_bool(), Some(true));
        assert_eq!(Value::Char('あ').as_char(), Some('あ'));

        let ctor = heap.ctor(9, Vec::new());
        let (tag, fields) = ctor.as_ctor().unwrap();
        assert_eq!(tag, 9);
        assert!(fields.is_empty());
        assert_eq!(heap.stats().allocations, 1);

        let list = heap.list_from_vec(vec![Value::Int(4)], "test").unwrap();
        assert_eq!(list.as_list().map(ListRef::len), Some(1));
        let func = heap.func_proto(ProtoIdx(0), Vec::new());
        assert!(matches!(func.as_func(), Some(FuncObj::Proto { .. })));
        let io_error = heap.io_error(String::from("failed"));
        assert_eq!(io_error.as_io_error(), Some("failed"));
    }

    #[test]
    fn list_cells_keep_lengths_order_and_shared_tails() {
        let mut heap = Heap::new();
        let original = heap
            .list_from_vec((0_i64..5_i64).map(Value::Int).collect(), "test")
            .unwrap();
        let original_ref = original.as_list().unwrap();
        assert!(ListRef::empty().same_cells(&ListRef::empty()));
        let independent = heap
            .list_from_vec((0_i64..5_i64).map(Value::Int).collect(), "test")
            .unwrap();
        assert!(!original_ref.same_cells(independent.as_list().unwrap()));

        let mut cursor = original_ref.clone();
        for expected in (1_u32..=5_u32).rev() {
            assert_eq!(cursor.len(), expected);
            cursor = cursor.tail().unwrap().clone();
        }
        assert!(cursor.is_empty());

        let prepended = heap
            .cons(Value::Int(10), original_ref, "List.prepend")
            .unwrap();
        let prepended_ref = prepended.as_list().unwrap();
        assert!(prepended_ref.tail().unwrap().same_cells(original_ref));
        let original_items: Vec<i64> = original_ref
            .iter()
            .map(|value| value.as_int().unwrap())
            .collect();
        let prepended_items: Vec<i64> = prepended_ref
            .iter()
            .map(|value| value.as_int().unwrap())
            .collect();
        assert_eq!(original_items, vec![0, 1, 2, 3, 4]);
        assert_eq!(prepended_items, vec![10, 0, 1, 2, 3, 4]);
        drop(prepended);
        let remaining_items: Vec<i64> = original_ref
            .iter()
            .map(|value| value.as_int().unwrap())
            .collect();
        assert_eq!(remaining_items, vec![0, 1, 2, 3, 4]);
    }

    #[test]
    fn cons_rejects_a_list_that_exceeds_the_element_limit() {
        let tail = ListRef(Some(Rc::new(Cell {
            head: Value::Unit,
            tail: ListRef::empty(),
            len: MAX_LIST_LEN as u32,
        })));
        let mut heap = Heap::new();
        let result = heap.cons(Value::Int(1), &tail, "List.prepend");
        assert!(matches!(
            result,
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "List.prepend",
                size: 16_777_217,
                unit: SizeUnit::Elements,
                limit: MAX_LIST_LEN
            }))
        ));
    }

    #[test]
    fn structural_equality_handles_values_and_rejects_impossible_kinds() {
        let mut heap = Heap::new();
        let left_list = heap
            .list_from_vec(vec![Value::Int(1), Value::Int(2)], "test")
            .unwrap();
        let right_list = heap
            .list_from_vec(vec![Value::Int(1), Value::Int(2)], "test")
            .unwrap();
        let left_string = heap.string("text");
        let left = heap.ctor(3, vec![left_string, left_list]);
        let right_string = heap.string("text");
        let right = heap.ctor(3, vec![right_string, right_list]);
        assert!(values_equal(&left, &right).unwrap());

        let other_tag = heap.ctor(4, vec![Value::Int(1)]);
        let same_tag_other_field = heap.ctor(3, vec![Value::Int(1)]);
        assert!(!values_equal(&left, &other_tag).unwrap());
        assert!(!values_equal(&left, &same_tag_other_field).unwrap());

        let short_list = heap.list_from_vec(vec![Value::Int(1)], "test").unwrap();
        let long_list = heap
            .list_from_vec(vec![Value::Int(1), Value::Int(2)], "test")
            .unwrap();
        assert!(!values_equal(&short_list, &long_list).unwrap());

        let nan_left = heap.ctor(5, vec![Value::Float(f64::NAN)]);
        let nan_right = heap.ctor(5, vec![Value::Float(f64::NAN)]);
        assert!(!values_equal(&nan_left, &nan_right).unwrap());
        let zeros = heap.ctor(5, vec![Value::Float(0.0)]);
        let negative_zero = heap.ctor(5, vec![Value::Float(-0.0)]);
        assert!(values_equal(&zeros, &negative_zero).unwrap());

        let function = heap.func_proto(ProtoIdx(0), Vec::new());
        assert!(matches!(
            values_equal(&function, &function),
            Err(Stop::Internal(_))
        ));
        assert!(matches!(
            values_equal(&Value::Int(1), &Value::Bool(true)),
            Err(Stop::Internal(_))
        ));
        let io_error = heap.io_error(String::from("failed"));
        assert!(matches!(
            values_equal(&io_error, &io_error),
            Err(Stop::Internal(_))
        ));
    }

    #[test]
    fn long_nested_values_are_released_and_long_lists_compare_iteratively() {
        let mut heap = Heap::new();

        let mut long_list = Value::List(ListRef::empty());
        for _ in 0..10_000_000 {
            let tail = long_list.as_list().unwrap();
            long_list = heap.cons(Value::Int(0), tail, "List.prepend").unwrap();
        }
        drop(long_list);

        let mut nested = Value::Unit;
        for _ in 0..1_000_000 {
            nested = heap.ctor(0, vec![nested]);
        }
        drop(nested);

        let mut nested = Value::Unit;
        for _ in 0..1_000_000 {
            nested = heap.list_from_vec(vec![nested], "test").unwrap();
        }
        drop(nested);

        let mut nested = Value::Unit;
        for index in 0..1_000_000 {
            nested = if index % 2 == 0 {
                heap.func_proto(ProtoIdx(0), vec![nested])
            } else {
                heap.func_ref(RefCode::Lambda(LambdaId(0)), vec![(VarId(0), nested)])
            };
        }
        drop(nested);

        // 二つの子が同じ対象を指す（参照の数が 2 の）入れ子。先の子を落とすと数が 1 になり、
        // 後の子の解放が連鎖するので、これも再帰せずに解放できなければならない。
        let mut nested = Value::List(ListRef::empty());
        for _ in 0..1_000_000 {
            let tail = nested.as_list().unwrap().clone();
            nested = heap.cons(nested, &tail, "List.prepend").unwrap();
        }
        drop(nested);

        let mut nested = Value::Unit;
        for _ in 0..1_000_000 {
            nested = heap.ctor(0, vec![nested.clone(), nested]);
        }
        drop(nested);

        let mut nested = Value::Unit;
        for index in 0..1_000_000 {
            nested = if index % 2 == 0 {
                heap.func_proto(ProtoIdx(0), vec![nested.clone(), nested])
            } else {
                heap.func_ref(
                    RefCode::Lambda(LambdaId(0)),
                    vec![(VarId(0), nested.clone()), (VarId(1), nested)],
                )
            };
        }
        drop(nested);

        let make_list = |heap: &mut Heap| {
            let items = (0_i64..1_000_000_i64).map(Value::Int).collect::<Vec<_>>();
            heap.list_from_vec(items, "test").unwrap()
        };
        let left = make_list(&mut heap);
        let right = make_list(&mut heap);
        assert!(values_equal(&left, &right).unwrap());
        drop(left);
        drop(right);
    }

    // 解放の回数は、リストのセルだけでなく構成子の引数の並びと関数の値も数える（設計書 07-02「確保と解放」）。
    // 同じ対象を二つの子が指す入れ子でも、各対象をちょうど一度だけ解放しなければならない。
    #[cfg(feature = "alloc-stats")]
    #[test]
    fn freed_count_counts_each_released_ctor_and_function_once() {
        type Build = fn(&mut Heap, Value, usize) -> Value;
        let cases: [(&str, Build); 5] = [
            ("ctor", |heap, inner, _| heap.ctor(0, vec![inner])),
            ("aliased ctor", |heap, inner, _| {
                heap.ctor(0, vec![inner.clone(), inner])
            }),
            ("aliased proto captures", |heap, inner, _| {
                heap.func_proto(ProtoIdx(0), vec![inner.clone(), Value::Int(1), inner])
            }),
            ("aliased ref env", |heap, inner, _| {
                heap.func_ref(
                    RefCode::Lambda(LambdaId(0)),
                    vec![(VarId(0), inner.clone()), (VarId(1), inner)],
                )
            }),
            ("mixed kinds", |heap, inner, index| match index % 3 {
                0 => heap.ctor(0, vec![inner.clone(), inner]),
                1 => heap.func_proto(ProtoIdx(0), vec![inner.clone(), inner]),
                _ => heap.func_ref(
                    RefCode::Lambda(LambdaId(0)),
                    vec![(VarId(0), inner.clone()), (VarId(1), inner)],
                ),
            }),
        ];
        const DEPTH: usize = 1000;
        for (name, build) in cases {
            let mut heap = Heap::new();
            let before = crate::runtime::heap::freed_count();
            let mut nested = Value::Int(0);
            for index in 0..DEPTH {
                nested = build(&mut heap, nested, index);
            }
            assert_eq!(heap.stats().allocations, DEPTH as u64, "{name}");
            drop(nested);
            let freed = crate::runtime::heap::freed_count() - before;
            assert_eq!(freed, DEPTH as u64, "{name}");
        }
    }
}
