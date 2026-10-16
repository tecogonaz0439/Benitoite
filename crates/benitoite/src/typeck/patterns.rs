//! パターンの検査: 網羅性、選ばれない分岐、必ず照合するパターン（設計書 02-05「本体の後の検査」、01-05）。

use std::collections::{BTreeSet, HashMap};

use super::limits::MAX_COVERAGE_WORK;
use crate::base::{BindingId, ModuleId};
use crate::modules::ModuleTable;

/// 本体からパッケージ外にある、将来の形を考慮する ADT の集合。
/// 型表を複製せず、一つのソース照合の間は同じ集合を参照する。
pub type CoverageView = BTreeSet<BindingId>;

/// 型の指定と本体の所属から view を作る。公開範囲と同じパッケージ比較を使う。
pub fn coverage_view(modules: &ModuleTable, adts: &AdtTable, module: ModuleId) -> CoverageView {
    adts.adts
        .iter()
        .filter_map(|(id, adt)| {
            (adt.extensible && !crate::resolve::same_package(modules, module, adt.module))
                .then_some(id)
        })
        .collect()
}

/// 検査に使うパターン。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum Pat {
    /// ワイルドカードと変数のパターン（どちらもすべての値に照合する）
    Wild,
    /// 構成子のパターン（レコードを含む）。`adt` は型の宣言の束縛の番号
    Ctor {
        adt: BindingId,
        tag: u32,
        args: Vec<Pat>,
    },
    Integer(i64),
    Character(char),
    String(String),
    Boolean(bool),
    Unit,
    /// 範囲のパターン（両端を含む）
    IntegerRange(i64, i64),
    CharacterRange(char, char),
    /// リストのパターン。`rest` は `..` を書いたか
    List {
        before: Vec<Pat>,
        rest: bool,
        after: Vec<Pat>,
    },
}

/// `match` の分岐一つ。
#[derive(Clone, PartialEq, Debug)]
pub struct ArmPats {
    /// コンマで並べた選択肢
    pub alts: Vec<Pat>,
    /// ガードを持つか。ガードの付いた分岐の行は、後の分岐を覆うものに数えない（02-05「本体の後の検査」）
    pub guarded: bool,
}

/// 検査の結果。
#[derive(Clone, PartialEq, Debug)]
pub enum MatchIssue {
    /// 網羅していない。`witness` はどの分岐にも照合しない値の形（`Tree.Node(Tree.Leaf, _, _)` など）
    NonExhaustive {
        witness: String,
        future_types: BTreeSet<BindingId>,
    },
    /// `arm` 番目の分岐の `alt` 番目の選択肢（どちらも 0 から数える）は選ばれない。
    /// `covered_by` は覆っている前の分岐の番号（昇順。02-05「本体の後の検査」の選び方）
    Unreachable {
        arm: usize,
        alt: usize,
        covered_by: Vec<usize>,
    },
}

use crate::types::{AdtTable, Ty};

/// 仕事量の予算を超えて判定をやめたこと（設計書 02-05「本体の後の検査」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Undecided;

/// 選ばれない選択肢の位置と、それを覆う選択肢の位置。
pub type CoveringAlternatives = ((usize, usize), Vec<(usize, usize)>);

/// 一つの `match` の判定の結果。途中で予算を超えた場合、部分的な結果は返さない。
#[derive(Clone, PartialEq, Debug)]
pub struct MatchCheck {
    /// 選ばれない選択肢を分岐と選択肢の順に、その後に網羅していないこと（あれば一つ）。
    pub issues: Vec<MatchIssue>,
    /// 選ばれない選択肢 `(arm, alt)` ごとの、覆っている選択肢の位置。
    pub covering: Vec<CoveringAlternatives>,
    /// 判定に使った仕事量。
    pub work: usize,
}

/// 束縛の文の判定の結果。
#[derive(Clone, PartialEq, Debug)]
pub struct BindingCheck {
    /// 必ず照合するなら `None`、そうでなければ照合しない値の形。
    pub witness: Option<String>,
    /// 反例に含まれる将来の形の宣言。表示文字列から推測しない。
    pub future_types: BTreeSet<BindingId>,
    /// 判定に使った仕事量。
    pub work: usize,
}

// 各列の表示と型の出どころを一緒に記憶し、入れ子の反例を組み立てる。
#[derive(Clone, PartialEq, Debug)]
struct Witness {
    text: String,
    future_types: BTreeSet<BindingId>,
}
impl From<String> for Witness {
    fn from(text: String) -> Self {
        Self {
            text,
            future_types: BTreeSet::new(),
        }
    }
}
impl From<&str> for Witness {
    fn from(text: &str) -> Self {
        text.to_owned().into()
    }
}

#[derive(PartialEq, Eq, Hash)]
struct SearchKey {
    types: Vec<Ty>,
    matrix: Vec<Vec<Pat>>,
    query: Vec<Pat>,
}

// 表と予算は一つの match または束縛の文の間だけ共有する。表を引く順序は探索の順序に影響しない。
struct Search<'a> {
    view: &'a CoverageView,
    limit: usize,
    used: usize,
    memo: Option<HashMap<SearchKey, Option<Vec<Witness>>>>,
}
impl<'a> Search<'a> {
    fn new(limit: usize, view: &'a CoverageView) -> Self {
        Self {
            view,
            limit,
            used: 0,
            memo: Some(HashMap::new()),
        }
    }
    fn charge(&mut self, work: usize) -> Result<(), Undecided> {
        self.used = self.used.saturating_add(work);
        if self.used > self.limit {
            Err(Undecided)
        } else {
            Ok(())
        }
    }
    fn matrix(&mut self, rows: &[Vec<Pat>]) -> Result<(), Undecided> {
        self.charge(
            rows.iter()
                .fold(0usize, |n, row| n.saturating_add(row.len())),
        )
    }
    fn finish(
        &mut self,
        key: Option<Box<SearchKey>>,
        result: Option<Vec<Witness>>,
    ) -> Option<Vec<Witness>> {
        if let (Some(memo), Some(key)) = (&mut self.memo, key) {
            memo.insert(*key, result.clone());
        }
        result
    }
}

