//! ランタイム（設計書 02-09）: 実行時の値、ヒープ、IO のハンドラ、IO 実行器、報告、実行の流れ。

pub mod executor;
pub mod heap;
pub mod io;
pub mod panic;
pub mod real_io;
pub mod report;
pub mod run;
pub mod test_io;
pub mod value;

/// 一つの操作で作る文字列の大きさの上限（2^30 バイト。02-09、ADR 0049）。
pub const MAX_STRING_BYTES: u64 = 1_073_741_824;
/// 一つの操作で作るリストの長さの上限（2^24 要素）。
pub const MAX_LIST_LEN: u64 = 16_777_216;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Stream {
    Stdout,
    Stderr,
}

/// 実行時エラーの種類（01-08「実行時エラーによる停止」の最小実行版の三種）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum RuntimeError {
    /// R0101
    DivisionByZero,
    /// R0102
    IntegerOverflow,
    /// R0201・R0202。`reason` は `std::io::Error` の文字列
    WriteFailed { stream: Stream, reason: String },
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SizeUnit {
    Bytes,
    Elements,
}

/// 資源の不足の種類（01-08「資源の不足」のうち処理系が上限を設けるもの）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum ResourceError {
    /// R0901。`frames` はそのときの呼び出しの枠の数
    CallStackTooDeep { frames: u64 },
    /// R0902。`function` は値を作ろうとした関数の修飾した名前、または `+`。
    /// リストリテラル（`LIST` の命令）では `"list literal"`（実際には起きない）
    ValueTooLarge {
        function: &'static str,
        size: u64,
        unit: SizeUnit,
        limit: u64,
    },
}

/// 実行を止める理由。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Stop {
    Runtime(RuntimeError),
    Resource(ResourceError),
    /// 処理系の不具合。文字列は調べるための説明（英語）
    Internal(String),
}
