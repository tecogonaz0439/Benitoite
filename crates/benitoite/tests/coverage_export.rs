//! E1c-1: 公開の網羅性検査の出力を、独立した Lean の手順と比較する。
// テストの失敗は panic で表す。生成する型とパターン以外は書き出さない。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use benitoite::base::{BindingId, ModuleId};
use benitoite::typeck::patterns::{ArmPats, MatchIssue, Pat, check_match, is_irrefutable};
use benitoite::types::builtin::BuiltinTypeId as B;
use benitoite::types::{AdtDef, AdtTable, CtorDef, FieldInfo, Ty, TyCon, TypeArg, TypeSummary};
use serde_json::{Value, json};
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::time::Instant;

const RANDOM_CASES: usize = 10_000;
const MAX_DEPTH: usize = 3;
const MAX_NODES: usize = 40;
const INTEGERS: [i64; 9] = [
    i64::MIN,
    i64::MIN + 1,
    -10,
    -1,
    0,
    1,
    10,
    i64::MAX - 1,
    i64::MAX,
];
const CHARS: [char; 8] = [
    '\0',
    'a',
    'b',
    'z',
    '\u{d7fe}',
    '\u{d7ff}',
    '\u{e000}',
    '\u{10ffff}',
];

// random_programs/generator.rs と同じ SplitMix64。種と交換形式は出力に保持する。
struct Random(u64);
impl Random {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut x = self.0;
        x = (x ^ (x >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        x = (x ^ (x >> 27)).wrapping_mul(0x94d049bb133111eb);
        x ^ (x >> 31)
    }
    fn index(&mut self, n: usize) -> usize {
        usize::try_from(self.next() % u64::try_from(n).unwrap()).unwrap()
    }
}
fn base(b: B) -> Ty {
    Ty::Con(TyCon::Builtin(b), vec![])
}
fn data(n: u32, args: Vec<Ty>) -> Ty {
    Ty::Con(TyCon::Adt(BindingId(n)), args)
}
fn list(a: Ty) -> Ty {
    Ty::Con(TyCon::Builtin(B::LIST), vec![a])
}
fn con(n: u32, tag: u32, args: Vec<Pat>) -> Pat {
    Pat::Ctor {
        adt: BindingId(n),
        tag,
        args,
    }
}
fn lp(before: Vec<Pat>, rest: bool, after: Vec<Pat>) -> Pat {
    Pat::List {
        before,
        rest,
        after,
    }
}
fn arm(p: Pat) -> ArmPats {
    ArmPats {
        alts: vec![p],
        guarded: false,
    }
}

fn declarations(r: &mut Random) -> AdtTable {
    let mut table = AdtTable::default();
    // 宣言順、自己参照、型引数、型と同名の構成子、レコードを毎回含める。
    let mut defs = vec![
        (
            "Option",
            1,
            vec![("None", vec![]), ("Some", vec![Ty::Param(0)])],
            None,
        ),
        (
            "Tree",
            1,
            vec![
                ("Leaf", vec![]),
                (
                    "Node",
                    vec![
                        data(1, vec![Ty::Param(0)]),
                        Ty::Param(0),
                        data(1, vec![Ty::Param(0)]),
                    ],
                ),
            ],
            None,
        ),
        ("Toggle", 0, vec![("On", vec![]), ("Off", vec![])], None),
        (
            "Pair",
            2,
            vec![("Pair", vec![Ty::Param(0), Ty::Param(1)])],
            Some(vec!["first", "last"]),
        ),
    ];
    let choices = [
        Ty::Param(0),
        base(B::BOOLEAN),
        list(Ty::Param(0)),
        data(0, vec![Ty::Param(0)]),
        data(3, vec![Ty::Param(0), base(B::UNIT)]),
    ];
    let mut ctors = vec![];
    for name in ["Empty", "Many", "Choice"] {
        let n = if name == "Empty" { 0 } else { 1 + r.index(4) };
        ctors.push((
            name,
            (0..n)
                .map(|_| choices[r.index(choices.len())].clone())
                .collect(),
        ));
    }
    defs.push(("Choice", 1, ctors, None));
    // data の型と同名の構成子の表示も、record と別に比較する。
    defs.push(("Box", 1, vec![("Box", vec![Ty::Param(0)])], None));
    for (n, (name, params, ctors, record)) in defs.into_iter().enumerate() {
        let binding = BindingId(u32::try_from(n).unwrap());
        let ctors: Vec<_> = ctors
            .into_iter()
            .enumerate()
            .map(|(tag, (name, fields))| CtorDef {
                name: name.into(),
                binding: BindingId(100 + binding.0 * 10 + u32::try_from(tag).unwrap()),
                tag: u32::try_from(tag).unwrap(),
                fields,
            })
            .collect();
        table.adts.insert(
            binding,
            AdtDef {
                binding,
                name: name.into(),
                module: ModuleId(0),
                type_params: (0..params).map(|i| format!("T{i}")).collect(),
                ctors,
                record: record.map(|names| {
                    names
                        .into_iter()
                        .enumerate()
                        .map(|(i, name)| FieldInfo {
                            name: name.into(),
                            binding: BindingId(500 + binding.0 * 10 + u32::try_from(i).unwrap()),
                        })
                        .collect()
                }),
                eq_summary: TypeSummary::default(),
                key_summary: TypeSummary::default(),
            },
        );
    }
    table
}
fn gen_ty(r: &mut Random, depth: usize) -> Ty {
    let k = r.index(if depth == 0 { 5 } else { 12 });
    match k {
        0 => base(B::INTEGER),
        1 => base(B::CHARACTER),
        2 => base(B::STRING),
        3 => base(B::BOOLEAN),
        4 => base(B::UNIT),
        5 => list(gen_ty(r, depth - 1)),
        8 => data(2, vec![]),
        9 => data(3, vec![gen_ty(r, depth - 1), gen_ty(r, depth - 1)]),
        _ => data(
            match k {
                6 => 0,
                7 => 1,
                10 => 4,
                _ => 5,
            },
            vec![gen_ty(r, depth - 1)],
        ),
    }
}
fn gen_pat(r: &mut Random, ty: &Ty, table: &AdtTable, depth: usize, nodes: &mut usize) -> Pat {
    if depth == 0 || *nodes >= MAX_NODES || r.index(5) == 0 {
        return Pat::Wild;
    }
    *nodes += 1;
    match ty {
        Ty::Con(TyCon::Adt(id), args) => {
            let def = table.get(*id).unwrap();
            let ctor = &def.ctors[r.index(def.ctors.len())];
            let ts: Vec<_> = args.iter().cloned().map(TypeArg::Ty).collect();
            con(
                id.0,
                ctor.tag,
                ctor.fields
                    .iter()
                    .map(|t| gen_pat(r, &t.subst(&ts, &[]), table, depth - 1, nodes))
                    .collect(),
            )
        }
        Ty::Con(TyCon::Builtin(b), args) => match *b {
            B::INTEGER => {
                let a = INTEGERS[r.index(INTEGERS.len())];
                let b = INTEGERS[r.index(INTEGERS.len())];
                if r.index(2) == 0 {
                    Pat::Integer(a)
                } else {
                    Pat::IntegerRange(a.min(b), a.max(b))
                }
            }
            B::CHARACTER => {
                let a = CHARS[r.index(CHARS.len())];
                let b = CHARS[r.index(CHARS.len())];
                if r.index(2) == 0 {
                    Pat::Character(a)
                } else {
                    Pat::CharacterRange(a.min(b), a.max(b))
                }
            }
            B::STRING => Pat::String(["", "a", "b", "日本語", "\"\\\n"][r.index(5)].into()),
            B::BOOLEAN => Pat::Boolean(r.index(2) == 0),
            B::UNIT => Pat::Unit,
            B::LIST => {
                let n = r.index(4);
                let m = r.index(4 - n);
                let rest = r.index(2) == 0;
                let before = (0..n)
                    .map(|_| gen_pat(r, &args[0], table, depth - 1, nodes))
                    .collect();
                let after = (0..m)
                    .map(|_| gen_pat(r, &args[0], table, depth - 1, nodes))
                    .collect();
                lp(before, rest, after)
            }
            _ => panic!("unexpected builtin"),
        },
        Ty::Param(_) | Ty::App(_, _) | Ty::Rigid { .. } | Ty::Fn(_) => {
            panic!("uninstantiated type")
        }
    }
}
fn ty_json(t: &Ty) -> Value {
    match t {
        Ty::Con(TyCon::Adt(id), args) => {
            json!({"kind":"data", "name":format!("d{}",id.0), "args":args.iter().map(ty_json).collect::<Vec<_>>()})
        }
        Ty::Con(TyCon::Builtin(b), args) => {
            json!({"kind":b.def().unwrap().name.to_lowercase(),"args":args.iter().map(ty_json).collect::<Vec<_>>()})
        }
        Ty::Param(i) => json!({"kind":"param","index":i}),
        Ty::App(_, _) | Ty::Rigid { .. } | Ty::Fn(_) => panic!("unexpected type"),
    }
}
fn pat_json(p: &Pat) -> Value {
    match p {
        Pat::Wild => json!({"kind":"wild"}),
        Pat::Ctor { adt, tag, args } => {
            json!({"kind":"con","name":format!("d{}c{tag}",adt.0),"args":args.iter().map(pat_json).collect::<Vec<_>>()})
        }
        Pat::Integer(n) => json!({"kind":"integer","value":n}),
        Pat::Character(c) => json!({"kind":"character","value":u32::from(*c)}),
        Pat::String(s) => json!({"kind":"string","value":s}),
        Pat::Boolean(b) => json!({"kind":"boolean","value":b}),
        Pat::Unit => json!({"kind":"unit"}),
        Pat::IntegerRange(lo, hi) => json!({"kind":"integerRange","lo":lo,"hi":hi}),
        Pat::CharacterRange(lo, hi) => {
            json!({"kind":"characterRange","lo":u32::from(*lo),"hi":u32::from(*hi)})
        }
        Pat::List {
            before,
            rest,
            after,
        } => {
            json!({"kind":"list","before":before.iter().map(pat_json).collect::<Vec<_>>(),"rest":rest,"after":after.iter().map(pat_json).collect::<Vec<_>>()})
        }
    }
}
fn result(ty: &Ty, arms: &[ArmPats], table: &AdtTable) -> Value {
    let mut uncovered = None;
    let mut unreachable = vec![];
    for issue in check_match(ty, arms, table) {
        match issue {
            MatchIssue::NonExhaustive { witness } => uncovered = Some(witness),
            MatchIssue::Unreachable {
                arm,
                alt,
                covered_by,
            } => unreachable.push(json!({"arm":arm,"alt":alt,"coveredBy":covered_by})),
        }
    }
    json!({"exhaustive":uncovered.is_none(),"uncovered":uncovered,"unreachable":unreachable})
}
fn export_case(name: String, ty: Ty, arms: Vec<ArmPats>, p: Pat, table: &AdtTable) -> Value {
    let ds: Vec<_> = (0..6).map(|n| {
        let d = table.get(BindingId(n)).unwrap();
        json!({"name":format!("d{n}"),"typeName":d.name,"ntys":d.type_params.len(),
            "fields":d.record.as_ref().map(|fs| fs.iter().map(|f| f.name.clone()).collect::<Vec<_>>()),
            "ctors":d.ctors.iter().map(|c| json!({"name":format!("d{n}c{}",c.tag),"constructorName":c.name,"tag":c.tag,"args":c.fields.iter().map(ty_json).collect::<Vec<_>>()})).collect::<Vec<_>>()})
    }).collect();
    let ir = is_irrefutable(&ty, &p, table);
    let single = result(&ty, &[arm(p.clone())], table);
    assert_eq!(ir, single["exhaustive"].as_bool().unwrap());
    json!({"name":name,"decls":ds,"ty":ty_json(&ty),"arms":arms.iter().map(|a| json!({"guarded":a.guarded,"alts":a.alts.iter().map(pat_json).collect::<Vec<_>>()})).collect::<Vec<_>>(),
        "pattern":pat_json(&p),"expected":result(&ty,&arms,table),"irrefutable":ir,"irrefutableWitness":single["uncovered"]})
}
fn boundaries(table: &AdtTable) -> Vec<Value> {
    let mut cases = vec![];
    let mut add = |name: &str, ty: Ty, arms: Vec<ArmPats>, p: Pat| {
        cases.push(export_case(name.into(), ty, arms, p, table))
    };
    // E0601/2/7/8 を持つ七つのファイルの九つの照合と同じ形。
    for (name, ty, p, q) in [
        (
            "golden/integer",
            base(B::INTEGER),
            Pat::Integer(0),
            Pat::Integer(1),
        ),
        (
            "golden/string",
            base(B::STRING),
            Pat::String("a".into()),
            Pat::String("b".into()),
        ),
        (
            "golden/character",
            base(B::CHARACTER),
            Pat::Character('a'),
            Pat::Character('b'),
        ),
    ] {
        add(name, ty, vec![arm(p.clone()), arm(q)], p);
    }
    add(
        "golden/after-wild",
        base(B::INTEGER),
        vec![arm(Pat::Wild), arm(Pat::Integer(0))],
        Pat::Wild,
    );
    let opt = data(0, vec![base(B::INTEGER)]);
    add(
        "golden/refutable-bind",
        opt.clone(),
        vec![arm(con(0, 1, vec![Pat::Wild]))],
        con(0, 1, vec![Pat::Wild]),
    );
    add(
        "golden/option",
        opt,
        vec![
            arm(con(0, 1, vec![Pat::Integer(1)])),
            arm(con(0, 0, vec![])),
        ],
        con(0, 1, vec![Pat::Integer(1)]),
    );
    add(
        "golden/tree",
        data(1, vec![base(B::INTEGER)]),
        vec![arm(con(1, 0, vec![]))],
        con(1, 0, vec![]),
    );
    add(
        "golden/covering-many",
        data(0, vec![base(B::BOOLEAN)]),
        vec![
            arm(con(0, 1, vec![Pat::Boolean(true)])),
            arm(con(0, 1, vec![Pat::Boolean(false)])),
            arm(con(0, 1, vec![Pat::Wild])),
            arm(con(0, 0, vec![])),
        ],
        con(0, 1, vec![Pat::Wild]),
    );
    add(
        "golden/toggle",
        data(2, vec![]),
        vec![arm(con(2, 0, vec![]))],
        con(2, 0, vec![]),
    );
    add(
        "boundary/i64",
        base(B::INTEGER),
        vec![
            arm(Pat::IntegerRange(i64::MIN, 0)),
            arm(Pat::IntegerRange(1, i64::MAX)),
            arm(Pat::IntegerRange(i64::MIN, i64::MAX)),
            arm(Pat::Wild),
        ],
        Pat::IntegerRange(i64::MIN, i64::MAX),
    );
    add(
        "boundary/surrogate",
        base(B::CHARACTER),
        vec![
            arm(Pat::CharacterRange('\0', '\u{d7ff}')),
            arm(Pat::CharacterRange('\u{e000}', '\u{10ffff}')),
            arm(Pat::CharacterRange('\0', '\u{10ffff}')),
            arm(Pat::Wild),
        ],
        Pat::CharacterRange('\0', '\u{10ffff}'),
    );
    for n in 0..=3 {
        add(
            &format!("boundary/list-{n}"),
            list(base(B::BOOLEAN)),
            (0..=n)
                .map(|k| arm(lp(vec![Pat::Wild; k], false, vec![])))
                .collect(),
            lp(vec![Pat::Wild; n], false, vec![]),
        );
    }
    add(
        "boundary/front-back",
        list(base(B::BOOLEAN)),
        vec![
            arm(lp(vec![], false, vec![])),
            arm(lp(vec![Pat::Wild], false, vec![])),
            arm(lp(vec![Pat::Boolean(true)], true, vec![Pat::Boolean(true)])),
        ],
        lp(vec![], true, vec![]),
    );
    for (name, prior) in [
        ("duplicate", vec![Pat::Integer(1), Pat::Integer(1)]),
        (
            "union",
            vec![
                Pat::IntegerRange(0, 1),
                Pat::IntegerRange(2, 3),
                Pat::IntegerRange(0, 3),
            ],
        ),
        ("wild", vec![Pat::Wild, Pat::Integer(1)]),
    ] {
        add(
            &format!("q3/{name}"),
            base(B::INTEGER),
            vec![
                ArmPats {
                    alts: prior,
                    guarded: true,
                },
                arm(Pat::Wild),
            ],
            Pat::Integer(1),
        );
    }
    add(
        "q3/covered-by",
        base(B::INTEGER),
        vec![
            arm(Pat::IntegerRange(0, 1)),
            arm(Pat::IntegerRange(2, 3)),
            ArmPats {
                alts: vec![Pat::IntegerRange(0, 3), Pat::IntegerRange(0, 3)],
                guarded: true,
            },
            arm(Pat::Wild),
        ],
        Pat::Wild,
    );
    cases
}
fn count_kinds(j: &Value, stats: &mut BTreeMap<String, usize>) {
    match j {
        Value::Object(obj) => {
            if let Some(Value::String(k)) = obj.get("kind") {
                *stats.entry(k.clone()).or_default() += 1;
            }
            for v in obj.values() {
                count_kinds(v, stats);
            }
        }
        Value::Array(xs) => {
            for v in xs {
                count_kinds(v, stats);
            }
        }
        Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {}
    }
}
#[test]
#[ignore = "formal: scripts/check-formal.sh が走らせる"]
fn export_coverage() {
    let started = Instant::now();
    let repo = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .unwrap();
    let dir = std::env::var_os("BENITOITE_COVERAGE_DIFF_DIR")
        .map_or_else(|| repo.join("target/coverage-diff/default"), PathBuf::from);
    fs::create_dir_all(&dir).unwrap();
    let dir = dir.canonicalize().unwrap();
    assert!(
        dir.starts_with(&repo) && dir != repo,
        "output directory must be inside the repository"
    );
    let mut cases = boundaries(&declarations(&mut Random(0)));
    let boundary_count = cases.len();
    for seed in 0..RANDOM_CASES {
        let mut r = Random(u64::try_from(seed).unwrap() ^ 0xe1c1);
        let table = declarations(&mut r);
        let ty = gen_ty(&mut r, MAX_DEPTH);
        let mut arms: Vec<ArmPats> = vec![];
        for _ in 0..r.index(7) {
            let mut alts: Vec<Pat> = vec![];
            for _ in 0..1 + r.index(3) {
                let p = if !alts.is_empty() && r.index(4) == 0 {
                    alts[0].clone()
                } else {
                    gen_pat(&mut r, &ty, &table, MAX_DEPTH, &mut 0)
                };
                alts.push(p);
            }
            arms.push(ArmPats {
                alts,
                guarded: r.index(3) == 0,
            });
        }
        let p = gen_pat(&mut r, &ty, &table, MAX_DEPTH, &mut 0);
        cases.push(export_case(format!("random/{seed}"), ty, arms, p, &table));
    }
    let mut stats = BTreeMap::new();
    for c in &cases {
        count_kinds(
            &json!({"ty":c["ty"],"arms":c["arms"],"pattern":c["pattern"]}),
            &mut stats,
        );
    }
    let corpus = json!({"version":1,"seedXor":0xe1c1,"randomCases":RANDOM_CASES,"boundaryCases":boundary_count,"kinds":stats,"cases":cases});
    let bytes = serde_json::to_vec(&corpus).unwrap();
    let roundtrip: Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(roundtrip, corpus, "JSON must preserve i64 boundaries");
    fs::write(dir.join("corpus.json"), bytes).unwrap();
    println!(
        "coverage export: {} cases ({} boundary, {} random), {:.3}s",
        cases.len(),
        boundary_count,
        RANDOM_CASES,
        started.elapsed().as_secs_f64()
    );
}
