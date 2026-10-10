//! 値（設計書 02-08「値の表現」）。値は 16 バイトの列挙型であり、`Send` にしない。

use std::any::Any;
use std::fmt::Debug;
use std::marker::PhantomData;
use std::ptr::NonNull;

use super::core::ObjHeader;
use super::trace::Trace;

/// 回収しない区間の印。`'e` について不変にするため、`fn(&'e ()) -> &'e ()` を持つ。
#[derive(Clone, Copy, Debug)]
pub struct Epoch<'e>(PhantomData<fn(&'e ()) -> &'e ()>);

impl<'e> Epoch<'e> {
    pub(super) fn new() -> Epoch<'e> {
        Epoch(PhantomData)
    }
}

/// 引数のない構成子のタグ。型の宣言の中で 0 から数えた番号である（10-07「コンパイル済みプログラム」）。
/// 構成子の表の位置（10-07 の `CtorIdx`）とは別の値である。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct CtorTag(pub u32);

/// 実行ごとのリソースの表の番号（02-09「リソースの追跡」）。一つの実行の中で使い回さない。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ResourceId(pub u64);

/// ヒープの対象を指す値。区間 `'e` の中でだけ使える。
#[derive(Clone, Copy, Debug)]
pub struct ObjRef<'e> {
    ptr: NonNull<ObjHeader>,
    /// 確保の世代（機能 `heap-verify`）。対象の頭の世代と比べ、解放後の使用を見つける
    #[cfg(feature = "heap-verify")]
    generation: u32,
    epoch: Epoch<'e>,
}

impl<'e> ObjRef<'e> {
    #[cfg(not(feature = "heap-verify"))]
    pub(super) fn from_raw(ptr: NonNull<ObjHeader>) -> ObjRef<'e> {
        ObjRef {
            ptr,
            epoch: Epoch::new(),
        }
    }

    #[cfg(feature = "heap-verify")]
    pub(super) fn from_raw(ptr: NonNull<ObjHeader>, generation: u32) -> ObjRef<'e> {
        ObjRef {
            ptr,
            generation,
            epoch: Epoch::new(),
        }
    }

    pub(super) fn ptr(self) -> NonNull<ObjHeader> {
        self.ptr
    }

    #[cfg(feature = "heap-verify")]
    pub(super) fn generation(self) -> u32 {
        self.generation
    }

    pub(super) fn epoch(self) -> Epoch<'e> {
        self.epoch
    }
}

/// 値（設計書 02-08「値の表現」）。`Obj` のほかは即値である。
#[derive(Clone, Copy, Debug)]
pub enum Value<'e> {
    Int(i64),
    Float(f64),
    Byte(u8),
    Bool(bool),
    Char(char),
    Unit,
    /// 引数のない構成子
    Tag(CtorTag),
    Resource(ResourceId),
    EmptyList,
    EmptyMap,
    EmptySet,
    /// ヒープの対象。種類は対象の頭にある（`ValueCtx::kind`）
    Obj(ObjRef<'e>),
}

#[cfg(not(feature = "heap-verify"))]
const _: () = assert!(std::mem::size_of::<Value<'static>>() == 16);

impl<'e> Value<'e> {
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_int(self) -> Option<i64> {
        if let Value::Int(n) = self {
            Some(n)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_float(self) -> Option<f64> {
        if let Value::Float(x) = self {
            Some(x)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_byte(self) -> Option<u8> {
        if let Value::Byte(b) = self {
            Some(b)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_bool(self) -> Option<bool> {
        if let Value::Bool(b) = self {
            Some(b)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_char(self) -> Option<char> {
        if let Value::Char(c) = self {
            Some(c)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_tag(self) -> Option<CtorTag> {
        if let Value::Tag(t) = self {
            Some(t)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_resource(self) -> Option<ResourceId> {
        if let Value::Resource(r) = self {
            Some(r)
        } else {
            None
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn as_obj(self) -> Option<ObjRef<'e>> {
        if let Value::Obj(r) = self {
            Some(r)
        } else {
            None
        }
    }
}

/// ヒープの対象の種類（対象の頭に置く。設計書 02-08「値の表現」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum ObjKind {
    /// 文字列。中身は常に正しい UTF-8
    Str,
    Bytes,
    Decimal,
    /// 値の並びを持つ対象（下の `FieldsKind`）
    Fields(FieldsKind),
    /// `Reference` のセル。中身の値と版の番号を持ち、その場で書き換える（設計書 02-08「可変のセル」）
    Cell,
    /// 組み込みの関数が作った、言語の値を含まない Rust の値（`Regex.Pattern` など。設計書 02-08「値の表現」）
    Opaque,
    /// VM とランタイムが定める、言語の値を含む Rust の値（タスク、継続、ハンドラの記録、`Lazy`）
    Host,
}

/// 値の並びを持つ対象の種類。どれも、種類・32 ビットの印（`tag`）・値の並びを持つ。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum FieldsKind {
    /// 構成子を適用した値（レコード、`Pair`・`Triple` を含む）。`tag` は構成子のタグ
    Ctor,
    /// 関数の値。`tag` は原型の番号（10-07 の `ProtoIdx` の値）、並びは捕捉した値
    Func,
    /// 型クラスの辞書。`tag` は実装の番号（10-07 の `ImplIdx` の値）、並びは実装の制約の辞書（設計書 02-08「値の表現」）
    Dict,
    /// 連結リストのセル（第 1 段のリストの表現。並びは先頭の要素と残りのリスト、`tag` は長さ）
    ListCell,
    /// 永続ベクタのノードと葉（設計書 03-06「List の内部の表現」。`tag` の使い方はリストの表現を作る作業 R36 が決める）
    ListNode,
    /// マップの木のノード（設計書 02-08「値の表現」。`tag` の使い方は R37 が決める）
    MapNode,
    /// 集合の木のノード
    SetNode,
    /// `IOError` の値。`tag` は `IOErrorKind` の番号、並びは理由の文字列
    IoError,
    /// `NetworkError` の値。`tag` は `NetworkErrorKind` の番号、並びは理由の文字列
    NetworkError,
}

/// `ObjKind::Opaque` の対象が持つ Rust の値。言語の値（`Slot`）を含めてはならない。
/// 作った後に変更しない（`ValueCtx::opaque` は共有の参照だけを返す）。
pub trait OpaqueData: Any + Debug {}

/// `ObjKind::Host` の対象が持つ Rust の値。持つ `Slot` を `Trace` ですべて訪れる（不変条件 H5）。
/// 書き換えは `NoGcCtx::host_mut` だけで行う（不変条件 H7）。
/// 対象を解放するときに内部の層が Rust の値を `drop` するが、`Drop` の実装でリソースの解放やタスクの取り消しなど
/// 言語の後始末を行ってはならない。後始末は VM が枠を降ろす処理と止める手順で行う（10-08「根の保存領域」）。
pub trait HostData: Trace + Any + Debug {}

/// 対象の識別（テストで到達可能性を独立に計算するために使う。番地から作る）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ObjId(pub u64);
