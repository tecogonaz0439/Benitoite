//! 処理系が補う関数の引数名（設計書 02-05「型とエフェクトの表現」「出力」）。

pub(crate) const VALUE: &str = "value";
pub(crate) const LEFT: &str = "left";
pub(crate) const RIGHT: &str = "right";
pub(crate) const XS: &str = "xs";
pub(crate) const INDEX: &str = "index";
pub(crate) const FRONT: &str = "front";
pub(crate) const BACK: &str = "back";

/// 位置は 1 から数える。構成子と旧関数型・旧部分適用で同じ綴りを使う。
pub(crate) fn positional(position: usize) -> String {
    format!("arg{position}")
}

/// 指定した引数数に対し、宣言順の補完名を作る。
pub(crate) fn positional_names(arity: usize) -> Vec<String> {
    (1..=arity).map(positional).collect()
}
