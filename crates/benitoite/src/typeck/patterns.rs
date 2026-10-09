//! パターンの検査: 網羅性、選ばれない分岐、必ず照合するパターン（設計書 02-05「本体の後の検査」、01-05）。

use crate::base::BindingId;

/// 検査に使うパターン。
#[derive(Clone, PartialEq, Debug)]
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
    /// ガードを持つか。ガードの付いた分岐の行は、後の行を覆うものに数えない（02-05「本体の後の検査」）
    pub guarded: bool,
}

/// 検査の結果。
#[derive(Clone, PartialEq, Debug)]
pub enum MatchIssue {
    /// 網羅していない。`witness` はどの分岐にも照合しない値の形（`Tree.Node(Tree.Leaf, _, _)` など）
    NonExhaustive { witness: String },
    /// `arm` 番目の分岐の `alt` 番目の選択肢（どちらも 0 から数える）は選ばれない。
    /// `covered_by` は覆っている前の分岐の番号（昇順。02-05「本体の後の検査」の選び方）
    Unreachable {
        arm: usize,
        alt: usize,
        covered_by: Vec<usize>,
    },
}

use crate::types::{AdtTable, Ty};

/// 一つの `match` を検査する。選ばれない選択肢を分岐と選択肢の順に、その後に網羅していないこと（あれば一つ）を返す。
/// 構成子の名前の表示は、型名で修飾した名前（`Tree.Leaf`、`Option.Some`）とし、型の名前と同じ名前の
/// 構成子（`Pair`）とレコードは修飾しない。
pub fn check_match(scrutinee: &Ty, arms: &[ArmPats], adts: &AdtTable) -> Vec<MatchIssue> {
    let mut issues = Vec::new();
    let mut rows = Vec::new();
    for (arm, a) in arms.iter().enumerate() {
        for (alt, pat) in a.alts.iter().enumerate() {
            if useful(scrutinee, &rows, pat, adts).is_none() {
                let mut covered_by = covering_alternatives(scrutinee, arms, arm, alt, adts)
                    .into_iter()
                    .map(|(i, _)| i)
                    .filter(|i| *i != arm)
                    .collect::<Vec<_>>();
                covered_by.sort_unstable();
                covered_by.dedup();
                issues.push(MatchIssue::Unreachable {
                    arm,
                    alt,
                    covered_by,
                });
            }
            if !a.guarded {
                rows.push(pat.clone());
            }
        }
    }
    if let Some(witness) = useful(scrutinee, &rows, &Pat::Wild, adts) {
        issues.push(MatchIssue::NonExhaustive { witness });
    }
    issues
}