/// 一つの `match` を検査する。構成子の名前は型名で修飾し、同名の構成子とレコードは修飾しない。
pub fn check_match(
    scrutinee: &Ty,
    arms: &[ArmPats],
    adts: &AdtTable,
    view: &CoverageView,
) -> Result<MatchCheck, Undecided> {
    check_match_with(
        scrutinee,
        arms,
        adts,
        &mut Search::new(MAX_COVERAGE_WORK, view),
    )
}
fn check_match_with(
    scrutinee: &Ty,
    arms: &[ArmPats],
    adts: &AdtTable,
    search: &mut Search,
) -> Result<MatchCheck, Undecided> {
    let mut issues = Vec::new();
    let mut covering = Vec::new();
    let mut rows = Vec::new();
    for (arm, a) in arms.iter().enumerate() {
        let previous_len = rows.len();
        for (alt, pat) in a.alts.iter().enumerate() {
            if useful(scrutinee, &rows, pat, adts, search)?.is_none() {
                let positions = covering_alternatives(scrutinee, arms, arm, alt, adts, search)?;
                let mut covered_by = positions
                    .iter()
                    .map(|(i, _)| *i)
                    .filter(|i| *i != arm)
                    .collect::<Vec<_>>();
                covered_by.sort_unstable();
                covered_by.dedup();
                covering.push(((arm, alt), positions));
                issues.push(MatchIssue::Unreachable {
                    arm,
                    alt,
                    covered_by,
                });
            }
            // 同じ分岐の前の選択肢はガードによらず後の選択肢を覆う（01-05「選ばれない分岐の検査」）。
            rows.push(pat.clone());
        }
        if a.guarded {
            rows.truncate(previous_len);
        }
    }
    if let Some(witness) = useful(scrutinee, &rows, &Pat::Wild, adts, search)? {
        issues.push(MatchIssue::NonExhaustive {
            witness: witness.text,
            future_types: witness.future_types,
        });
    }
    Ok(MatchCheck {
        issues,
        covering,
        work: search.used,
    })
}

/// 束縛の文の反例まで、一つの予算で一度だけ求める。
pub fn check_binding(
    ty: &Ty,
    pat: &Pat,
    adts: &AdtTable,
    view: &CoverageView,
) -> Result<BindingCheck, Undecided> {
    let mut search = Search::new(MAX_COVERAGE_WORK, view);
    let witness = useful(ty, std::slice::from_ref(pat), &Pat::Wild, adts, &mut search)?;
    let future_types = witness
        .as_ref()
        .map(|w| w.future_types.clone())
        .unwrap_or_default();
    Ok(BindingCheck {
        witness: witness.map(|w| w.text),
        future_types,
        work: search.used,
    })
}

use crate::types::{TyCon, builtin::BuiltinTypeId as B};

// 区間と長さも構成子と同じ特殊化で扱う。各列で行列と候補の両方から境界を求める
// （設計書 02-05「本体の後の検査」）。
#[derive(Clone)]
enum Shape {
    Ctor {
        adt: BindingId,
        tag: u32,
        fields: Vec<Ty>,
    },
    Boolean(bool),
    Unit,
    Interval(i128, i128),
    String(String),
    Exact(usize, Ty),
    Long {
        min: usize,
        front: usize,
        back: usize,
        elem: Ty,
    },
    Future(BindingId),
    Other,
}
impl Shape {
    fn fields(&self) -> Vec<Ty> {
        match self {
            Self::Ctor { fields, .. } => fields.clone(),
            Self::Exact(n, t) => vec![t.clone(); *n],
            Self::Long {
                front, back, elem, ..
            } => vec![elem.clone(); front.saturating_add(*back)],
            Self::Boolean(_)
            | Self::Unit
            | Self::Interval(..)
            | Self::String(_)
            | Self::Future(_)
            | Self::Other => {
                vec![]
            }
        }
    }
    fn show(&self, args: &[String], adts: &AdtTable) -> String {
        match self {
            Self::Ctor { adt, tag, .. } => {
                let Some(def) = adts.get(*adt) else {
                    return "_".into();
                };
                let Some(ctor) = def.ctors.iter().find(|c| c.tag == *tag) else {
                    return "_".into();
                };
                let name = if def.record.is_some() || def.name == ctor.name {
                    ctor.name.clone()
                } else {
                    format!("{}.{}", def.name, ctor.name)
                };
                if let Some(fields) = &def.record {
                    let values = fields
                        .iter()
                        .zip(args)
                        .map(|(f, p)| format!("{}: {p}", f.name))
                        .collect::<Vec<_>>();
                    format!("{name}({})", values.join(", "))
                } else if args.is_empty() {
                    name
                } else {
                    format!("{name}({})", args.join(", "))
                }
            }
            Self::Future(id) => {
                let Some(def) = adts.get(*id) else {
                    return "_".into();
                };
                super::text::future_shape(&def.name, def.record.is_some())
            }
            Self::Boolean(v) => v.to_string(),
            Self::Unit => "()".into(),
            Self::Exact(_, _) => format!("[{}]", args.join(", ")),
            Self::Long {
                min, front, back, ..
            } => {
                if *min == 0 {
                    return "[..]".into();
                }
                let mut parts = args.iter().take(*front).cloned().collect::<Vec<_>>();
                parts.resize((*front).max(min.saturating_sub(*back)), "_".into());
                parts.push("..".into());
                parts.extend(args.iter().skip(*front).cloned());
                format!("[{}]", parts.join(", "))
            }
            Self::Interval(_, _) | Self::String(_) | Self::Other => "_".into(),
        }
    }
}
fn interval(p: &Pat) -> Option<(i128, i128)> {
    match p {
        Pat::Integer(v) => Some((i128::from(*v), i128::from(*v))),
        Pat::IntegerRange(a, b) => Some((i128::from(*a), i128::from(*b))),
        Pat::Character(v) => Some((i128::from(u32::from(*v)), i128::from(u32::from(*v)))),
        Pat::CharacterRange(a, b) => Some((i128::from(u32::from(*a)), i128::from(u32::from(*b)))),
        Pat::Wild
        | Pat::Ctor { .. }
        | Pat::String(_)
        | Pat::Boolean(_)
        | Pat::Unit
        | Pat::List { .. } => None,
    }
}
fn shapes(ty: &Ty, column: &[&Pat], adts: &AdtTable, view: &CoverageView) -> Option<Vec<Shape>> {
    Some(match ty {
        Ty::Con(TyCon::Adt(id), args) => {
            let Some(d) = adts.get(*id) else {
                return Some(vec![Shape::Other]);
            };
            let mut result = Vec::new();
            for c in &d.ctors {
                result.push(Shape::Ctor {
                    adt: *id,
                    tag: c.tag,
                    fields: adts.field_types(*id, c.tag, args)?,
                });
            }
            if view.contains(id) {
                result.push(Shape::Future(*id));
            }
            result
        }
        Ty::Con(TyCon::Builtin(b), _) if *b == B::BOOLEAN => {
            vec![Shape::Boolean(true), Shape::Boolean(false)]
        }
        Ty::Con(TyCon::Builtin(b), _) if *b == B::UNIT => vec![Shape::Unit],
        Ty::Con(TyCon::Builtin(b), _) if *b == B::INTEGER || *b == B::CHARACTER => {
            let intervals = column
                .iter()
                .filter_map(|p| interval(p))
                .collect::<Vec<_>>();
            let mut bounds = intervals
                .iter()
                .flat_map(|(a, b)| [*a, b.saturating_add(1)])
                .collect::<Vec<_>>();
            bounds.sort_unstable();
            bounds.dedup();
            // 実際の値域をすべて覆っても、規則上は残りの値を一つ設ける（設計書 01-05「網羅性の検査」）。
            let mut result = vec![Shape::Other];
            for ends in bounds.windows(2) {
                if let [a, hi_boundary] = ends {
                    let hi = hi_boundary.saturating_sub(1);
                    if intervals.iter().any(|(lo, high)| lo <= a && hi <= *high)
                        && !(*b == B::CHARACTER && *a >= 0xd800 && hi <= 0xdfff)
                    {
                        result.push(Shape::Interval(*a, hi));
                    }
                }
            }
            result
        }
        Ty::Con(TyCon::Builtin(b), _) if *b == B::STRING => {
            let mut result = vec![Shape::Other];
            for p in column {
                if let Pat::String(s) = p
                    && !result
                        .iter()
                        .any(|c| matches!(c, Shape::String(t) if s == t))
                {
                    result.push(Shape::String(s.clone()));
                }
            }
            result
        }
        Ty::Con(TyCon::Builtin(b), args) if *b == B::LIST => {
            let elem = args.first().cloned().unwrap_or(Ty::Param(0));
            let (mut exact_end, mut front, mut back) = (0, 0, 0);
            for p in column {
                if let Pat::List {
                    before,
                    rest,
                    after,
                } = p
                {
                    if *rest {
                        front = front.max(before.len());
                        back = back.max(after.len());
                    } else {
                        exact_end = exact_end
                            .max(before.len().saturating_add(after.len()).saturating_add(1));
                    }
                }
            }
            let min = exact_end.max(front.saturating_add(back));
            let mut result = (0..min)
                .map(|k| Shape::Exact(k, elem.clone()))
                .collect::<Vec<_>>();
            result.push(Shape::Long {
                min,
                front,
                back,
                elem,
            });
            result
        }
        Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
            vec![Shape::Other]
        }
    })
}
fn specialize(p: &Pat, shape: &Shape) -> Option<Vec<Pat>> {
    if matches!(p, Pat::Wild) {
        return Some(vec![Pat::Wild; shape.fields().len()]);
    }
    match (p, shape) {
        (Pat::Ctor { adt, tag, args }, Shape::Ctor { adt: a, tag: t, .. })
            if adt == a && tag == t =>
        {
            Some(args.clone())
        }
        (Pat::Boolean(a), Shape::Boolean(b)) if a == b => Some(vec![]),
        (Pat::Unit, Shape::Unit) => Some(vec![]),
        (p, Shape::Interval(lo, hi)) if interval(p).is_some_and(|(a, b)| a <= *lo && *hi <= b) => {
            Some(vec![])
        }
        (Pat::String(a), Shape::String(b)) if a == b => Some(vec![]),
        (
            Pat::List {
                before,
                rest,
                after,
            },
            Shape::Exact(n, _),
        ) => {
            let count = before.len().saturating_add(after.len());
            if (*rest && count <= *n) || (!*rest && count == *n) {
                let mut args = before.clone();
                args.resize(n.saturating_sub(after.len()), Pat::Wild);
                args.extend(after.clone());
                Some(args)
            } else {
                None
            }
        }
        (
            Pat::List {
                before,
                rest: true,
                after,
            },
            Shape::Long {
                min, front, back, ..
            },
        ) if before.len().saturating_add(after.len()) <= *min => {
            let mut args = before.clone();
            args.resize(
                front.saturating_add(*back).saturating_sub(after.len()),
                Pat::Wild,
            );
            args.extend(after.clone());
            Some(args)
        }
        _ => None,
    }
}
fn useful(
    ty: &Ty,
    rows: &[Pat],
    pat: &Pat,
    adts: &AdtTable,
    search: &mut Search,
) -> Result<Option<Witness>, Undecided> {
    search.charge(rows.len())?;
    let input = SearchInput {
        types: vec![ty.clone()],
        matrix: rows.iter().map(|p| vec![p.clone()]).collect(),
        query: vec![pat.clone()],
    };
    Ok(usefulness(input, adts, search)?.and_then(|v| v.into_iter().next()))
}

