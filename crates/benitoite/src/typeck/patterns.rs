//! パターンの検査: 網羅性と選ばれない分岐（設計書 02-05「本体の後の検査」、01-05）。
//!
//! 判定は、パターンの行列に対する有用性（usefulness）で行う（設計書 02-05「本体の後の検査」）。
//! 算法は L. Maranget「Warnings for pattern matching」（2007）の有用性の算法の形で、
//! 列を一つずつ減らす再帰で書く。再帰の深さはパターンの大きさで決まり、分岐の数によらない
//! （行の並びは `Vec` で持つ。実装の規約「再帰の深さ」）。

use crate::types::{AdtDef, AdtTable, CtorDef, Ty, TyCon};

/// 検査に使うパターン。変数のパターンは `Wild` にする（どちらもすべての値に照合する）。
#[derive(Clone, PartialEq, Debug)]
pub enum Pat {
    Wild,
    Ctor {
        con: TyCon,
        tag: u32,
        args: Vec<Pat>,
    },
    Int(i64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
}

/// 検査の結果。
#[derive(Clone, PartialEq, Debug)]
pub enum MatchIssue {
    /// 網羅していない。`witness` はどの分岐にも照合しない値の形（`Tree.Node(Tree.Leaf, _, _)` など）
    NonExhaustive { witness: String },
    /// `arm` 番目（0 から数える）の分岐は選ばれない。`covered_by` は覆っている前の分岐の番号（昇順）
    Unreachable { arm: usize, covered_by: Vec<usize> },
}

/// 一つの `match` を検査する。`arms` は分岐のパターンを順に並べたもの。
/// 選ばれない分岐を分岐の順に、その後に網羅していないこと（あれば一つ）を返す。
/// 構成子の名前の表示は、利用者の型は `型名.構成子名`、`Option`・`Result` は `Some` などの修飾しない名前とする。
pub fn check_match(scrutinee: &Ty, arms: &[Pat], adts: &AdtTable) -> Vec<MatchIssue> {
    let tys = [ColTy::Known(scrutinee.clone())];
    let mut issues = Vec::new();
    // 前の分岐を一行ずつ積む。分岐 pi は p0 から p(i-1) の行列に対して有用でなければ選ばれない
    // （設計書 01-05「選ばれない分岐の検査」）。p0 は常に選ばれうるので調べない。
    let mut rows: Vec<Row<'_>> = Vec::with_capacity(arms.len());
    for (i, arm) in arms.iter().enumerate() {
        if !rows.is_empty() && useful(&rows, &[arm], &tys, adts).is_none() {
            issues.push(MatchIssue::Unreachable {
                arm: i,
                covered_by: covering_arms(arms, i, arm, &tys, adts),
            });
        }
        rows.push(vec![arm]);
    }
    // 網羅性はワイルドカード一つの並びの有用性で判定し、選ばれない分岐の有無によらず調べる
    // （設計書 02-05「本体の後の検査」）。
    if let Some(witnesses) = useful(&rows, &[wild()], &tys, adts) {
        issues.push(MatchIssue::NonExhaustive {
            witness: witnesses
                .into_iter()
                .next()
                .unwrap_or_else(|| WILD_TEXT.to_string()),
        });
    }
    issues
}

/// 反例の中の、形を問わない位置の表示。
const WILD_TEXT: &str = "_";

/// 行列の一行。列の順にパターンを並べる。
type Row<'p> = Vec<&'p Pat>;

/// 特殊化で増やす列に置くワイルドカード。
fn wild() -> &'static Pat {
    &Pat::Wild
}

/// 列の型。`Opaque` は、表にない構成子の引数など、型の分からない列を表し、
/// 構成子を持たない型として扱う（作業 T16「有用性の判定」）。
#[derive(Clone, Debug)]
enum ColTy {
    Known(Ty),
    Opaque,
}

/// 列の型の構成子の集まり（設計書 02-05「本体の後の検査」の最後の段落）。
#[derive(Clone, Copy, Debug)]
enum Space<'t> {
    /// 代数的データ型（`Option`・`Result` を含む）。宣言の構成子の全体で網羅できる
    Adt {
        def: &'t AdtDef,
        args: &'t [Ty],
    },
    /// `true`・`false` で網羅できる
    Bool,
    /// `()` で網羅できる
    Unit,
    /// リテラルの集まりは無限とみなす（`Char` も同じ。設計書 01-05「網羅性の検査」）
    Int,
    Str,
    Char,
    /// 構成子を持たない型（`Float`、`List[T]`、関数の型、`IoError`、型パラメータ）
    Empty,
}

