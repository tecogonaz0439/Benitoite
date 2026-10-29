//! 型の確定から独立した Scope の必須判定の入力
//! （設計書 02-05「Scope の必須判定の入力」）。
//! 構造を先に収集し、番号付けだけに必要な補間の変換の有無を後から補う。

mod accept;
mod input;
mod local;
mod lower;
pub use accept::*;
pub use local::*;
#[cfg(test)]
mod accept_tests;
#[cfg(test)]
mod local_tests;
#[cfg(test)]
mod numbering_budget_tests;
#[cfg(test)]
mod tests;

use crate::base::{BindingId, NodeId, NodeMap, Span};

/// Lean の ruleDeclarations が認定する標準宣言。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeDeclaration {
    /// パスの検査。
    CheckPath,
    /// 要求の検査。
    CheckRequest,
    /// パスの射影。
    PathValue,
    /// 要求の射影。
    RequestValue,
    /// パスの明示拡大。
    WidenPath,
    /// 要求の明示拡大。
    WidenRequest,
}

impl ScopeDeclaration {
    /// Lean の標準宣言の名前。
    pub fn name(self) -> &'static str {
        match self {
            Self::CheckPath => "Scope.checkPathIn",
            Self::CheckRequest => "Http.checkRequestIn",
            Self::PathValue => "Scope.pathInValue",
            Self::RequestValue => "Http.requestInValue",
            Self::WidenPath => "Scope.widenPathIn",
            Self::WidenRequest => "Http.widenRequestIn",
        }
    }
}

/// 定義の名前と表層の先行順番号の組。AST の NodeId と区別する。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeKey {
    /// モジュールを含む元定義名。入れ子も囲む定義名を保つ。
    pub definition: String,
    /// 本体の先頭の右辺は 0。
    pub surface_preorder: u64,
}

/// 本体入口の束縛番号。Lean の de Bruijn の位置に Rust の束縛を対応させる。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeEntry {
    /// 明示的な辞書の引数の個数。メソッドが捕捉した実装自身の辞書は含めない。
    pub dictionaries: usize,
    /// entryScope.idAt(index) = index に対応する束縛。最後の値引数が位置 0、辞書は None。
    pub positions: Vec<Option<BindingId>>,
    /// 次に使う新しい束縛番号。
    pub next_id: u64,
}

/// 表層への正規化で得る出現の由来。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeOrigin {
    /// 元の式。
    Expression(NodeId),
    /// else if の式。
    Conditional(NodeId),
    /// 複数の with を一つずつの with へ写した位置。
    WithBinding(NodeId),
    /// リストの展開が補う concatenate。
    ListConcatenate(NodeId),
    /// 文字列補間の変換関数。
    InterpolationConverter(NodeId),
}

/// 番号を付けた一つの表層の式。容器や専用束縛には項目を作らない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeOccurrence {
    /// 本体内の先行順番号。
    pub preorder: u64,
    /// 元の式または正規化で補う式の由来。
    pub origin: ScopeOrigin,
    /// 元ソースの位置。
    pub span: Span,
}

/// 構文上の全文の始まり。preorder は右辺の出現の番号と同じである。
/// Lean の局所解析が実際に事実を記録する位置の集合とは区別する。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeStatement {
    /// 元の文のノード番号。
    pub statement: NodeId,
    /// 右辺のノード番号。
    pub rhs: NodeId,
    /// 右辺の先行順番号。
    pub preorder: u64,
}

/// 契約位置の引数の供給元。パイプの左辺は呼び出しの子として数え直さない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeArgumentSource {
    /// 呼び出しに明示した、ソース順の引数の位置。
    Explicit(usize),
    /// パイプの左辺。契約位置 0 に入り、範囲の読み取りでは未知として扱う。
    PipeLeft(NodeId),
}

/// 標準と同定された直接呼び出し。ソース順と契約順を別々に保つ。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeCall {
    /// 呼び出し式の先行順番号。
    pub preorder: u64,
    /// 呼び出し式のノード番号。
    pub node: NodeId,
    /// 所有元と宣言の同一性を確認した標準の宣言。
    pub declaration: ScopeDeclaration,
    /// 解決済みの標準宣言の束縛番号。
    pub binding: BindingId,
    /// ソース順の引数のノード番号。
    pub arguments: Vec<NodeId>,
    /// ソース順の引数自身の開始番号。停止時は取得できた接頭辞を保つ。
    pub argument_preorders: Vec<u64>,
    /// ソース順の各引数の契約内の位置。
    pub source_to_contract: Vec<usize>,
    /// 契約順の各引数の供給元。明示引数とパイプの左辺を区別する。
    pub contract_to_source: Vec<ScopeArgumentSource>,
}