struct SearchInput {
    types: Vec<Ty>,
    matrix: Vec<Vec<Pat>>,
    query: Vec<Pat>,
}
impl SearchInput {
    fn fallback(&self, adts: &AdtTable) -> Option<Vec<Witness>> {
        Some(
            self.query
                .iter()
                .map(|p| show_pattern(p, adts).into())
                .collect(),
        )
    }
}
struct Branches {
    key: Option<Box<SearchKey>>,
    input: SearchInput,
    shapes: std::vec::IntoIter<Shape>,
    specialized: bool,
}
enum Continue {
    Wild(usize),
    Branch {
        branches: Box<Branches>,
        shape: Shape,
        arity: usize,
    },
}
enum Step {
    Done(Option<Vec<Witness>>),
    Descend(SearchInput, Continue),
}

fn usefulness(
    input: SearchInput,
    adts: &AdtTable,
    search: &mut Search,
) -> Result<Option<Vec<Witness>>, Undecided> {
    // 再帰の戻り先を明示したスタックに置く。深い構成子やリストでも、鍵の複製と
    // ハッシュの再帰を探索の再帰と重ねない（07-03「テストの設計の原則」の深い入力）。
    let mut pending = Vec::new();
    let mut step = enter(input, adts, search)?;
    loop {
        match step {
            Step::Descend(input, continuation) => {
                pending.push(continuation);
                step = enter(input, adts, search)?;
            }
            Step::Done(result) => {
                let Some(continuation) = pending.pop() else {
                    return Ok(result);
                };
                step = match continuation {
                    Continue::Wild(count) => {
                        let result = result.map(|result| {
                            let mut witness = vec!["_".into(); count];
                            witness.extend(result);
                            witness
                        });
                        Step::Done(result)
                    }
                    Continue::Branch {
                        branches,
                        shape,
                        arity,
                    } => {
                        if let Some(result) = result {
                            let tail_len = branches.input.query.len().saturating_sub(1);
                            let witness = if result.len() == arity.saturating_add(tail_len) {
                                if let Some((fields, rest)) = result.split_at_checked(arity) {
                                    let text = shape.show(
                                        &fields.iter().map(|w| w.text.clone()).collect::<Vec<_>>(),
                                        adts,
                                    );
                                    let mut future_types = fields
                                        .iter()
                                        .flat_map(|w| w.future_types.iter().copied())
                                        .collect::<BTreeSet<_>>();
                                    if let Shape::Future(id) = shape {
                                        future_types.insert(id);
                                    }
                                    let mut witness = vec![Witness { text, future_types }];
                                    witness.extend_from_slice(rest);
                                    Some(witness)
                                } else {
                                    branches.input.fallback(adts)
                                }
                            } else {
                                branches.input.fallback(adts)
                            };
                            Step::Done(search.finish(branches.key, witness))
                        } else {
                            next_branch(*branches, adts, search)?
                        }
                    }
                };
            }
        }
    }
}
fn enter(mut input: SearchInput, adts: &AdtTable, search: &mut Search) -> Result<Step, Undecided> {
    search.charge(1)?;
    // Lean の usefulFuel と同じく、長さの違う行を被覆と記憶の判定より先に除く。
    input.matrix.retain(|row| row.len() == input.query.len());
    // 不整合は有用の側に倒し、問いの形を返す（02-05「本体の後の検査」）。
    if input.types.len() != input.query.len() {
        return Ok(Step::Done(input.fallback(adts)));
    }
    if input
        .matrix
        .iter()
        .any(|row| row.iter().all(|p| matches!(p, Pat::Wild)))
    {
        return Ok(Step::Done(None));
    }
    let (Some(q), Some(ty)) = (input.query.first(), input.types.first()) else {
        return Ok(Step::Done(input.fallback(adts)));
    };
    if input.matrix.is_empty() {
        return Ok(Step::Done(input.fallback(adts)));
    }
    // ワイルドカードだけの先頭の列は、連続する分を一度に落とす。
    // 行列の残りを複製するのは一回だけであり、作るセルをすべて先に数える。
    let wild_columns = input
        .query
        .iter()
        .enumerate()
        .take_while(|(i, p)| {
            matches!(p, Pat::Wild)
                && input
                    .matrix
                    .iter()
                    .all(|row| matches!(row.get(*i), Some(Pat::Wild)))
        })
        .count();
    if wild_columns > 0 {
        search.charge(input.matrix.iter().fold(0usize, |n, row| {
            n.saturating_add(row.len().saturating_sub(wild_columns))
        }))?;
        let matrix = input
            .matrix
            .iter()
            .map(|row| row.iter().skip(wild_columns).cloned().collect())
            .collect::<Vec<_>>();
        return Ok(Step::Descend(
            SearchInput {
                types: input.types.into_iter().skip(wild_columns).collect(),
                query: input.query.into_iter().skip(wild_columns).collect(),
                matrix,
            },
            Continue::Wild(wild_columns),
        ));
    }
    let column = input
        .matrix
        .iter()
        .filter_map(|row| row.first())
        .chain(std::iter::once(q))
        .collect::<Vec<_>>();
    let Some(shapes) = shapes(ty, &column, adts, search.view) else {
        return Ok(Step::Done(input.fallback(adts)));
    };
    // 記憶は構成子で分ける段の入力だけに持つ。検索のための複製も、表で再利用
    // できた場合を含めて数える（型の並びと問いのセルも含む）。
    let key = if search.memo.is_some() {
        search.matrix(&input.matrix)?;
        search.charge(input.types.len().saturating_add(input.query.len()))?;
        Some(Box::new(SearchKey {
            types: input.types.clone(),
            matrix: input.matrix.clone(),
            query: input.query.clone(),
        }))
    } else {
        None
    };
    if let Some(result) = key
        .as_ref()
        .and_then(|key| search.memo.as_ref()?.get(key.as_ref()))
    {
        return Ok(Step::Done(result.clone()));
    }
    next_branch(
        Branches {
            key,
            input,
            shapes: shapes.into_iter(),
            specialized: false,
        },
        adts,
        search,
    )
}
fn next_branch(
    mut branches: Branches,
    adts: &AdtTable,
    search: &mut Search,
) -> Result<Step, Undecided> {
    for shape in branches.shapes.by_ref() {
        let Some(q) = branches.input.query.first() else {
            break;
        };
        let Some(mut query) = specialize(q, &shape) else {
            continue;
        };
        branches.specialized = true;
        query.extend(branches.input.query.iter().skip(1).cloned());
        let mut matrix = Vec::new();
        for row in &branches.input.matrix {
            let Some(first) = row.first() else {
                continue;
            };
            let Some(mut specialized) = specialize(first, &shape) else {
                continue;
            };
            // 行全体を複製する前に数える。予算に当たる行があれば、その先の行を作らない。
            search.charge(
                specialized
                    .len()
                    .saturating_add(row.len().saturating_sub(1)),
            )?;
            specialized.extend(row.iter().skip(1).cloned());
            matrix.push(specialized);
        }
        let mut types = shape.fields();
        let arity = types.len();
        types.extend(branches.input.types.iter().skip(1).cloned());
        return Ok(Step::Descend(
            SearchInput {
                types,
                matrix,
                query,
            },
            Continue::Branch {
                branches: Box::new(branches),
                shape,
                arity,
            },
        ));
    }
    let result =
        if !branches.specialized && !matches!(branches.input.query.first(), Some(Pat::Wild)) {
            branches.input.fallback(adts)
        } else {
            None
        };
    Ok(Step::Done(search.finish(branches.key, result)))
}
fn show_pattern(p: &Pat, adts: &AdtTable) -> String {
    match p {
        Pat::Ctor { adt, tag, args } => Shape::Ctor {
            adt: *adt,
            tag: *tag,
            fields: vec![],
        }
        .show(
            &args
                .iter()
                .map(|p| show_pattern(p, adts))
                .collect::<Vec<_>>(),
            adts,
        ),
        Pat::Boolean(v) => v.to_string(),
        Pat::Unit => "()".into(),
        Pat::List {
            before,
            rest,
            after,
        } => {
            let mut parts = before
                .iter()
                .map(|p| show_pattern(p, adts))
                .collect::<Vec<_>>();
            if *rest {
                parts.push("..".into());
            }
            parts.extend(after.iter().map(|p| show_pattern(p, adts)));
            format!("[{}]", parts.join(", "))
        }
        Pat::Wild
        | Pat::Integer(_)
        | Pat::Character(_)
        | Pat::String(_)
        | Pat::IntegerRange(..)
        | Pat::CharacterRange(..) => "_".into(),
    }
}
fn overlaps(
    ty: &Ty,
    a: &Pat,
    b: &Pat,
    adts: &AdtTable,
    search: &mut Search,
) -> Result<bool, Undecided> {
    search.charge(1)?;
    if matches!(a, Pat::Wild) || matches!(b, Pat::Wild) {
        return Ok(true);
    }
    if let Some(shapes) = shapes(ty, &[a, b], adts, search.view) {
        for shape in shapes {
            let (Some(xs), Some(ys)) = (specialize(a, &shape), specialize(b, &shape)) else {
                continue;
            };
            if xs.len() != ys.len() {
                continue;
            }
            let mut all = true;
            for (t, (x, y)) in shape.fields().iter().zip(xs.iter().zip(&ys)) {
                if !overlaps(t, x, y, adts, search)? {
                    all = false;
                    break;
                }
            }
            if all {
                return Ok(true);
            }
        }
    }
    Ok(false)
}
/// 補助の位置は分岐の番号だけでは足りないので、選択肢の単位で求める。
fn covering_alternatives(
    ty: &Ty,
    arms: &[ArmPats],
    arm: usize,
    alt: usize,
    adts: &AdtTable,
    search: &mut Search,
) -> Result<Vec<(usize, usize)>, Undecided> {
    let Some(target) = arms.get(arm).and_then(|a| a.alts.get(alt)) else {
        return Ok(vec![]);
    };
    let previous = arms
        .iter()
        .enumerate()
        .take(arm.saturating_add(1))
        .filter(|(i, a)| *i == arm || !a.guarded)
        .flat_map(|(i, a)| {
            a.alts
                .iter()
                .enumerate()
                .take(if i == arm { alt } else { a.alts.len() })
                .map(move |(j, p)| ((i, j), p))
        })
        .collect::<Vec<_>>();
    for (position, p) in &previous {
        if useful(ty, std::slice::from_ref(*p), target, adts, search)?.is_none() {
            return Ok(vec![*position]);
        }
    }
    let mut rows = vec![];
    for (k, (_, p)) in previous.iter().enumerate() {
        rows.push((*p).clone());
        if useful(ty, &rows, target, adts, search)?.is_none() {
            let mut positions = vec![];
            for (position, p) in previous.iter().take(k.saturating_add(1)) {
                if overlaps(ty, p, target, adts, search)? {
                    positions.push(*position);
                }
            }
            return Ok(positions);
        }
    }
    Ok(vec![])
}