fn space_of<'t>(ty: &'t ColTy, adts: &'t AdtTable) -> Space<'t> {
    let ColTy::Known(ty) = ty else {
        return Space::Empty;
    };
    match ty {
        Ty::Con(c, args) => match c {
            TyCon::Int => Space::Int,
            TyCon::String => Space::Str,
            TyCon::Char => Space::Char,
            TyCon::Bool => Space::Bool,
            TyCon::Unit => Space::Unit,
            TyCon::Float | TyCon::List | TyCon::IoError => Space::Empty,
            TyCon::Option | TyCon::Result | TyCon::Adt(_) => adts
                .get(*c)
                .map_or(Space::Empty, |def| Space::Adt { def, args }),
        },
        Ty::Fn(_) | Ty::Param(_) => Space::Empty,
    }
}

/// 列の先頭に現れる構成子（リテラルは引数のない構成子として扱う）。
#[derive(Clone, Copy, PartialEq, Debug)]
enum Head<'p> {
    Ctor(u32),
    Int(i64),
    Str(&'p str),
    Char(char),
    Bool(bool),
    Unit,
}

/// 列の型に照らしたパターンの形。
enum Shape<'p> {
    Wild,
    Head(Head<'p>, &'p [Pat]),
    /// 列の型と食い違うパターン。T15 は渡さないはずだが、渡されたらどの値にも照合しないものとして扱う
    /// （作業 T16「有用性の判定」。panic しない）
    Never,
}

fn classify<'p>(p: &'p Pat, space: Space<'_>) -> Shape<'p> {
    match (p, space) {
        (Pat::Wild, _) => Shape::Wild,
        (Pat::Ctor { con, tag, args }, Space::Adt { def, .. }) => {
            let fits =
                *con == def.con && ctor_of(def, *tag).is_some_and(|c| c.fields.len() == args.len());
            if fits {
                Shape::Head(Head::Ctor(*tag), args)
            } else {
                Shape::Never
            }
        }
        (Pat::Int(n), Space::Int) => Shape::Head(Head::Int(*n), &[]),
        (Pat::Str(s), Space::Str) => Shape::Head(Head::Str(s), &[]),
        (Pat::Char(c), Space::Char) => Shape::Head(Head::Char(*c), &[]),
        (Pat::Bool(b), Space::Bool) => Shape::Head(Head::Bool(*b), &[]),
        (Pat::Unit, Space::Unit) => Shape::Head(Head::Unit, &[]),
        _ => Shape::Never,
    }
}

fn ctor_of(def: &AdtDef, tag: u32) -> Option<&CtorDef> {
    def.ctors.iter().find(|c| c.tag == tag)
}