/// 局所解析の予算の上限の範囲。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeBudgetScope {
    /// 一つの本体。
    Body,
    /// 囲む定義の中で、入れ子の本体を含む全体。
    Whole,
}

/// 予算を超過した資源。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeBudgetResource {
    /// 操作の回数。
    Operations,
    /// 保持する項目の数。
    Items,
}

/// 共有定数の展開を含む、一つの定義の番号付けのイベント上限。
/// Lean にない Rust だけの資源制限であり、局所解析の ScopeLimits と分離する。
/// 普通の文の密度と上限への到達を release 測定で確認する（設計書 02-05）。
pub const DEFAULT_NUMBERING_OPERATIONS: u64 = 200_000;

/// 番号付けで承認したイベント数。局所解析の操作数へ足さない。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ScopeNumberingBudget {
    /// 入れ子と共有定数の展開を含むイベントの累積数。
    pub operations: u64,
}

/// 入力の取得を止めた理由。未知の事実や Top の選択とは区別する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScopeInputStop {
    /// 番号付けの資源上限。全規則が Top を要求し、リテラルも保持しない。
    NumberingLimit {
        /// 一つの定義に許す番号イベント数。
        max_operations: u64,
    },
    /// 局所解析の予算の超過。未知の入力と区別し、範囲・資源を保つ。
    BudgetExceeded {
        /// 超過した上限の範囲。
        scope: ScopeBudgetScope,
        /// 超過した資源。
        resource: ScopeBudgetResource,
    },
    /// 構文の深さが入力取得の上限を超えた。
    Depth,
    /// 番号を表現できない。
    NumberOverflow,
    /// 入力の参照・宣言・引数の対応が欠けている。
    MissingInput(NodeId),
    /// 補間の変換の有無がまだ決まっていない。
    PendingInterpolation(NodeId),
}

/// 一つの本体を読み取り、番号を付けた入力。局所解析の結果や型の表を含まない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScopeNumberedInput {
    /// 本体の入口の鍵。番号は常に 0。
    pub body_key: ScopeKey,
    /// 元定義の束縛番号。名前解決の入力が欠けた場合は None。
    pub binding: Option<BindingId>,
    /// 辞書の引数を含む入口の束縛番号。
    pub entry: ScopeEntry,
    /// 取得できた出現の接頭辞。
    pub occurrences: Vec<ScopeOccurrence>,
    /// 文の始まりと右辺の同じ番号。
    pub statements: Vec<ScopeStatement>,
    /// 同定できた標準の直接呼び出し。
    pub calls: Vec<ScopeCall>,
    /// この本体の番号付けで承認されたイベント数。局所解析の stepCost には加えない。
    pub numbering_operations: u64,
    /// 未取得の理由。停止後の番号を詰め直さない。
    pub stopped: Option<ScopeInputStop>,
}

/// 元定義一つの共有された構造入力。定数の参照先を本体ごとに複写しない。
#[derive(Clone, Debug)]
pub struct ScopeBodyInput {
    /// 本体の入口の鍵。番号は常に 0。
    pub body_key: ScopeKey,
    /// 元定義の束縛番号。名前解決の入力が欠けた場合は None。
    pub binding: Option<BindingId>,
    /// 明示的な辞書の引数と値引数の入口。
    pub entry: ScopeEntry,
    structure: std::sync::Arc<input::Structure>,
    converters: std::sync::Arc<NodeMap<bool>>,
    index: usize,
}

impl ScopeBodyInput {
    /// 前段で診断された構文のエラーノードを含む。定数の参照先も含める。
    /// この入力は既に不正であり、情報の欠落による内部エラーを重ねない。
    pub fn has_diagnosed_input(&self) -> bool {
        self.structure
            .diagnosed
            .get(self.index)
            .copied()
            .unwrap_or(false)
    }

    /// 番号付けと定数の展開に依存せず、構文順の規則の呼び出しを返す。
    /// 各項目の preorder と argument_preorders は未採番であり、照合には使わない。
    /// 定数の値式に呼び出しは許されないため、定数の参照先の展開は不要である。
    pub fn rule_calls(&self) -> Vec<ScopeCall> {
        self.structure.rule_calls(self.index)
    }