/// 束縛の文の左辺のパターンが必ず照合するか（01-05「必ず照合するパターン（初回リリース版）」）。
pub fn is_irrefutable(ty: &Ty, pat: &Pat, adts: &AdtTable) -> bool {
    useful(ty, std::slice::from_ref(pat), &Pat::Wild, adts).is_none()
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
            Self::Boolean(_) | Self::Unit | Self::Interval(..) | Self::String(_) | Self::Other => {
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
fn shapes(ty: &Ty, column: &[&Pat], adts: &AdtTable) -> Vec<Shape> {
    match ty {
        Ty::Con(TyCon::Adt(id), args) => adts.get(*id).map_or_else(
            || vec![Shape::Other],
            |d| {
                d.ctors
                    .iter()
                    .map(|c| Shape::Ctor {
                        adt: *id,
                        tag: c.tag,
                        fields: adts.field_types(*id, c.tag, args).unwrap_or_default(),
                    })
                    .collect()
            },
        ),
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
    }
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
fn useful(ty: &Ty, rows: &[Pat], pat: &Pat, adts: &AdtTable) -> Option<String> {
    let matrix = rows.iter().map(|p| vec![p.clone()]).collect::<Vec<_>>();
    usefulness(
        std::slice::from_ref(ty),
        &matrix,
        std::slice::from_ref(pat),
        adts,
    )
    .and_then(|v| v.into_iter().next())
}
fn usefulness(
    tys: &[Ty],
    matrix: &[Vec<Pat>],
    query: &[Pat],
    adts: &AdtTable,
) -> Option<Vec<String>> {
    if matrix
        .iter()
        .any(|row| row.iter().all(|p| matches!(p, Pat::Wild)))
    {
        return None;
    }
    let Some((q, tail)) = query.split_first() else {
        return Some(vec![]);
    };
    let (ty, types_tail) = tys.split_first()?;
    // 空の行列は候補そのものを反例にできる。再帰型の存在を展開し続けない
    // （設計書 01-05「選ばれない分岐の検査」）。
    if matrix.is_empty() {
        return Some(query.iter().map(|p| show_pattern(p, adts)).collect());
    }
    let column = matrix
        .iter()
        .filter_map(|row| row.first())
        .chain(std::iter::once(q))
        .collect::<Vec<_>>();
    if column.iter().all(|p| matches!(p, Pat::Wild)) {
        let rows = matrix
            .iter()
            .map(|row| row.iter().skip(1).cloned().collect())
            .collect::<Vec<_>>();
        let mut result = usefulness(types_tail, &rows, tail, adts)?;
        result.insert(0, "_".into());
        return Some(result);
    }
    for shape in shapes(ty, &column, adts) {
        let Some(mut args) = specialize(q, &shape) else {
            continue;
        };
        args.extend_from_slice(tail);
        let rows = matrix
            .iter()
            .filter_map(|row| {
                let mut specialized = specialize(row.first()?, &shape)?;
                specialized.extend(row.iter().skip(1).cloned());
                Some(specialized)
            })
            .collect::<Vec<_>>();
        let mut types = shape.fields();
        let arity = types.len();
        types.extend_from_slice(types_tail);
        if let Some(result) = usefulness(&types, &rows, &args, adts) {
            let (fields, rest) = result.split_at_checked(arity)?;
            let mut witness = vec![shape.show(fields, adts)];
            witness.extend_from_slice(rest);
            return Some(witness);
        }
    }
    None
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
fn overlaps(ty: &Ty, a: &Pat, b: &Pat, adts: &AdtTable) -> bool {
    if matches!(a, Pat::Wild) || matches!(b, Pat::Wild) {
        return true;
    }
    shapes(ty, &[a, b], adts).into_iter().any(|shape| {
        let (Some(xs), Some(ys)) = (specialize(a, &shape), specialize(b, &shape)) else {
            return false;
        };
        xs.len() == ys.len()
            && shape
                .fields()
                .iter()
                .zip(xs.iter().zip(&ys))
                .all(|(t, (x, y))| overlaps(t, x, y, adts))
    })
}
/// 補助の位置は分岐の番号だけでは足りないので、選択肢の単位で求める（実装プラン F10「P4」）。
pub(super) fn covering_alternatives(
    ty: &Ty,
    arms: &[ArmPats],
    arm: usize,
    alt: usize,
    adts: &AdtTable,
) -> Vec<(usize, usize)> {
    let Some(target) = arms.get(arm).and_then(|a| a.alts.get(alt)) else {
        return vec![];
    };
    let previous = arms
        .iter()
        .enumerate()
        .take(arm.saturating_add(1))
        .filter(|(_, a)| !a.guarded)
        .flat_map(|(i, a)| {
            a.alts
                .iter()
                .enumerate()
                .take(if i == arm { alt } else { a.alts.len() })
                .map(move |(j, p)| ((i, j), p))
        })
        .collect::<Vec<_>>();
    for (position, p) in &previous {
        if useful(ty, std::slice::from_ref(*p), target, adts).is_none() {
            return vec![*position];
        }
    }
    let mut rows = vec![];
    for (k, (_, p)) in previous.iter().enumerate() {
        rows.push((*p).clone());
        if useful(ty, &rows, target, adts).is_none() {
            return previous
                .iter()
                .take(k.saturating_add(1))
                .filter(|(_, p)| overlaps(ty, p, target, adts))
                .map(|(position, _)| *position)
                .collect();
        }
    }
    vec![]
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
            assert_eq!(check_match(&ty, &arms, &table), expected);
        }
        assert!(is_irrefutable(&builtin(B::UNIT), &Pat::Unit, &table));
        assert!(!is_irrefutable(
            &builtin(B::BOOLEAN),
            &Pat::Boolean(true),
            &table
        ));
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
                check_match(&ty, &pats.into_iter().map(arm).collect::<Vec<_>>(), &table),
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
            check_match(&ty, &arms, &table),
            vec![unreachable(0, 1, &[])]
        );
        let ty = builtin(B::CHARACTER);
        assert_eq!(
            check_match(
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
            check_match(
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
            check_match(&ty, std::slice::from_ref(&guarded), &adts),
            vec![missing("_")]
        );
        assert_eq!(
            check_match(&ty, &[guarded.clone(), arm(Pat::Wild)], &adts),
            vec![]
        );
        assert_eq!(
            check_match(&ty, &[arm(Pat::Wild), guarded], &adts),
            vec![unreachable(1, 0, &[0])]
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
                check_match(&ty, &pats.into_iter().map(arm).collect::<Vec<_>>(), &table),
                expected
            );
        }
        assert!(is_irrefutable(&ty, &list(vec![], true, vec![]), &table));
        assert!(!is_irrefutable(&ty, &exact_one, &table));
        // 長い長さの反例は min 未満のリストを表さない（実装プラン F10）。
        let pats = [
            empty,
            exact_one,
            list(vec![Pat::Boolean(true)], true, vec![Pat::Boolean(true)]),
        ];
        assert_eq!(
            check_match(&ty, &pats.into_iter().map(arm).collect::<Vec<_>>(), &table),
            vec![missing("[true, .., false]")]
        );
    }
    fn option() -> (Ty, AdtTable) {
        let id = BindingId(0);
        let mut table = AdtTable::default();
        table.adts.insert(
            id,
            AdtDef {
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
            check_match(
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
            check_match(
                &ty,
                &[arm(none.clone()), arm(some(Pat::Boolean(true)))],
                &table
            ),
            vec![missing("Option.Some(false)")]
        );
        assert_eq!(
            check_match(
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
        assert!(!is_irrefutable(&ty, &some(Pat::Wild), &table));
    }
}