/// 有限の集まりの構成子の全体を、反例に選ぶ順（タグの順、`true` の次に `false`）に返す。
/// 無限の集まりと構成子を持たない型は `None`。
fn finite_heads(space: Space<'_>) -> Option<Vec<Head<'static>>> {
    match space {
        Space::Adt { def, .. } => Some(def.ctors.iter().map(|c| Head::Ctor(c.tag)).collect()),
        Space::Bool => Some(vec![Head::Bool(true), Head::Bool(false)]),
        Space::Unit => Some(vec![Head::Unit]),
        Space::Int | Space::Str | Space::Char | Space::Empty => None,
    }
}

fn arity(space: Space<'_>, head: Head<'_>) -> usize {
    match (head, space) {
        (Head::Ctor(tag), Space::Adt { def, .. }) => {
            ctor_of(def, tag).map_or(0, |c| c.fields.len())
        }
        _ => 0,
    }
}

/// 構成子 `head` で特殊化した後の列の型: 構成子の引数の型を並べ、その後に残りの列の型を続ける。
fn specialized_tys(
    space: Space<'_>,
    head: Head<'_>,
    adts: &AdtTable,
    rest: &[ColTy],
) -> Vec<ColTy> {
    let mut out: Vec<ColTy> = match (head, space) {
        (Head::Ctor(tag), Space::Adt { def, args }) => match adts.field_types(def.con, tag, args) {
            Some(tys) => tys.into_iter().map(ColTy::Known).collect(),
            // 表にない構成子は起きないはずなので、引数の列を構成子を持たない型として続ける
            None => vec![ColTy::Opaque; arity(space, head)],
        },
        _ => Vec::new(),
    };
    out.extend_from_slice(rest);
    out
}

/// 特殊化した行列: 先頭が `head` の行は引数を展開し、先頭がワイルドカードの行は
/// ワイルドカードを `arity` 個に広げ、それ以外の行は除く。
fn specialize<'p>(
    rows: &[Row<'p>],
    space: Space<'_>,
    head: Head<'_>,
    arity: usize,
) -> Vec<Row<'p>> {
    let mut out = Vec::new();
    for row in rows {
        let Some((&first, rest)) = row.split_first() else {
            continue;
        };
        let mut new_row: Row<'p> = match classify(first, space) {
            Shape::Wild => vec![wild(); arity],
            Shape::Head(h, args) if h == head => args.iter().collect(),
            Shape::Head(..) | Shape::Never => continue,
        };
        new_row.extend_from_slice(rest);
        out.push(new_row);
    }
    out
}

/// 既定の行列: 先頭がワイルドカードの行だけを残し、先頭の列を除く。
fn default_rows<'p>(rows: &[Row<'p>], space: Space<'_>) -> Vec<Row<'p>> {
    rows.iter()
        .filter_map(|row| {
            let (&first, rest) = row.split_first()?;
            matches!(classify(first, space), Shape::Wild).then(|| rest.to_vec())
        })
        .collect()
}