#[cfg(test)]
mod tests {
    // 公開の判定 API の契約を表で確かめる。型検査の例だけでは、合成による被覆の
    // 最小の接頭辞と、長さごとの前後の要素の対応の誤りを区別できない。
    // 期待値を独立に書き、本番の差し込み口を増やさない（設計書 07-03「テストの設計の原則」）。
    #![allow(
        clippy::unwrap_used,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::base::ModuleId;
    use crate::types::{AdtDef, CtorDef, TypeSummary};

    #[test]
    fn coverage_views_follow_package_identity_and_type_flags() {
        use crate::modules::{ModuleInfo, ModuleKind, ModulePath};

        // 型表の指定から作者/外部を区別する判定 API の契約を確かめる。
        // 表示名は全型で同じにして、名前から所属や record を推測する退行を防ぐ。
        let modules = ModuleTable {
            modules: [
                (ModuleKind::Entry, "Main"),
                (ModuleKind::User, "Words.Use"),
                (ModuleKind::Prelude, "Benitoite.Integer"),
                (ModuleKind::Stdlib, "Benitoite.Json"),
                (ModuleKind::Package, "Words.Kinds"),
                (ModuleKind::Package, "Words.Use"),
                (ModuleKind::Package, "Other.Kinds"),
                (ModuleKind::Config, "Main"),
                (ModuleKind::PackageConfig, "Words"),
            ]
            .into_iter()
            .enumerate()
            .map(|(i, (kind, name))| ModuleInfo {
                id: ModuleId(u32::try_from(i).unwrap()),
                name: ModulePath(name.split('.').map(str::to_owned).collect()),
                kind,
                imports: vec![],
                internal_dependencies: vec![],
            })
            .collect(),
        };
        let mut adts = AdtTable::default();
        for i in 0..8 {
            let binding = BindingId(i);
            adts.adts.insert(
                binding,
                AdtDef {
                    binding,
                    name: "Kind".into(),
                    module: ModuleId(if i == 7 { 0 } else { i }),
                    extensible: false,
                    type_params: vec![],
                    ctors: vec![],
                    record: (i == 3).then(Vec::new),
                    eq_summary: TypeSummary::default(),
                    key_summary: TypeSummary::default(),
                },
            );
        }
        assert!(coverage_view(&modules, &adts, ModuleId(0)).is_empty());
        for i in 0..7 {
            let mut adt = adts.adts.get(BindingId(i)).unwrap().clone();
            adt.extensible = true;
            adts.adts.insert(BindingId(i), adt);
        }
        for (module, expected) in [
            (0, vec![2, 3, 4, 5, 6]),
            (1, vec![2, 3, 4, 5, 6]),
            (2, vec![0, 1, 4, 5, 6]),
            (3, vec![0, 1, 4, 5, 6]),
            (4, vec![0, 1, 2, 3, 6]),
            (5, vec![0, 1, 2, 3, 6]),
            (6, vec![0, 1, 2, 3, 4, 5]),
            (7, vec![0, 1, 2, 3, 4, 5, 6]),
            (8, vec![0, 1, 2, 3, 4, 5, 6]),
            (u32::MAX, vec![0, 1, 2, 3, 4, 5, 6]),
        ] {
            assert_eq!(
                coverage_view(&modules, &adts, ModuleId(module)),
                expected.into_iter().map(BindingId).collect(),
                "module {module}"
            );
        }
    }

