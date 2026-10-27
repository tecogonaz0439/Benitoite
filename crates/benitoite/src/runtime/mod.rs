//! ランタイム（設計書 02-09）: 値とヒープ（heap）、リスト（list）、マップと集合（map）、構造の等しさ（equal）、
//! スケジューラ（sched）と IO 実行器（io）、panic 境界（panic）、報告（report）、実行の流れ（run）。

pub mod equal;
pub mod heap;
pub mod io;
pub mod list;
pub mod map;
pub mod panic;
pub mod random;
pub mod report;
pub mod run;
pub mod sched;

use crate::vm::InstrRef;

/// 一つの操作で作る文字列と `Bytes` の大きさの上限（2^30 バイト。02-09「一つの操作で作る値の大きさの上限」）。
pub const MAX_STRING_BYTES: u64 = 1_073_741_824;
/// 一つの操作で作るリストの長さの上限（2^24 要素）。
pub const MAX_LIST_LEN: u64 = 16_777_216;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Stream {
    Stdout,
    Stderr,
}

/// リソースの型（01-10「リソースの型」、02-09「リソースの追跡」）。解放の失敗の報告に使う。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum ResourceKind {
    FileReader,
    FileWriter,
    HttpListener,
    HttpExchange,
    TaskGroup,
}

/// 解放の失敗一つ（02-09「リソースの追跡」の「解放の失敗」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct ReleaseFailure {
    pub kind: ResourceKind,
    /// リソースを開いた呼び出しの命令。解放の失敗の報告で位置を示す（設計書 02-10「解放の失敗の報告」）。
    pub opened_at: Option<InstrRef>,
    /// 失敗の理由（`std::io::Error` の文字列など）
    pub reason: String,
}

/// 実行時エラーの種類（01-08「実行時エラーによる停止」の初回リリース版の範囲）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum RuntimeError {
    /// 外部の関数のトラップ（設計書 03-10「実行」）。
    ExternalTrap {
        function: String,
        component: String,
        export: String,
        trap: String,
    },
    IntegerOverflow,
    DecimalOverflow,
    DivisionByZero,
    /// `reason` は `std::io::Error` の文字列
    WriteFailed {
        stream: Stream,
        reason: String,
    },
    /// 集めた解放の失敗（一つ以上）
    ReleaseFailed(Vec<ReleaseFailure>),
    ReleasedResourceUsed {
        kind: ResourceKind,
    },
    ContinuationResumedTwice,
    /// 引き継いだハンドラの節が末尾で再開する節でない（02-09「操作の振り分け」）。`operation` は操作の修飾した名前
    InheritedHandlerClause {
        operation: String,
    },
    /// `function` は関数の修飾した名前、`argument` は 0 から数えた引数の位置
    ArgumentOutOfDomain {
        function: &'static str,
        argument: u16,
    },
    ResponseSentTwice,
    TaskDeadlock,
    /// 取り消したタスクを `Task.await` で待った（01-11「取り消し」）
    AwaitedTaskCancelled,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SizeUnit {
    Bytes,
    Elements,
}

/// 資源の不足の種類（01-08「資源の不足」のうち処理系が上限を設けるもの）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum ResourceError {
    /// 論理長の上限内でのバッファ予約失敗。要求した容量のバイト数であり、全使用量ではない。
    AllocationFailed {
        function: &'static str,
        requested_bytes: u64,
    },
    /// `frames` はそのときの枠の数（二つの `Vec` の両方を数える。02-08「呼び出しの入れ子の上限」）
    CallStackTooDeep { frames: u64 },
    /// 呼び出しごとの外部の関数の上限（設計書 02-09「外部の関数の実行」）。
    ExternalFuel {
        function: String,
        component: String,
        limit: u64,
    },
    ExternalMemory {
        function: String,
        component: String,
        limit: u64,
    },
    /// 補助の確保器の memory32 の範囲超過または memory.grow の失敗。
    /// Store 全体の制限と補助の確保器の報告を、量の意味ごとに区別する。
    ExternalAdapterMemory {
        function: String,
        component: String,
        requested: Option<u64>,
        memory32_limit: Option<u64>,
        allocated: Option<u64>,
        store_limit: Option<u64>,
    },
    /// ホスト側の表現で数える受け渡しの予算（設計書 02-09「外部の関数の実行」）。
    ExternalTransfer {
        function: String,
        component: String,
        limit: u64,
    },
    /// ゲストの表の要素数、またはコアのインスタンス・メモリ・表の数の上限。
    ExternalObjects {
        function: String,
        component: String,
        resource: &'static str,
        size: u64,
        limit: u64,
    },
    /// Store ごとの生存するコンポーネントハンドル（component handle）の上限。必要数は取得できない。
    ExternalComponentHandles {
        function: String,
        component: String,
        limit: u64,
    },
    ExternalValueTooLarge {
        function: String,
        size: u64,
        unit: SizeUnit,
        limit: u64,
    },
    /// `function` は値を作ろうとした関数の修飾した名前、または演算子の記号
    ValueTooLarge {
        function: &'static str,
        size: u64,
        unit: SizeUnit,
        limit: u64,
    },
    /// 読む大きさが決まっていない入力を読む操作が、上限を超えた（02-09「一つの操作で作る値の大きさの上限」、
    /// 02-10「実行時エラーと資源の不足の報告」）。結果の大きさは決まらないので持たない。
    /// `function` は操作の修飾した名前（`Benitoite.IO.File.readText` など）
    InputTooLarge {
        function: &'static str,
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

pub mod assert;