/// 行列の先頭の列に `head` が現れるか（Σ に含まれるか）。
fn head_present(rows: &[Row<'_>], space: Space<'_>, head: Head<'_>) -> bool {
    rows.iter().any(|row| {
        row.first()
            .is_some_and(|p| matches!(classify(p, space), Shape::Head(h, _) if h == head))
    })
}

/// 先頭の列の構成子の集まり Σ が型の構成子の全体なら、その全体を返す。
/// 無限の集まりと構成子を持たない型は、常に `None`（既定の行列を使う）。
fn complete_heads(rows: &[Row<'_>], space: Space<'_>) -> Option<Vec<Head<'static>>> {
    let all = finite_heads(space)?;
    all.iter()
        .all(|h| head_present(rows, space, *h))
        .then_some(all)
}

/// 既定の行列で反例を見つけたときの、先頭の列の反例（作業 T16「反例の組み立て」）。
/// 有限の集まりで Σ に現れない構成子があれば、タグの最も小さいものを引数を `_` にして示す。
/// 無限の集まり、構成子を持たない型、Σ が空のときは `_` を示す。
fn missing_head_witness(rows: &[Row<'_>], space: Space<'_>) -> String {
    let sigma_empty = !rows.iter().any(|row| {
        row.first()
            .is_some_and(|p| matches!(classify(p, space), Shape::Head(..)))
    });
    if sigma_empty {
        return WILD_TEXT.to_string();
    }
    let missing = finite_heads(space)
        .and_then(|all| all.into_iter().find(|h| !head_present(rows, space, *h)));
    match missing {
        Some(head) => {
            let args = vec![WILD_TEXT.to_string(); arity(space, head)];
            show_head(space, head, &args)
        }
        None => WILD_TEXT.to_string(),
    }
}

/// 構成子とその引数の反例から、値の形の表示を作る。
fn show_head(space: Space<'_>, head: Head<'_>, args: &[String]) -> String {
    match head {
        Head::Ctor(tag) => {
            let Space::Adt { def, .. } = space else {
                return WILD_TEXT.to_string();
            };
            let Some(ctor) = ctor_of(def, tag) else {
                return WILD_TEXT.to_string();
            };
            // 利用者の型の構成子は型名で修飾し、Option・Result の構成子は修飾しない（設計書 01-05「パターン」）
            let name = if matches!(def.con, TyCon::Adt(_)) {
                format!("{}.{}", def.name, ctor.name)
            } else {
                ctor.name.clone()
            };
            if args.is_empty() {
                name
            } else {
                format!("{name}({})", args.join(", "))
            }
        }
        Head::Int(n) => n.to_string(),
        Head::Str(s) => format!("{s:?}"),
        Head::Char(c) => format!("{c:?}"),
        Head::Bool(b) => b.to_string(),
        Head::Unit => "()".to_string(),
    }
}

/// 特殊化した並びの反例の先頭 `arity` 個を、構成子 `head` の引数としてまとめる。
fn rebuild(
    space: Space<'_>,
    head: Head<'_>,
    arity: usize,
    mut witnesses: Vec<String>,
) -> Vec<String> {
    let args: Vec<String> = witnesses.drain(..arity.min(witnesses.len())).collect();
    let mut out = Vec::with_capacity(witnesses.len().saturating_add(1));
    out.push(show_head(space, head, &args));
    out.extend(witnesses);
    out
}

/// パターンの並び `q` が行列 `rows` に対して有用か（`q` に照合し、`rows` のどの行にも照合しない
/// 値の並びがあるか）を判定する（設計書 02-05「本体の後の検査」）。
/// 有用なら、その値の並びの形（列ごとの表示）を返す。`tys` は列の型。
fn useful<'p>(
    rows: &[Row<'p>],
    q: &[&'p Pat],
    tys: &[ColTy],
    adts: &AdtTable,
) -> Option<Vec<String>> {
    let Some((&q0, q_rest)) = q.split_first() else {
        // 列が尽きた: 行が一つでも残れば、その行が照合する
        return rows.is_empty().then(Vec::new);
    };
    let (ty0, ty_rest) = match tys.split_first() {
        Some((t, r)) => (t, r),
        None => (&ColTy::Opaque, tys),
    };
    let space = space_of(ty0, adts);
    match classify(q0, space) {
        Shape::Never => None,
        Shape::Head(head, args) => {
            let sub_rows = specialize(rows, space, head, args.len());
            let mut sub_q: Vec<&'p Pat> = args.iter().collect();
            sub_q.extend_from_slice(q_rest);
            let sub_tys = specialized_tys(space, head, adts, ty_rest);
            let witnesses = useful(&sub_rows, &sub_q, &sub_tys, adts)?;
            Some(rebuild(space, head, args.len(), witnesses))
        }
        Shape::Wild => {
            if let Some(all) = complete_heads(rows, space) {
                // Σ が全体: 構成子ごとに特殊化して調べ、反例に選ぶ順で最初に見つけたものを返す
                for head in all {
                    let n = arity(space, head);
                    let sub_rows = specialize(rows, space, head, n);
                    let mut sub_q: Vec<&'p Pat> = vec![wild(); n];
                    sub_q.extend_from_slice(q_rest);
                    let sub_tys = specialized_tys(space, head, adts, ty_rest);
                    if let Some(witnesses) = useful(&sub_rows, &sub_q, &sub_tys, adts) {
                        return Some(rebuild(space, head, n, witnesses));
                    }
                }
                None
            } else {
                let sub_rows = default_rows(rows, space);
                let mut witnesses = useful(&sub_rows, q_rest, ty_rest, adts)?;
                witnesses.insert(0, missing_head_witness(rows, space));
                Some(witnesses)
            }
        }
    }
}

/// 選ばれない分岐 `arm`（`i` 番目）を覆っている前の分岐を選ぶ（設計書 02-05「本体の後の検査」）。
/// 一つで覆う分岐があれば最初のもの一つを、なければ覆う最短の前置の並びのうち `arm` と重なる分岐を返す。
fn covering_arms(arms: &[Pat], i: usize, arm: &Pat, tys: &[ColTy], adts: &AdtTable) -> Vec<usize> {
    let prev = arms.get(..i).unwrap_or(&[]);
    for (j, p) in prev.iter().enumerate() {
        if useful(&[vec![p]], &[arm], tys, adts).is_none() {
            return vec![j];
        }
    }
    let mut rows: Vec<Row<'_>> = Vec::with_capacity(prev.len());
    for (k, p) in prev.iter().enumerate() {
        rows.push(vec![p]);
        if useful(&rows, &[arm], tys, adts).is_none() {
            return prev
                .iter()
                .enumerate()
                .take_while(|(j, _)| *j <= k)
                .filter(|(_, p)| overlaps(p, arm))
                .map(|(j, _)| j)
                .collect();
        }
    }
    Vec::new()
}

/// 二つのパターンが重なるか（両方に照合する値があるか。設計書 02-05「本体の後の検査」）。
fn overlaps(a: &Pat, b: &Pat) -> bool {
    match (a, b) {
        (Pat::Wild, _) | (_, Pat::Wild) => true,
        (
            Pat::Ctor {
                con: c1,
                tag: t1,
                args: a1,
            },
            Pat::Ctor {
                con: c2,
                tag: t2,
                args: a2,
            },
        ) => {
            c1 == c2
                && t1 == t2
                && a1.len() == a2.len()
                && a1.iter().zip(a2).all(|(x, y)| overlaps(x, y))
        }
        (Pat::Int(x), Pat::Int(y)) => x == y,
        (Pat::Str(x), Pat::Str(y)) => x == y,
        (Pat::Char(x), Pat::Char(y)) => x == y,
        (Pat::Bool(x), Pat::Bool(y)) => x == y,
        (Pat::Unit, Pat::Unit) => true,
        _ => false,
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)] // テストの失敗は panic で表す（実装の規約「#[allow] を書いてよい箇所」）
mod tests {
    use super::*;
    use crate::base::BindingId;
    use crate::types::EqSummary;

    const TREE: TyCon = TyCon::Adt(BindingId(100));
    const L: TyCon = TyCon::Adt(BindingId(200));
    /// 表にない利用者の型
    const MISSING: TyCon = TyCon::Adt(BindingId(300));

    fn ctor(name: &str, binding: u32, tag: u32, fields: Vec<Ty>) -> CtorDef {
        CtorDef {
            name: name.to_string(),
            binding: BindingId(binding),
            tag,
            fields,
        }
    }

    fn adt(con: TyCon, name: &str, type_params: &[&str], ctors: Vec<CtorDef>) -> AdtDef {
        AdtDef {
            con,
            name: name.to_string(),
            type_params: type_params.iter().map(|s| s.to_string()).collect(),
            ctors,
            eq_summary: EqSummary::default(),
        }
    }

    /// `Option`・`Result` と、`type Tree[T] { Leaf  Node(Tree[T], T, Tree[T]) }`、`type L { Mk(L) }`。
    fn table() -> AdtTable {
        let tree_t = Ty::Con(TREE, vec![Ty::Param(0)]);
        AdtTable {
            adts: vec![
                adt(
                    TyCon::Option,
                    "Option",
                    &["T"],
                    vec![
                        ctor("Some", 1, 0, vec![Ty::Param(0)]),
                        ctor("None", 2, 1, vec![]),
                    ],
                ),
                adt(
                    TyCon::Result,
                    "Result",
                    &["T", "E"],
                    vec![
                        ctor("Ok", 3, 0, vec![Ty::Param(0)]),
                        ctor("Err", 4, 1, vec![Ty::Param(1)]),
                    ],
                ),
                adt(
                    TREE,
                    "Tree",
                    &["T"],
                    vec![
                        ctor("Leaf", 101, 0, vec![]),
                        ctor("Node", 102, 1, vec![tree_t.clone(), Ty::Param(0), tree_t]),
                    ],
                ),
                adt(L, "L", &[], vec![ctor("Mk", 201, 0, vec![Ty::con(L)])]),
            ],
        }
    }

    fn w() -> Pat {
        Pat::Wild
    }
    fn c(con: TyCon, tag: u32, args: Vec<Pat>) -> Pat {
        Pat::Ctor { con, tag, args }
    }
    fn some(p: Pat) -> Pat {
        c(TyCon::Option, 0, vec![p])
    }
    fn none() -> Pat {
        c(TyCon::Option, 1, vec![])
    }
    fn leaf() -> Pat {
        c(TREE, 0, vec![])
    }
    fn node(l: Pat, x: Pat, r: Pat) -> Pat {
        c(TREE, 1, vec![l, x, r])
    }
    fn mk(p: Pat) -> Pat {
        c(L, 0, vec![p])
    }
    fn tree_int() -> Ty {
        Ty::Con(TREE, vec![Ty::int()])
    }
    fn non_exhaustive(witness: &str) -> Vec<MatchIssue> {
        vec![MatchIssue::NonExhaustive {
            witness: witness.to_string(),
        }]
    }
    fn unreachable(arm: usize, covered_by: &[usize]) -> MatchIssue {
        MatchIssue::Unreachable {
            arm,
            covered_by: covered_by.to_vec(),
        }
    }

    /// 作業 T16 の受け入れテストの表。
    #[test]
    fn acceptance_table() {
        let adts = table();
        let cases: Vec<(&str, Ty, Vec<Pat>, Vec<MatchIssue>)> = vec![
            (
                "tree: leaf, node(leaf)",
                tree_int(),
                vec![leaf(), node(leaf(), w(), w())],
                non_exhaustive("Tree.Node(Tree.Node(_, _, _), _, _)"),
            ),
            (
                "tree: node only",
                tree_int(),
                vec![node(w(), w(), w())],
                non_exhaustive("Tree.Leaf"),
            ),
            (
                "tree: complete",
                tree_int(),
                vec![leaf(), node(w(), w(), w())],
                vec![],
            ),
            (
                "tree: leaf only",
                tree_int(),
                vec![leaf()],
                non_exhaustive("Tree.Node(_, _, _)"),
            ),
            (
                "tree: duplicated leaf",
                tree_int(),
                vec![leaf(), leaf(), node(w(), w(), w())],
                vec![unreachable(1, &[0])],
            ),
            (
                "int: wildcard first",
                Ty::int(),
                vec![w(), Pat::Int(0)],
                vec![unreachable(1, &[0])],
            ),
            (
                "int: literals only",
                Ty::int(),
                vec![Pat::Int(0), Pat::Int(1)],
                non_exhaustive("_"),
            ),
            (
                "int: literals and variable",
                Ty::int(),
                vec![Pat::Int(0), Pat::Int(-1), w()],
                vec![],
            ),
            (
                "int: unreachable and non-exhaustive together",
                Ty::int(),
                vec![Pat::Int(0), Pat::Int(0)],
                vec![
                    unreachable(1, &[0]),
                    MatchIssue::NonExhaustive {
                        witness: "_".to_string(),
                    },
                ],
            ),
            (
                "bool: complete",
                Ty::bool(),
                vec![Pat::Bool(true), Pat::Bool(false)],
                vec![],
            ),
            (
                "bool: true only",
                Ty::bool(),
                vec![Pat::Bool(true)],
                non_exhaustive("false"),
            ),
            ("unit: complete", Ty::unit(), vec![Pat::Unit], vec![]),
            (
                "string: literals only",
                Ty::string(),
                vec![Pat::Str("yes".to_string()), Pat::Str("no".to_string())],
                non_exhaustive("_"),
            ),
            (
                "option of option",
                Ty::option(Ty::option(Ty::int())),
                vec![some(some(w())), none()],
                non_exhaustive("Some(None)"),
            ),
            (
                "result: covered by a prefix",
                Ty::result(Ty::int(), Ty::string()),
                vec![
                    c(TyCon::Result, 0, vec![w()]),
                    c(TyCon::Result, 1, vec![w()]),
                    w(),
                ],
                vec![unreachable(2, &[0, 1])],
            ),
            (
                "option of bool: only overlapping arms cover",
                Ty::option(Ty::bool()),
                vec![
                    some(Pat::Bool(true)),
                    none(),
                    some(Pat::Bool(false)),
                    some(w()),
                ],
                vec![unreachable(3, &[0, 2])],
            ),
            (
                "uninhabited type: complete",
                Ty::con(L),
                vec![mk(w())],
                vec![],
            ),
            (
                "uninhabited type: nested arm unreachable",
                Ty::con(L),
                vec![mk(w()), mk(mk(w()))],
                vec![unreachable(1, &[0])],
            ),
            ("float: variable", Ty::float(), vec![w()], vec![]),
            (
                "list: second wildcard",
                Ty::list(Ty::int()),
                vec![w(), w()],
                vec![unreachable(1, &[0])],
            ),
            ("type parameter", Ty::Param(0), vec![w()], vec![]),
        ];
        for (name, ty, arms, expected) in cases {
            assert_eq!(check_match(&ty, &arms, &adts), expected, "case: {name}");
        }
    }

    /// 反例は、Σ が全体の列ではタグの順で最初に見つけた構成子、足りない列では最も小さいタグの
    /// 構成子を選ぶ。`Char` はリテラルを並べても網羅しない（設計書 01-05「網羅性の検査」）。
    #[test]
    fn witness_selection() {
        let adts = table();
        let cases: Vec<(Ty, Vec<Pat>, &str)> = vec![
            (Ty::option(Ty::bool()), vec![], "_"),
            (Ty::bool(), vec![Pat::Bool(false)], "true"),
            (
                Ty::option(Ty::bool()),
                vec![some(Pat::Bool(false)), none()],
                "Some(true)",
            ),
            (
                Ty::result(Ty::unit(), Ty::int()),
                vec![
                    c(TyCon::Result, 0, vec![Pat::Unit]),
                    c(TyCon::Result, 1, vec![Pat::Int(3)]),
                ],
                "Err(_)",
            ),
            (Ty::char(), vec![Pat::Char('a'), Pat::Char('b')], "_"),
            (
                tree_int(),
                vec![leaf(), node(w(), Pat::Int(1), w())],
                "Tree.Node(_, _, _)",
            ),
            (
                tree_int(),
                vec![leaf(), node(leaf(), w(), w()), node(w(), w(), leaf())],
                "Tree.Node(Tree.Node(_, _, _), _, Tree.Node(_, _, _))",
            ),
        ];
        for (ty, arms, witness) in cases {
            assert_eq!(
                check_match(&ty, &arms, &adts),
                non_exhaustive(witness),
                "arms: {arms:?}"
            );
        }
    }

    /// 列の型と食い違うパターン（表にない構成子、ほかの型の構成子、引数の個数の違い、
    /// ほかの型のリテラル）は、どの値にも照合しないものとして扱い、panic しない。
    #[test]
    fn mismatched_patterns_match_nothing() {
        let adts = table();
        let cases: Vec<(Ty, Vec<Pat>)> = vec![
            (Ty::option(Ty::int()), vec![c(TyCon::Result, 0, vec![w()])]),
            (Ty::option(Ty::int()), vec![c(TyCon::Option, 7, vec![])]),
            (Ty::option(Ty::int()), vec![c(TyCon::Option, 0, vec![])]),
            (Ty::con(MISSING), vec![c(MISSING, 0, vec![w()])]),
            (Ty::bool(), vec![Pat::Int(1)]),
            (Ty::float(), vec![Pat::Unit]),
        ];
        for (ty, arms) in cases {
            assert_eq!(
                check_match(&ty, &arms, &adts),
                non_exhaustive("_"),
                "arms: {arms:?}"
            );
        }
        // 表にない型の構成子の引数の列も、構成子を持たない型として扱う
        let issues = check_match(
            &Ty::option(Ty::con(MISSING)),
            &[some(c(MISSING, 0, vec![])), some(w()), none()],
            &adts,
        );
        assert_eq!(issues, vec![]);
    }

    /// パターンの入れ子の深さが構文解析器の上限（1000）程度でも検査できる。
    #[test]
    fn deep_nesting() {
        let adts = table();
        let depth = 1000;
        let mut ty = Ty::int();
        let mut pat = Pat::Int(0);
        for _ in 0..depth {
            ty = Ty::option(ty);
            pat = some(pat);
        }
        let issues = check_match(&ty, &[pat.clone(), pat], &adts);
        assert_eq!(
            issues,
            vec![
                unreachable(1, &[0]),
                MatchIssue::NonExhaustive {
                    witness: "None".to_string()
                }
            ]
        );
    }

    /// 分岐が多くても、分岐の数に比例して再帰を深くしない。
    #[test]
    fn many_arms() {
        let adts = table();
        let n: i64 = 3000;
        let mut arms: Vec<Pat> = (0..n).map(Pat::Int).collect();
        arms.push(w());
        arms.push(Pat::Int(5));
        let issues = check_match(&Ty::int(), &arms, &adts);
        assert_eq!(issues, vec![unreachable(3001, &[5])]);
    }
}