    fn builtin(b: B) -> Ty {
        Ty::Con(TyCon::Builtin(b), vec![])
    }
    fn arm(p: Pat) -> ArmPats {
        ArmPats {
            alts: vec![p],
            guarded: false,
        }
    }
    fn list(before: Vec<Pat>, rest: bool, after: Vec<Pat>) -> Pat {
        Pat::List {
            before,
            rest,
            after,
        }
    }
    fn missing(witness: &str) -> MatchIssue {
        MatchIssue::NonExhaustive {
            future_types: BTreeSet::new(),
            witness: witness.into(),
        }
    }
    fn unreachable(arm: usize, alt: usize, covered_by: &[usize]) -> MatchIssue {
        MatchIssue::Unreachable {
            arm,
            alt,
            covered_by: covered_by.into(),
        }
    }
    #[test]
    fn finite_and_open_types_have_the_specified_coverage() {
        let table = AdtTable::default();
        for (ty, arms, expected) in [
            (
                builtin(B::BOOLEAN),
                vec![arm(Pat::Boolean(true)), arm(Pat::Boolean(false))],
                vec![],
            ),
            (
                builtin(B::BOOLEAN),
                vec![arm(Pat::Boolean(true))],
                vec![missing("false")],
            ),
            (
                builtin(B::UNIT),
                vec![arm(Pat::Unit), arm(Pat::Wild)],
                vec![unreachable(1, 0, &[0])],
            ),
            (
                builtin(B::INTEGER),
                vec![arm(Pat::IntegerRange(i64::MIN, i64::MAX))],
                vec![missing("_")],
            ),
            (
                builtin(B::CHARACTER),
                vec![arm(Pat::CharacterRange('\0', '\u{10ffff}'))],
                vec![missing("_")],
            ),
            (
                builtin(B::STRING),
                vec![arm(Pat::String("a".into())), arm(Pat::String("a".into()))],
                vec![unreachable(1, 0, &[0]), missing("_")],
            ),
            (builtin(B::FLOAT), vec![arm(Pat::Wild)], vec![]),
            (Ty::Param(0), vec![arm(Pat::Wild)], vec![]),
        ] {
            assert_eq!(checked_issues(&ty, &arms, &table), expected);
        }
        assert!(
            check_binding(&builtin(B::UNIT), &Pat::Unit, &table, &CoverageView::new())
                .unwrap()
                .witness
                .is_none()
        );
        assert!(
            check_binding(
                &builtin(B::BOOLEAN),
                &Pat::Boolean(true),
                &table,
                &CoverageView::new()
            )
            .unwrap()
            .witness
            .is_some()
        );
    }
    #[test]
    fn intervals_choose_single_cover_before_minimal_joint_cover() {
        let table = AdtTable::default();
        let ty = builtin(B::INTEGER);
        for (pats, expected) in [
            (
                vec![
                    Pat::IntegerRange(1, 5),
                    Pat::IntegerRange(6, 10),
                    Pat::IntegerRange(1, 10),
                    Pat::Wild,
                ],
                vec![unreachable(2, 0, &[0, 1])],
            ),
            (
                vec![
                    Pat::Integer(99),
                    Pat::IntegerRange(1, 5),
                    Pat::IntegerRange(6, 10),
                    Pat::IntegerRange(1, 10),
                    Pat::Wild,
                ],
                vec![unreachable(3, 0, &[1, 2])],
            ),
            (
                vec![
                    Pat::IntegerRange(1, 5),
                    Pat::IntegerRange(6, 10),
                    Pat::IntegerRange(1, 20),
                    Pat::IntegerRange(1, 10),
                    Pat::Wild,
                ],
                vec![unreachable(3, 0, &[2])],
            ),
            (
                vec![
                    Pat::IntegerRange(i64::MIN, 0),
                    Pat::IntegerRange(1, i64::MAX),
                    Pat::IntegerRange(i64::MIN, i64::MAX),
                    Pat::Wild,
                ],
                vec![unreachable(2, 0, &[0, 1])],
            ),
            (
                vec![Pat::IntegerRange(1, 5), Pat::IntegerRange(5, 10), Pat::Wild],
                vec![],
            ),
        ] {
            assert_eq!(
                checked_issues(&ty, &pats.into_iter().map(arm).collect::<Vec<_>>(), &table),
                expected
            );
        }
        let arms = vec![
            ArmPats {
                alts: vec![Pat::Integer(1), Pat::Integer(1)],
                guarded: false,
            },
            arm(Pat::Wild),
        ];
        assert_eq!(
            checked_issues(&ty, &arms, &table),
            vec![unreachable(0, 1, &[])]
        );
        let ty = builtin(B::CHARACTER);
        assert_eq!(
            checked_issues(
                &ty,
                &[
                    arm(Pat::CharacterRange('a', 'm')),
                    arm(Pat::CharacterRange('n', 'z')),
                    arm(Pat::CharacterRange('a', 'z')),
                    arm(Pat::Wild)
                ],
                &table
            ),
            vec![unreachable(2, 0, &[0, 1])]
        );
        assert_eq!(
            checked_issues(
                &ty,
                &[
                    arm(Pat::CharacterRange('\0', '\u{d7ff}')),
                    arm(Pat::CharacterRange('\u{e000}', '\u{10ffff}')),
                    arm(Pat::CharacterRange('\0', '\u{10ffff}')),
                    arm(Pat::Wild)
                ],
                &table
            ),
            vec![unreachable(2, 0, &[0, 1])]
        );
    }
    #[test]
    fn guards_never_cover_later_rows() {
        let ty = builtin(B::INTEGER);
        let adts = AdtTable::default();
        let guarded = ArmPats {
            alts: vec![Pat::Wild],
            guarded: true,
        };
        assert_eq!(
            checked_issues(&ty, std::slice::from_ref(&guarded), &adts),
            vec![missing("_")]
        );
        assert_eq!(
            checked_issues(&ty, &[guarded.clone(), arm(Pat::Wild)], &adts),
            vec![]
        );
        assert_eq!(
            checked_issues(&ty, &[arm(Pat::Wild), guarded], &adts),
            vec![unreachable(1, 0, &[0])]
        );
    }
    // spec: 01-05 選ばれない分岐の検査
    #[test]
    fn guarded_alternatives_cover_only_later_alternatives_in_the_same_arm() {
        let ty = builtin(B::INTEGER);
        let table = AdtTable::default();
        for (arms, expected) in [
            (
                vec![
                    ArmPats {
                        alts: vec![Pat::Integer(1), Pat::Integer(1)],
                        guarded: true,
                    },
                    arm(Pat::Integer(1)),
                    arm(Pat::Wild),
                ],
                vec![unreachable(0, 1, &[])],
            ),
            (
                vec![
                    arm(Pat::IntegerRange(0, 1)),
                    arm(Pat::IntegerRange(2, 3)),
                    ArmPats {
                        alts: vec![Pat::IntegerRange(0, 3), Pat::IntegerRange(0, 3)],
                        guarded: true,
                    },
                    arm(Pat::Wild),
                ],
                vec![unreachable(2, 0, &[0, 1]), unreachable(2, 1, &[])],
            ),
        ] {
            assert_eq!(checked_issues(&ty, &arms, &table), expected);
        }
    }
    // spec: 02-05 本体の後の検査
    #[test]
    fn inconsistent_constructor_matrices_remain_useful() {
        let (ty, table) = option();
        let malformed = |args| Pat::Ctor {
            adt: BindingId(0),
            tag: 1,
            args,
        };
        // 引数の足りない問いと多すぎる問い、長さの違うワイルドカードの行を含む行列。
        for arms in [
            vec![arm(some(Pat::Wild)), arm(malformed(vec![])), arm(Pat::Wild)],
            vec![
                arm(some(Pat::Wild)),
                arm(malformed(vec![Pat::Wild, Pat::Wild])),
                arm(Pat::Wild),
            ],
            vec![
                arm(malformed(vec![])),
                arm(some(Pat::Boolean(true))),
                arm(Pat::Wild),
            ],
            vec![
                arm(malformed(vec![Pat::Wild, Pat::Wild])),
                arm(some(Pat::Boolean(true))),
                arm(Pat::Wild),
            ],
        ] {
            assert_eq!(checked_issues(&ty, &arms, &table), vec![]);
        }
        // 型引数が足りず構成子の欄の型を取得できない場合も、問いの形を保つ。
        let missing_args = Ty::Con(TyCon::Adt(BindingId(0)), vec![]);
        assert_eq!(
            checked_issues(
                &missing_args,
                &[arm(some(Pat::Wild)), arm(some(Pat::Boolean(true)))],
                &table
            ),
            vec![missing("_")]
        );
        // ワイルドカードでない問いが、型のどの構成子にも特殊化できない。
        assert_eq!(
            checked_issues(
                &builtin(B::INTEGER),
                &[
                    arm(Pat::Integer(0)),
                    arm(Pat::Boolean(true)),
                    arm(Pat::Wild)
                ],
                &table
            ),
            vec![]
        );
    }
    #[test]
    fn lists_distinguish_exact_lengths_and_front_back_alignment() {
        let table = AdtTable::default();
        let ty = Ty::Con(TyCon::Builtin(B::LIST), vec![builtin(B::BOOLEAN)]);
        let empty = list(vec![], false, vec![]);
        let any_nonempty = list(vec![Pat::Wild], true, vec![]);
        let exact_one = list(vec![Pat::Wild], false, vec![]);
        for (pats, expected) in [
            (vec![empty.clone(), any_nonempty.clone()], vec![]),
            (
                vec![empty.clone(), exact_one.clone()],
                vec![missing("[_, _, ..]")],
            ),
            (
                vec![
                    empty.clone(),
                    list(vec![Pat::Boolean(true)], true, vec![]),
                    list(vec![Pat::Boolean(false)], true, vec![]),
                ],
                vec![],
            ),
            (
                vec![
                    empty.clone(),
                    list(vec![], true, vec![Pat::Boolean(true)]),
                    list(vec![], true, vec![Pat::Boolean(false)]),
                ],
                vec![],
            ),
            (
                vec![
                    list(vec![Pat::Boolean(true)], true, vec![Pat::Boolean(false)]),
                    list(vec![Pat::Boolean(true), Pat::Boolean(false)], false, vec![]),
                    Pat::Wild,
                ],
                vec![unreachable(1, 0, &[0])],
            ),
            (
                vec![
                    list(vec![Pat::Boolean(true)], true, vec![Pat::Boolean(false)]),
                    list(vec![Pat::Boolean(true)], false, vec![]),
                    Pat::Wild,
                ],
                vec![],
            ),
            (
                vec![
                    list(vec![Pat::Wild], true, vec![Pat::Wild]),
                    list(vec![Pat::Wild, Pat::Wild, Pat::Wild], true, vec![]),
                    Pat::Wild,
                ],
                vec![unreachable(1, 0, &[0])],
            ),
        ] {
            assert_eq!(
                checked_issues(&ty, &pats.into_iter().map(arm).collect::<Vec<_>>(), &table),
                expected
            );
        }
        assert!(
            check_binding(
                &ty,
                &list(vec![], true, vec![]),
                &table,
                &CoverageView::new()
            )
            .unwrap()
            .witness
            .is_none()
        );
        assert!(
            check_binding(&ty, &exact_one, &table, &CoverageView::new())
                .unwrap()
                .witness
                .is_some()
        );
        // 長い長さの反例は min 未満のリストを表さない。
        let pats = [
            empty,
            exact_one,
            list(vec![Pat::Boolean(true)], true, vec![Pat::Boolean(true)]),
        ];
        assert_eq!(
            checked_issues(&ty, &pats.into_iter().map(arm).collect::<Vec<_>>(), &table),
            vec![missing("[true, .., false]")]
        );
    }
    fn option() -> (Ty, AdtTable) {
        let id = BindingId(0);
        let mut table = AdtTable::default();
        table.adts.insert(
            id,
            AdtDef {
                extensible: false,
                binding: id,
                name: "Option".into(),
                module: ModuleId(0),
                type_params: vec!["T".into()],
                ctors: vec![
                    CtorDef {
                        name: "None".into(),
                        binding: BindingId(1),
                        tag: 0,
                        fields: vec![],
                    },
                    CtorDef {
                        name: "Some".into(),
                        binding: BindingId(2),
                        tag: 1,
                        fields: vec![Ty::Param(0)],
                    },
                ],
                record: None,
                eq_summary: TypeSummary::default(),
                key_summary: TypeSummary::default(),
            },
        );
        (Ty::Con(TyCon::Adt(id), vec![builtin(B::BOOLEAN)]), table)
    }
    fn some(p: Pat) -> Pat {
        Pat::Ctor {
            adt: BindingId(0),
            tag: 1,
            args: vec![p],
        }
    }
    #[test]
    fn constructor_fields_are_instantiated_and_combined() {
        let (ty, table) = option();
        let none = Pat::Ctor {
            adt: BindingId(0),
            tag: 0,
            args: vec![],
        };
        assert_eq!(
            checked_issues(
                &ty,
                &[
                    arm(none.clone()),
                    arm(some(Pat::Boolean(true))),
                    arm(some(Pat::Boolean(false)))
                ],
                &table
            ),
            vec![]
        );
        assert_eq!(
            checked_issues(
                &ty,
                &[arm(none.clone()), arm(some(Pat::Boolean(true)))],
                &table
            ),
            vec![missing("Option.Some(false)")]
        );
        assert_eq!(
            checked_issues(
                &ty,
                &[
                    arm(some(Pat::Boolean(true))),
                    arm(none),
                    arm(some(Pat::Boolean(false))),
                    arm(some(Pat::Wild))
                ],
                &table
            ),
            vec![unreachable(3, 0, &[0, 2])]
        );
        assert!(
            check_binding(&ty, &some(Pat::Wild), &table, &CoverageView::new())
                .unwrap()
                .witness
                .is_some()
        );
    }