    /// 定数の参照先を含め、規則対象の直接呼び出しを含むかを共有表から読む。
    /// 規則がない本体の自明な受理には番号列の展開を要しない。
    /// 構造の収集で停止した本体も true とし、規則なしと判定しない。
    /// 番号の読み取りでの深さ・予算の停止は、収集済みの規則の有無を変えない。
    pub fn contains_rules(&self) -> bool {
        self.structure.contains_rules(self.index)
    }

    /// 比較・診断・後続の解析のために、この本体の番号付き入力を読み取る。
    /// 定数を参照する各出現も、囲む定義の同じ先行順で展開する。
    /// 各イベントの読み取りの前に一操作を計上し、上限を超える操作を行う前に止める。
    pub fn numbered(&self, max_operations: u64) -> ScopeNumberedInput {
        self.number(max_operations, false)
    }

    fn number(&self, max_operations: u64, pending: bool) -> ScopeNumberedInput {
        self.number_with_budget(
            max_operations,
            &mut ScopeNumberingBudget::default(),
            pending,
        )
    }

    /// 局所解析と独立したイベント上限で番号を読む。拒否されたイベントは計上しない。
    pub fn numbered_with_budget(
        &self,
        max_operations: u64,
        budget: &mut ScopeNumberingBudget,
    ) -> ScopeNumberedInput {
        self.number_with_budget(max_operations, budget, false)
    }

    pub(super) fn number_with_budget(
        &self,
        max_operations: u64,
        budget: &mut ScopeNumberingBudget,
        pending: bool,
    ) -> ScopeNumberedInput {
        self.structure.number(
            self.index,
            max_operations,
            budget,
            &self.converters,
            pending,
            ScopeNumberedInput {
                body_key: self.body_key.clone(),
                binding: self.binding,
                entry: self.entry.clone(),
                occurrences: Vec::new(),
                statements: Vec::new(),
                calls: Vec::new(),
                numbering_operations: 0,
                stopped: None,
            },
        )
    }
}

/// 元ソースの順の入力。型検査の公開入口から後続へ渡す。
#[derive(Clone, Debug, Default)]
pub struct ScopeInputs {
    /// 本体を持つ全ての定数・関数・実装メソッド。
    pub bodies: Vec<ScopeBodyInput>,
    by_binding: crate::base::BindingMap<usize>,
}

impl ScopeInputs {
    /// 解決済みの束縛から本体を読む。各関数の検査で全本体を走査し直さない。
    pub fn lookup(&self, binding: BindingId) -> Option<&ScopeBodyInput> {
        self.bodies
            .get(*self.by_binding.get(binding)?)
            .filter(|body| body.binding == Some(binding))
    }

    /// 型の確定後に、番号ラベルだけに使う補間の変換の有無を同じ不変の表へ更新する。
    pub fn finish_interpolations(&mut self, converters: NodeMap<bool>) {
        let converters = std::sync::Arc::new(converters);
        for body in &mut self.bodies {
            body.converters = std::sync::Arc::clone(&converters);
        }
    }
}

/// 構造入力は宣言検査直後に作る。ここには推論後の型も警告も入らない。
#[derive(Default)]
pub(in crate::typeck) struct Inputs {
    bodies: Vec<input::PendingBody>,
    converters: NodeMap<bool>,
}

impl Inputs {
    /// 補間の型から確定した番号付け用の真偽値だけを返す。
    pub fn interpolation_map(&self) -> NodeMap<bool> {
        self.converters.clone()
    }

    pub fn collect(
        asts: &[crate::syntax::ast::Module],
        modules: &crate::modules::ModuleTable,
        resolved: &crate::resolve::ResolveOutput,
        schemes: &crate::base::BindingMap<crate::types::Scheme>,
        implementations: &crate::base::NodeMap<crate::types::ImplDef>,
    ) -> Self {
        Self {
            bodies: input::collect(asts, modules, resolved, schemes, implementations),
            converters: NodeMap::default(),
        }
    }

    /// 補間の番号付けに必要な Boolean だけを保存する。finalize や区間解析を呼ばない。
    pub fn interpolation(&mut self, node: NodeId, converter: bool) {
        self.converters.insert(node, converter);
    }

    pub fn finish(self) -> ScopeInputs {
        input::finish(self.bodies, self.converters)
    }
}
