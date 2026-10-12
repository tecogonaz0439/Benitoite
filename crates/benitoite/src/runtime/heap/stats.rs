//! ヒープの設定と測定の記録（設計書 02-09「メモリの管理」、07-02「測る項目」）。

use super::{DEFAULT_TRIGGER_FACTOR_PERCENT, MIN_COLLECT_TRIGGER_BYTES};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct HeapConfig {
    /// A の下限（既定 4 MiB）
    pub trigger_min_bytes: u64,
    /// 係数 k の百分率（既定 100）
    pub trigger_factor_percent: u32,
    /// 回収の強制。安全点ごとに必ず回収する（機能 `gc-stress` のビルドでは常に真として扱う）
    pub stress: bool,
    /// 停止時間の並びを測定時だけ保持する（設計書 07-02「測る項目」）。
    pub record_pauses: bool,
    /// その場での再利用を行う（既定は真）。偽なら `NoGcCtx::reuse_ctor` がつねに `Ok(None)` を返す。
    /// 再利用の有無を同じプログラムで比べるためにある。再利用は参照カウントの方式だけが
    /// 行うので、マーク・スイープでは設定によらず再利用しない
    pub reuse: bool,
}

impl Default for HeapConfig {
    fn default() -> HeapConfig {
        HeapConfig {
            trigger_min_bytes: MIN_COLLECT_TRIGGER_BYTES,
            trigger_factor_percent: DEFAULT_TRIGGER_FACTOR_PERCENT,
            stress: cfg!(feature = "gc-stress"),
            record_pauses: false,
            reuse: true,
        }
    }
}

/// 測定の記録。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct HeapStats {
    pub allocations: u64,
    /// 確保した量の合計（頭と切り上げと別の領域を含む）。数え直しで増えた分を含み、減った分は引かない。
    pub allocated_bytes: u64,
    /// 最後の回収で数えた生きている量 L
    pub live_bytes: u64,
    /// これまでで最も大きい、確保している量
    pub peak_heap_bytes: u64,
    pub collections: u64,
    /// 回収の停止時間の合計（ナノ秒）。件数は `collections` と常に等しいので、別の欄に持たない
    /// （設計書 07-02「測る項目」）。
    pub pause_total_nanos: u64,
    /// 回収の停止時間の最大値（設計書 07-02「測る項目」）。
    pub pause_max_nanos: u64,
    /// 回収ごとの停止の時間（ナノ秒）。record_pauses が真のときだけ記録する（設計書 07-02「測る項目」）。
    pub pause_nanos: Vec<u64>,
    /// 回収で辿った根の `Slot` の数の合計
    pub roots_traced: u64,
    /// 解放した対象の数。内部の層の解放の関数だけが数える
    pub frees: u64,
}

/// ヒープの検証器と確保の世代の検査が見つけた不具合の種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum HeapFaultKind {
    /// 解放した対象を指す値を読んだ（世代の食い違い）
    StaleReference,
    /// 別の `Heap` の番号を持つ `Slot` を読んだ・書いた・辿った（すべての構成で調べる。設計書 02-09「メモリの管理」）
    ForeignHeap,
    /// 対象の頭が壊れている
    CorruptHeader,
    /// 参照カウントの数が、辿って数えた数と食い違う（参照カウントの項目。マーク・スイープでは起きない）
    CountMismatch,
    /// 根から辿れる対象が解放されている
    ReachableFreed,
}

/// ヒープの不具合。VM はこれを `Stop::Internal` にして止める。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct HeapFault {
    pub kind: HeapFaultKind,
    /// 調べるための説明（英語）
    pub detail: String,
}