    // 将来の形の追加、包括的な選択肢、覆っている位置と反例の出どころを公開 API で確認する。
    #[test]
    fn extensible_shapes_require_catchalls_in_nested_source_patterns() {
        for record in [false, true] {
            let (ty, mut table) = boolean_record(1);
            let mut def = table.get(BindingId(0)).unwrap().clone();
            def.extensible = true;
            def.name = "Failure".into();
            def.ctors[0].name = "Failure".into();
            if !record {
                def.record = None;
            }
            table.adts.insert(BindingId(0), def);
            let known = Pat::Ctor {
                adt: BindingId(0),
                tag: 0,
                args: vec![Pat::Wild],
            };
            let view = BTreeSet::from([BindingId(0)]);
            let future = if record {
                "<future shape of Failure>"
            } else {
                "<future constructor of Failure>"
            };
            assert!(
                check_match(&ty, &[arm(known.clone())], &table, &CoverageView::new())
                    .unwrap()
                    .issues
                    .is_empty()
            );
            assert_eq!(
                check_match(&ty, &[arm(known.clone())], &table, &view)
                    .unwrap()
                    .issues,
                vec![MatchIssue::NonExhaustive {
                    witness: future.into(),
                    future_types: view.clone()
                }]
            );
            let binding = check_binding(&ty, &known, &table, &view).unwrap();
            assert_eq!(binding.witness.as_deref(), Some(future));
            assert_eq!(binding.future_types, view);
            assert!(
                check_binding(&ty, &Pat::Wild, &table, &view)
                    .unwrap()
                    .witness
                    .is_none()
            );
            for arms in [
                vec![arm(known.clone()), arm(Pat::Wild)],
                vec![ArmPats {
                    alts: vec![known.clone(), Pat::Wild],
                    guarded: false,
                }],
            ] {
                assert!(
                    check_match(&ty, &arms, &table, &view)
                        .unwrap()
                        .issues
                        .is_empty()
                );
            }
            let guarded = check_match(
                &ty,
                &[ArmPats {
                    alts: vec![Pat::Wild],
                    guarded: true,
                }],
                &table,
                &view,
            )
            .unwrap();
            assert_eq!(guarded.issues, vec![missing("_")]);
            let checked = check_match(
                &ty,
                &[arm(known.clone()), arm(Pat::Wild), arm(Pat::Wild)],
                &table,
                &view,
            )
            .unwrap();
            assert_eq!(checked.issues, vec![unreachable(2, 0, &[1])]);
            assert_eq!(checked.covering, vec![((2, 0), vec![(1, 0)])]);
            let checked = check_match(
                &ty,
                &[ArmPats {
                    alts: vec![known.clone(), Pat::Wild, Pat::Wild],
                    guarded: false,
                }],
                &table,
                &view,
            )
            .unwrap();
            assert_eq!(checked.issues, vec![unreachable(0, 2, &[])]);
            assert_eq!(checked.covering, vec![((0, 2), vec![(0, 1)])]);
            let list_ty = Ty::Con(TyCon::Builtin(B::LIST), vec![ty.clone()]);
            let arms = [
                arm(list(vec![], false, vec![])),
                arm(list(vec![known.clone()], true, vec![])),
            ];
            let checked = check_match(&list_ty, &arms, &table, &view).unwrap();
            assert_eq!(
                checked.issues,
                vec![MatchIssue::NonExhaustive {
                    witness: format!("[{future}, ..]"),
                    future_types: view.clone()
                }]
            );
            // 閉じた外側の Option の内側だけを外部扱いにする。
            let (_, mut outer) = option();
            let mut inner = table.get(BindingId(0)).unwrap().clone();
            inner.binding = BindingId(10);
            inner.ctors[0].binding = BindingId(11);
            if let Some(fields) = &mut inner.record {
                fields[0].binding = BindingId(12);
            }
            outer.adts.insert(BindingId(10), inner);
            let nested_ty = Ty::Con(
                TyCon::Adt(BindingId(0)),
                vec![Ty::Con(TyCon::Adt(BindingId(10)), vec![])],
            );
            let nested_known = Pat::Ctor {
                adt: BindingId(10),
                tag: 0,
                args: vec![Pat::Wild],
            };
            let nested_view = BTreeSet::from([BindingId(10)]);
            let arms = [
                arm(Pat::Ctor {
                    adt: BindingId(0),
                    tag: 0,
                    args: vec![],
                }),
                arm(some(nested_known)),
            ];
            assert_eq!(
                check_match(&nested_ty, &arms, &outer, &nested_view)
                    .unwrap()
                    .issues,
                vec![MatchIssue::NonExhaustive {
                    witness: format!("Option.Some({future})"),
                    future_types: nested_view
                }]
            );
            let expected = check_match(&ty, &[arm(known.clone())], &table, &view).unwrap();
            for limit in [0, expected.work - 1] {
                assert_eq!(
                    check_match_with(
                        &ty,
                        &[arm(known.clone())],
                        &table,
                        &mut Search::new(limit, &view)
                    ),
                    Err(Undecided)
                );
            }
        }
    }

    // 省略した先頭の欄が多くても、後ろの少数の欄を調べるだけで予算を使い切らない。
    // 判定 API で確かめ、時間や内部の記憶の表の形には依存しない。
    #[test]
    fn wide_record_tail_checks_fit_the_budget() {
        let width = 1000;
        let (ty, table) = boolean_record(width);
        let mut arms = (0..10)
            .map(|k| {
                let mut args = vec![Pat::Wild; width];
                args[width - 1 - k] = Pat::Boolean(true);
                arm(Pat::Ctor {
                    adt: BindingId(0),
                    tag: 0,
                    args,
                })
            })
            .collect::<Vec<_>>();
        arms.push(arm(Pat::Wild));
        let checked = check_match(&ty, &arms, &table, &CoverageView::new()).unwrap();
        assert!(checked.issues.is_empty());
        assert!(checked.covering.is_empty());
    }
    fn checked_issues(ty: &Ty, arms: &[ArmPats], table: &AdtTable) -> Vec<MatchIssue> {
        let view = CoverageView::new();
        let checked = check_match(ty, arms, table, &CoverageView::new()).unwrap();
        let mut search = Search::new(MAX_COVERAGE_WORK, &view);
        search.memo = None;
        let plain = check_match_with(ty, arms, table, &mut search).unwrap();
        assert_eq!(checked.issues, plain.issues);
        assert_eq!(checked.covering, plain.covering);
        checked.issues
    }
    // 予算切れは部分的な診断を返さず、ちょうど予算の内側なら以前と同じ結果を返す。
    // 非公開の探索を同じモジュールから使い、テスト用の公開の差し込み口は設けない。
    #[test]
    fn budget_stops_instead_of_returning_partial_coverage() {
        let view = CoverageView::new();
        let table = AdtTable::default();
        let ty = builtin(B::INTEGER);
        let arms = [
            arm(Pat::IntegerRange(1, 5)),
            arm(Pat::IntegerRange(6, 10)),
            arm(Pat::IntegerRange(1, 10)),
        ];
        let expected = check_match(&ty, &arms, &table, &CoverageView::new()).unwrap();
        assert_eq!(
            expected.issues,
            vec![unreachable(2, 0, &[0, 1]), missing("_")]
        );
        assert_eq!(expected.covering, vec![((2, 0), vec![(0, 0), (1, 0)])]);
        for limit in [0, expected.work - 1] {
            assert_eq!(
                check_match_with(&ty, &arms, &table, &mut Search::new(limit, &view)),
                Err(Undecided)
            );
        }
        assert_eq!(
            check_match_with(&ty, &arms, &table, &mut Search::new(expected.work, &view)),
            Ok(expected)
        );
        let pat = Pat::Boolean(true);
        assert_eq!(
            useful(
                &builtin(B::BOOLEAN),
                std::slice::from_ref(&pat),
                &Pat::Wild,
                &table,
                &mut Search::new(0, &view)
            ),
            Err(Undecided)
        );
        assert_eq!(
            check_binding(&builtin(B::BOOLEAN), &pat, &table, &CoverageView::new())
                .unwrap()
                .witness,
            Some("false".into())
        );
    }

    fn boolean_record(width: usize) -> (Ty, AdtTable) {
        let id = BindingId(0);
        let mut table = AdtTable::default();
        table.adts.insert(
            id,
            AdtDef {
                extensible: false,
                binding: id,
                name: "Flags".into(),
                module: ModuleId(0),
                type_params: vec![],
                ctors: vec![CtorDef {
                    name: "Flags".into(),
                    binding: BindingId(1),
                    tag: 0,
                    fields: vec![builtin(B::BOOLEAN); width],
                }],
                record: Some(
                    (0..width)
                        .map(|i| crate::types::FieldInfo {
                            name: format!("f{i}"),
                            binding: BindingId(u32::try_from(i + 2).unwrap()),
                        })
                        .collect(),
                ),
                eq_summary: TypeSummary::default(),
                key_summary: TypeSummary::default(),
            },
        );
        (Ty::Con(TyCon::Adt(id), vec![]), table)
    }
    fn review_arms(n: usize) -> Vec<ArmPats> {
        let mut arms = vec![];
        for group in 0..n {
            let mut args = vec![Pat::Wild; 4 * n + 1];
            for field in &mut args[4 * group..4 * group + 4] {
                *field = Pat::Boolean(false);
            }
            arms.push(arm(Pat::Ctor {
                adt: BindingId(0),
                tag: 0,
                args,
            }));
        }
        for value in [true, false] {
            let mut args = vec![Pat::Wild; 4 * n + 1];
            args[4 * n] = Pat::Boolean(value);
            arms.push(arm(Pat::Ctor {
                adt: BindingId(0),
                tag: 0,
                args,
            }));
        }
        arms
    }
    // FE-03 の重複した探索を再現する。時間の閾値には依存しない。
    #[test]
    fn repeated_boolean_groups_fit_with_memo_and_stop_without_it() {
        let view = CoverageView::new();
        let (ty, table) = boolean_record(49);
        let arms = review_arms(12);
        let checked = check_match(&ty, &arms, &table, &CoverageView::new()).unwrap();
        assert!(checked.issues.is_empty());
        assert!(checked.work <= MAX_COVERAGE_WORK);
        let mut plain = Search::new(MAX_COVERAGE_WORK, &view);
        plain.memo = None;
        assert_eq!(
            check_match_with(&ty, &arms, &table, &mut plain),
            Err(Undecided)
        );
    }
}
