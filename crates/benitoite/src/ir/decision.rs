//! 判定の木への変換（設計書 02-06「判定の木への変換」、ADR 0026）。
//!
//! コア IR の `match` を、構成子や定数で分岐する `case` と、本体を共有する `join`・`jump` からなる
//! 判定の木に置き換え、コード生成に渡す下位 IR を作る。`match` 以外の計算と値は形を変えずに写す。
//!
//! 変換は 02-06 の手順 1〜6 のとおり、分岐のパターンの行列から木を作る。行列の一つの行は
//! パターンの並び・選ぶ分岐の番号・束縛の記録を持つ。木は次の三段で作る。
//!
//! - 行列から、葉が分岐の番号と束縛の記録を持つ中間の木（`Tree`）を作る（手順 1〜6）。
//! - 中間の木を辿り、分岐の番号ごとに、それを選ぶ葉の数を数える。
//! - 二つ以上の葉から選ばれる分岐に `JoinId` を振り、中間の木を下位 IR の計算に写す。
//!
//! 行列から木を作る段は新しい変数を振るので、一度だけ行う。葉の数え上げと下位 IR への写しは、
//! 作った中間の木を二回辿って行う。

use crate::base::Span;
use crate::types::{AdtTable, EffectSet, Ty, TyCon};

use super::InternalError;
use super::core_ir::{
    Arm, Comp, CompKind, Const, CorePat, CoreProgram, Def, Lambda, Val, ValKind, Var, VarId,
};
use super::lower_ir::{ConstArm, CtorArm, JoinId, LComp, LCompKind, LowerProgram};

/// `InternalError` の段の名前。
const STAGE: &str = "decision";

fn internal(message: impl Into<String>) -> InternalError {
    InternalError {
        stage: STAGE,
        message: message.into(),
    }
}

/// コア IR の `match` を判定の木に置き換えて下位 IR を作る（02-06「判定の木への変換」）。
pub fn lower_program(program: &CoreProgram) -> Result<LowerProgram, InternalError> {
    let mut defs = Vec::with_capacity(program.defs.len());
    for def in &program.defs {
        defs.push(lower_def(def, &program.adts)?);
    }
    Ok(LowerProgram {
        defs,
        adts: program.adts.clone(),
        main: program.main,
        main_returns_result: program.main_returns_result,
        lambda_count: program.lambda_count,
    })
}

/// 定義の本体を写す。新しい変数は定義の `var_count` から続けて振り、最後の値で `var_count` を
/// 更新する。変数の番号は定義ごとなので、ラムダの本体の中の `match` も同じ数え上げを使う
/// （設計書 02-06「コア IR」）。
fn lower_def(def: &Def<Comp>, adts: &AdtTable) -> Result<Def<LComp>, InternalError> {
    let mut cx = DefCx {
        adts,
        next_var: def.var_count,
        next_join: 0,
    };
    let body = cx.lower_comp(&def.body)?;
    Ok(Def {
        binding: def.binding,
        name: def.name.clone(),
        origin: def.origin,
        type_params: def.type_params.clone(),
        effect_params: def.effect_params.clone(),
        params: def.params.clone(),
        ret: def.ret.clone(),
        eff: def.eff.clone(),
        body,
        span: def.span,
        var_count: cx.next_var,
    })
}

/// パターンの行列の一つの行（設計書 02-06「判定の木への変換」）。
struct Row {
    /// 列ごとに一つのパターン
    pats: Vec<CorePat>,
    /// 選ぶ分岐の番号（元の `match` の分岐の位置）
    arm: usize,
    /// 束縛の記録。パターンの変数と、その値を入れた列の変数の組を、記録した順に並べる
    binds: Vec<(Var, Var)>,
}

/// 行列から作る中間の木。葉は分岐の本体をまだ持たず、分岐の番号と束縛の記録だけを持つ。
/// 本体を直接置くか `jump` にするかは、葉の数を数えてから決める。
enum Tree {
    Leaf {
        arm: usize,
        binds: Vec<(Var, Var)>,
    },
    Ctor {
        scrutinee: Var,
        /// タグ、構成子の引数の列の変数、分岐の木。タグの昇順
        arms: Vec<(u32, Vec<Var>, Tree)>,
        default: Option<Box<Tree>>,
    },
    Const {
        scrutinee: Var,
        /// 定数と分岐の木。最初に現れた順
        arms: Vec<(Const, Tree)>,
        default: Option<Box<Tree>>,
    },
}

/// 一つの定義を写す間の状態。
struct DefCx<'a> {
    adts: &'a AdtTable,
    /// 次に振る変数の番号
    next_var: u32,
    /// 次に振る `join` の印の番号（定義ごとに 0 から）
    next_join: u32,
}

impl DefCx<'_> {
    fn fresh_var(&mut self, ty: Ty) -> Result<Var, InternalError> {
        let id = VarId(self.next_var);
        self.next_var = self
            .next_var
            .checked_add(1)
            .ok_or_else(|| internal("variable numbers overflowed"))?;
        Ok(Var { id, name: None, ty })
    }

    fn fresh_join(&mut self) -> Result<JoinId, InternalError> {
        let id = JoinId(self.next_join);
        self.next_join = self
            .next_join
            .checked_add(1)
            .ok_or_else(|| internal("join labels overflowed"))?;
        Ok(id)
    }

    // ---- 写すだけの部分 ----

    fn lower_vals(&mut self, vals: &[Val<Comp>]) -> Result<Vec<Val<LComp>>, InternalError> {
        vals.iter().map(|v| self.lower_val(v)).collect()
    }

    /// 値を写す。ラムダの本体は計算なので、その中の `match` も変換する。
    fn lower_val(&mut self, v: &Val<Comp>) -> Result<Val<LComp>, InternalError> {
        let kind = match &v.kind {
            ValKind::Var(id) => ValKind::Var(*id),
            ValKind::Const(c) => ValKind::Const(c.clone()),
            ValKind::TopFn { def, tys, effs } => ValKind::TopFn {
                def: *def,
                tys: tys.clone(),
                effs: effs.clone(),
            },
            ValKind::Builtin { id, tys, effs } => ValKind::Builtin {
                id: *id,
                tys: tys.clone(),
                effs: effs.clone(),
            },
            ValKind::Lambda(lam) => ValKind::Lambda(Box::new(Lambda {
                id: lam.id,
                params: lam.params.clone(),
                body: self.lower_comp(&lam.body)?,
                span: lam.span,
            })),
            ValKind::Ctor {
                con,
                tag,
                tys,
                args,
            } => ValKind::Ctor {
                con: *con,
                tag: *tag,
                tys: tys.clone(),
                args: self.lower_vals(args)?,
            },
            ValKind::List(items) => ValKind::List(self.lower_vals(items)?),
        };
        Ok(Val {
            kind,
            ty: v.ty.clone(),
            origin: v.origin,
        })
    }

    /// 計算を写す。`match` だけを判定の木に置き換え、ほかは子を写して同じ形にする。
    fn lower_comp(&mut self, c: &Comp) -> Result<LComp, InternalError> {
        let kind = match &c.kind {
            CompKind::Return(v) => LCompKind::Return(self.lower_val(v)?),
            CompKind::Let { var, bound, body } => LCompKind::Let {
                var: var.clone(),
                bound: Box::new(self.lower_comp(bound)?),
                body: Box::new(self.lower_comp(body)?),
            },
            CompKind::App { func, args } => LCompKind::App {
                func: self.lower_val(func)?,
                args: self.lower_vals(args)?,
            },
            CompKind::If {
                cond,
                then_branch,
                else_branch,
            } => LCompKind::If {
                cond: self.lower_val(cond)?,
                then_branch: Box::new(self.lower_comp(then_branch)?),
                else_branch: Box::new(self.lower_comp(else_branch)?),
            },
            CompKind::Match { scrutinee, arms } => return self.lower_match(c, scrutinee, arms),
        };
        Ok(LComp {
            kind,
            ty: c.ty.clone(),
            eff: c.eff.clone(),
            origin: c.origin,
        })
    }

    // ---- match の置き換え ----

    /// `match` を判定の木に置き換える。`whole` は `match` の計算そのもので、作る計算の型と
    /// 由来位置に使う。
    fn lower_match(
        &mut self,
        whole: &Comp,
        scrutinee: &Val<Comp>,
        arms: &[Arm],
    ) -> Result<LComp, InternalError> {
        // 最初の行列: match V の V を列の変数とする 1 列、分岐ごとに 1 行、束縛の記録は空。
        // 脱糖の結果では V は常に変数である（実装プラン T20「行列と木の作り方」）。
        let ValKind::Var(id) = &scrutinee.kind else {
            return Err(internal("the scrutinee of a match is not a variable"));
        };
        let column = Var {
            id: *id,
            name: None,
            ty: scrutinee.ty.clone(),
        };
        let rows = arms
            .iter()
            .enumerate()
            .map(|(arm, a)| Row {
                pats: vec![a.pattern.clone()],
                arm,
                binds: Vec::new(),
            })
            .collect();
        let tree = self.compile(vec![column], rows)?;

        // 一回目: 分岐の番号ごとに、それを選ぶ葉の数を数える。
        let mut counts = vec![0usize; arms.len()];
        count_leaves(&tree, &mut counts)?;

        // 本体は一度だけ写す。どの葉からも選ばれない分岐（型検査が選ばれない分岐として
        // 報告するもの）の本体は、木に現れないので写さない。
        let mut bodies = Vec::with_capacity(arms.len());
        for (arm, count) in arms.iter().zip(&counts) {
            bodies.push(if *count == 0 {
                None
            } else {
                Some(self.lower_comp(&arm.body)?)
            });
        }

        // 二回目の前に、二つ以上の葉から選ばれる分岐ごとに JoinId を振る。join の引数は、
        // その分岐のパターンが束縛する変数を、パターンの中で左から現れる順に並べたもの。
        let mut joins = Vec::with_capacity(arms.len());
        for (arm, count) in arms.iter().zip(&counts) {
            joins.push(if *count >= 2 {
                let mut params = Vec::new();
                pattern_vars(&arm.pattern, &mut params);
                Some((self.fresh_join()?, params))
            } else {
                None
            });
        }

        // 二回目: 中間の木を下位 IR の計算に写す。
        let mut emit = Emit {
            ty: &whole.ty,
            origin: whole.origin,
            joins: &joins,
            bodies,
        };
        let mut result = emit.tree(tree)?;

        // join は、match を置き換えた木全体を包む位置に、分岐の番号の順に入れ子にして置く
        // （番号の小さい分岐の join を外側にする）。join のエフェクトは本体と木の和集合。
        for (arm, join) in joins.iter().enumerate().rev() {
            let Some((label, params)) = join else {
                continue;
            };
            let handler = emit.take_body(arm)?;
            let eff = handler.eff.union(&result.eff);
            result = LComp {
                kind: LCompKind::Join {
                    label: *label,
                    params: params.clone(),
                    handler: Box::new(handler),
                    body: Box::new(result),
                },
                ty: whole.ty.clone(),
                eff,
                origin: whole.origin,
            };
        }
        Ok(result)
    }

    /// 行列から中間の木を作る（設計書 02-06「判定の木への変換」の手順 1〜6）。
    /// 再帰の深さはパターンの入れ子の深さと列の数に比例し、どちらも AST の大きさで抑えられる。
    fn compile(&mut self, cols: Vec<Var>, mut rows: Vec<Row>) -> Result<Tree, InternalError> {
        // 手順 1: 行のない行列は、網羅性の検査を通った match では生じない。
        let Some(first) = rows.first() else {
            return Err(internal("a pattern matrix has no rows"));
        };
        if rows.iter().any(|r| r.pats.len() != cols.len()) {
            return Err(internal("a row of a pattern matrix has a wrong width"));
        }

        let Some(c) = first.pats.iter().position(|p| !is_wild_or_var(p)) else {
            // 手順 2: 最初の行がワイルドカードと変数だけなら、その行の分岐を選ぶ葉にする。
            // 最初の行の変数のパターンごとに、(変数, 列の変数) を束縛の記録に加える。
            let Some(row) = rows.into_iter().next() else {
                return Err(internal("a pattern matrix has no rows"));
            };
            let mut binds = row.binds;
            for (pat, col) in row.pats.iter().zip(&cols) {
                if let CorePat::Var(x) = pat {
                    binds.push((x.clone(), col.clone()));
                }
            }
            return Ok(Tree::Leaf {
                arm: row.arm,
                binds,
            });
        };

        // 手順 3: 最初の行でワイルドカードでも変数でもないパターンを持つ最も左の列 c を選ぶ。
        // 列 c が変数のパターンである各行について、束縛を記録してワイルドカードに置き換える。
        // この後、列 c の各行はワイルドカードか、構成子（または定数）のパターンである。
        let Some(col) = cols.get(c) else {
            return Err(internal("a column of a pattern matrix is missing"));
        };
        for row in &mut rows {
            let Some(pat) = row.pats.get_mut(c) else {
                return Err(internal("a row of a pattern matrix has a wrong width"));
            };
            if let CorePat::Var(x) = pat {
                row.binds.push((x.clone(), col.clone()));
                *pat = CorePat::Wild;
            }
        }

        let Ty::Con(con, targs) = &col.ty else {
            return Err(internal("a matched column does not have a data type"));
        };
        if self.adts.get(*con).is_some() {
            let targs = targs.clone();
            self.compile_ctor(&cols, &rows, c, *con, &targs)
        } else if con.is_basic() {
            self.compile_const(&cols, &rows, c, *con)
        } else {
            Err(internal("a matched column has a type without patterns"))
        }
    }

    /// 手順 4: 列 c の型が代数的データ型 `con[targs]` なら、構成子で分岐する `case` を作る。
    fn compile_ctor(
        &mut self,
        cols: &[Var],
        rows: &[Row],
        c: usize,
        con: TyCon,
        targs: &[Ty],
    ) -> Result<Tree, InternalError> {
        let Some(col) = cols.get(c) else {
            return Err(internal("a column of a pattern matrix is missing"));
        };
        let Some(ctor_count) = self.adts.get(con).map(|adt| adt.ctors.len()) else {
            return Err(internal("a data type is not in the table"));
        };

        // 列 c に現れる構成子を、タグの昇順に並べる。
        let mut tags = Vec::new();
        for row in rows {
            match row.pats.get(c) {
                Some(CorePat::Ctor { tag, .. }) => tags.push(*tag),
                Some(CorePat::Wild) => {}
                Some(CorePat::Var(_) | CorePat::Const(_)) | None => {
                    return Err(internal(
                        "a constructor column has a non-constructor pattern",
                    ));
                }
            }
        }
        tags.sort_unstable();
        tags.dedup();

        let mut arms = Vec::with_capacity(tags.len());
        for tag in &tags {
            // 構成子の引数の列の変数 y1…yn。型は構成子の宣言の引数の型を、分岐した列の型の
            // 型引数で置き換えたもの。
            let Some(field_tys) = self.adts.field_types(con, *tag, targs) else {
                return Err(internal("a constructor tag is not in the data type"));
            };
            let mut fields = Vec::with_capacity(field_tys.len());
            for ty in field_tys {
                fields.push(self.fresh_var(ty)?);
            }
            // 列 c がこの構成子の行とワイルドカードの行を元の順に残し、列 c を y1…yn に置き換える。
            // 構成子の行ではその引数のパターンを、ワイルドカードの行では n 個のワイルドカードを置く。
            let mut sub_rows = Vec::new();
            for row in rows {
                let args = match row.pats.get(c) {
                    Some(CorePat::Ctor { tag: t, args, .. }) if t == tag => {
                        if args.len() != fields.len() {
                            return Err(internal("a constructor pattern has a wrong arity"));
                        }
                        args.clone()
                    }
                    Some(CorePat::Ctor { .. }) => continue,
                    Some(CorePat::Wild) => vec![CorePat::Wild; fields.len()],
                    Some(CorePat::Var(_) | CorePat::Const(_)) | None => {
                        return Err(internal(
                            "a constructor column has a non-constructor pattern",
                        ));
                    }
                };
                sub_rows.push(Row {
                    pats: splice(&row.pats, c, args),
                    arm: row.arm,
                    binds: row.binds.clone(),
                });
            }
            // 手順 6: 分岐の行列から手順 1 に戻る。
            let sub = self.compile(splice(cols, c, fields.clone()), sub_rows)?;
            arms.push((*tag, fields, sub));
        }

        // 型の構成子のうち列 c に現れないものがあれば `_` の分岐を作る。
        let default = if tags.len() < ctor_count {
            Some(Box::new(self.compile_default(cols, rows, c)?))
        } else {
            None
        };
        Ok(Tree::Ctor {
            scrutinee: col.clone(),
            arms,
            default,
        })
    }

    /// 手順 5: 列 c の型が基本型 `con` なら、定数で分岐する `case` を作る。
    fn compile_const(
        &mut self,
        cols: &[Var],
        rows: &[Row],
        c: usize,
        con: TyCon,
    ) -> Result<Tree, InternalError> {
        let Some(col) = cols.get(c) else {
            return Err(internal("a column of a pattern matrix is missing"));
        };

        // 列 c に現れる定数を、最初に現れた順に並べる。同じ定数が二度現れたら、
        // 二つ目は選ばれない分岐なので最初のものだけを使う（実装プラン T20「String の定数」）。
        let mut consts: Vec<Const> = Vec::new();
        for row in rows {
            match row.pats.get(c) {
                Some(CorePat::Const(k)) => {
                    if const_con(k) != Some(con) {
                        return Err(internal(
                            "a constant pattern does not match the column type",
                        ));
                    }
                    if !consts.contains(k) {
                        consts.push(k.clone());
                    }
                }
                Some(CorePat::Wild) => {}
                Some(CorePat::Var(_) | CorePat::Ctor { .. }) | None => {
                    return Err(internal("a constant column has a non-constant pattern"));
                }
            }
        }

        let mut arms = Vec::with_capacity(consts.len());
        for k in &consts {
            // 列 c がこの定数の行とワイルドカードの行を元の順に残し、列 c を取り除く。
            let sub_rows = rows
                .iter()
                .filter(|r| match r.pats.get(c) {
                    Some(CorePat::Const(k2)) => k2 == k,
                    Some(CorePat::Wild) => true,
                    Some(CorePat::Var(_) | CorePat::Ctor { .. }) | None => false,
                })
                .map(|r| r.without_column(c))
                .collect();
            // 手順 6: 分岐の行列から手順 1 に戻る。
            let sub = self.compile(splice(cols, c, Vec::new()), sub_rows)?;
            arms.push((k.clone(), sub));
        }

        // 並べていない値がありうるときだけ `_` の分岐を作る。Int・String・Char は常に、
        // Bool は true と false の一方しか現れないときに作る。Unit は () が現れていれば並べ終えている。
        let needs_default = match con {
            TyCon::Int | TyCon::String | TyCon::Char => true,
            TyCon::Bool => consts.len() < 2,
            TyCon::Unit => false,
            TyCon::Float
            | TyCon::List
            | TyCon::Option
            | TyCon::Result
            | TyCon::IoError
            | TyCon::Adt(_) => {
                return Err(internal("a matched column has a type without constants"));
            }
        };
        let default = if needs_default {
            Some(Box::new(self.compile_default(cols, rows, c)?))
        } else {
            None
        };
        Ok(Tree::Const {
            scrutinee: col.clone(),
            arms,
            default,
        })
    }

    /// `_` の分岐の木。列 c がワイルドカードの行だけを元の順に残し、列 c を取り除いた行列から作る
    /// （手順 4・5 の `_` の分岐と、手順 6）。
    fn compile_default(
        &mut self,
        cols: &[Var],
        rows: &[Row],
        c: usize,
    ) -> Result<Tree, InternalError> {
        let sub_rows = rows
            .iter()
            .filter(|r| matches!(r.pats.get(c), Some(CorePat::Wild)))
            .map(|r| r.without_column(c))
            .collect();
        self.compile(splice(cols, c, Vec::new()), sub_rows)
    }
}

impl Row {
    /// 列 c を取り除いた行。束縛の記録は引き継ぐ。
    fn without_column(&self, c: usize) -> Row {
        Row {
            pats: splice(&self.pats, c, Vec::new()),
            arm: self.arm,
            binds: self.binds.clone(),
        }
    }
}

/// 中間の木を下位 IR の計算に写す間の状態。
struct Emit<'a> {
    /// 元の `match` の型
    ty: &'a Ty,
    /// 元の `match` の由来位置。作る `case`・`join`・`jump`・`let` と値に付ける
    origin: Span,
    /// 分岐の番号ごとの `join` の印と引数（二つ以上の葉から選ばれる分岐だけ）
    joins: &'a [Option<(JoinId, Vec<Var>)>],
    /// 分岐の番号ごとの、写した本体。使ったら取り出して、二度使わないことを保つ
    bodies: Vec<Option<LComp>>,
}

impl Emit<'_> {
    fn take_body(&mut self, arm: usize) -> Result<LComp, InternalError> {
        self.bodies
            .get_mut(arm)
            .and_then(Option::take)
            .ok_or_else(|| internal("an arm body is used twice or is missing"))
    }

    fn var_val(&self, v: &Var) -> Val<LComp> {
        Val {
            kind: ValKind::Var(v.id),
            ty: v.ty.clone(),
            origin: self.origin,
        }
    }

    /// 中間の木を写す。`case` のエフェクトは各分岐のエフェクトの和集合。
    fn tree(&mut self, tree: Tree) -> Result<LComp, InternalError> {
        match tree {
            Tree::Leaf { arm, binds } => self.leaf(arm, &binds),
            Tree::Ctor {
                scrutinee,
                arms,
                default,
            } => {
                let mut eff = EffectSet::empty();
                let mut out = Vec::with_capacity(arms.len());
                for (tag, fields, sub) in arms {
                    let body = self.tree(sub)?;
                    eff = eff.union(&body.eff);
                    out.push(CtorArm { tag, fields, body });
                }
                let default = self.default(default, &mut eff)?;
                Ok(self.comp(
                    LCompKind::CaseCtor {
                        scrutinee: self.var_val(&scrutinee),
                        arms: out,
                        default,
                    },
                    eff,
                ))
            }
            Tree::Const {
                scrutinee,
                arms,
                default,
            } => {
                let mut eff = EffectSet::empty();
                let mut out = Vec::with_capacity(arms.len());
                for (value, sub) in arms {
                    let body = self.tree(sub)?;
                    eff = eff.union(&body.eff);
                    out.push(ConstArm { value, body });
                }
                let default = self.default(default, &mut eff)?;
                Ok(self.comp(
                    LCompKind::CaseConst {
                        scrutinee: self.var_val(&scrutinee),
                        arms: out,
                        default,
                    },
                    eff,
                ))
            }
        }
    }

    fn default(
        &mut self,
        default: Option<Box<Tree>>,
        eff: &mut EffectSet,
    ) -> Result<Option<Box<LComp>>, InternalError> {
        let Some(tree) = default else {
            return Ok(None);
        };
        let body = self.tree(*tree)?;
        *eff = eff.union(&body.eff);
        Ok(Some(Box::new(body)))
    }

    /// 葉。二つ以上の葉から選ばれる分岐なら `jump` にし、そうでなければ本体を直接置く。
    fn leaf(&mut self, arm: usize, binds: &[(Var, Var)]) -> Result<LComp, InternalError> {
        if let Some(Some((label, params))) = self.joins.get(arm) {
            // jump の引数は、この葉の束縛の記録で各変数に当たる列の変数の値。
            // jump のエフェクトは空集合（設計書 02-06「コア IR」の表の後の段落）。
            let mut args = Vec::with_capacity(params.len());
            for p in params {
                let Some((_, col)) = binds.iter().find(|(x, _)| x.id == p.id) else {
                    return Err(internal("a pattern variable is not bound at a leaf"));
                };
                args.push(self.var_val(col));
            }
            return Ok(self.comp(
                LCompKind::Jump {
                    label: *label,
                    args,
                },
                EffectSet::empty(),
            ));
        }
        // 束縛の記録の組ごとに let x ⇐ return y in … を記録の順に本体の前に置く。
        // 内側から包むので、記録を逆の順に辿る。let の型とエフェクトは続く計算のもの。
        let mut result = self.take_body(arm)?;
        for (x, y) in binds.iter().rev() {
            let bound = LComp {
                kind: LCompKind::Return(self.var_val(y)),
                ty: y.ty.clone(),
                eff: EffectSet::empty(),
                origin: self.origin,
            };
            result = LComp {
                ty: result.ty.clone(),
                eff: result.eff.clone(),
                origin: self.origin,
                kind: LCompKind::Let {
                    var: x.clone(),
                    bound: Box::new(bound),
                    body: Box::new(result),
                },
            };
        }
        Ok(result)
    }

    /// 型を元の `match` の型、由来位置を元の `match` の由来位置とする計算を作る。
    fn comp(&self, kind: LCompKind, eff: EffectSet) -> LComp {
        LComp {
            kind,
            ty: self.ty.clone(),
            eff,
            origin: self.origin,
        }
    }
}

/// 分岐の番号ごとに、それを選ぶ葉の数を数える。
fn count_leaves(tree: &Tree, counts: &mut [usize]) -> Result<(), InternalError> {
    match tree {
        Tree::Leaf { arm, .. } => {
            let Some(n) = counts.get_mut(*arm) else {
                return Err(internal("a leaf selects an unknown arm"));
            };
            *n = n.saturating_add(1);
        }
        Tree::Ctor { arms, default, .. } => {
            for (_, _, sub) in arms {
                count_leaves(sub, counts)?;
            }
            if let Some(d) = default {
                count_leaves(d, counts)?;
            }
        }
        Tree::Const { arms, default, .. } => {
            for (_, sub) in arms {
                count_leaves(sub, counts)?;
            }
            if let Some(d) = default {
                count_leaves(d, counts)?;
            }
        }
    }
    Ok(())
}

fn is_wild_or_var(p: &CorePat) -> bool {
    matches!(p, CorePat::Wild | CorePat::Var(_))
}

/// パターンが束縛する変数を、パターンの中で左から現れる順に集める。
fn pattern_vars(p: &CorePat, out: &mut Vec<Var>) {
    match p {
        CorePat::Wild | CorePat::Const(_) => {}
        CorePat::Var(x) => out.push(x.clone()),
        CorePat::Ctor { args, .. } => {
            for a in args {
                pattern_vars(a, out);
            }
        }
    }
}

/// 定数の型の名前。Float の定数はパターンに書けない（02-06 の手順 5 の基本型に含まれない）。
fn const_con(k: &Const) -> Option<TyCon> {
    match k {
        Const::Int(_) => Some(TyCon::Int),
        Const::Str(_) => Some(TyCon::String),
        Const::Char(_) => Some(TyCon::Char),
        Const::Bool(_) => Some(TyCon::Bool),
        Const::Unit => Some(TyCon::Unit),
        Const::Float(_) => None,
    }
}

/// `items` の位置 `c` の要素を `with` の要素の並びに置き換えた並びを作る。
/// `with` が空なら位置 `c` を取り除く。
fn splice<T: Clone>(items: &[T], c: usize, with: Vec<T>) -> Vec<T> {
    items
        .iter()
        .take(c)
        .cloned()
        .chain(with)
        .chain(items.iter().skip(c.saturating_add(1)).cloned())
        .collect()
}

#[cfg(test)]
// テストの失敗は panic で表す（設計書 07-03「実装の規約と静的な検査」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use std::collections::HashMap;

    use super::*;
    use crate::base::{BindingId, BytePos, FileId};
    use crate::builtins::BuiltinId;
    use crate::ir::core_ir::{DefOrigin, LambdaId, Program};
    use crate::types::{AdtDef, CtorDef, EqSummary};

    const TREE: TyCon = TyCon::Adt(BindingId(100));
    const PAIR: TyCon = TyCon::Adt(BindingId(101));
    /// 元の `match` の計算の由来位置。作った計算がこの位置を持つかを確かめる
    const MATCH_AT: u32 = 7;

    fn span(n: u32) -> Span {
        Span {
            file: FileId(0),
            start: BytePos(n),
            end: BytePos(n),
        }
    }

    fn tree_ty(t: Ty) -> Ty {
        Ty::Con(TREE, vec![t])
    }

    fn pair_ty() -> Ty {
        Ty::con(PAIR)
    }

    /// `Option`（`Some` が 0、`None` が 1）、`type Tree[T] { Leaf | Node(Tree[T], T, Tree[T]) }`、
    /// `type Pair { MkPair(Option[Bool], Bool) }` を持つ表。
    fn adts() -> AdtTable {
        let ctor = |name: &str, binding: u32, tag: u32, fields: Vec<Ty>| CtorDef {
            name: name.to_string(),
            binding: BindingId(binding),
            tag,
            fields,
        };
        let adt = |con: TyCon, name: &str, tps: &[&str], ctors: Vec<CtorDef>| AdtDef {
            con,
            name: name.to_string(),
            type_params: tps.iter().map(|s| s.to_string()).collect(),
            ctors,
            eq_summary: EqSummary::default(),
        };
        let p0 = Ty::Param(0);
        AdtTable {
            adts: vec![
                adt(
                    TyCon::Option,
                    "Option",
                    &["T"],
                    vec![
                        ctor("Some", 1, 0, vec![p0.clone()]),
                        ctor("None", 2, 1, vec![]),
                    ],
                ),
                adt(
                    TREE,
                    "Tree",
                    &["T"],
                    vec![
                        ctor("Leaf", 110, 0, vec![]),
                        ctor(
                            "Node",
                            111,
                            1,
                            vec![tree_ty(p0.clone()), p0.clone(), tree_ty(p0)],
                        ),
                    ],
                ),
                adt(
                    PAIR,
                    "Pair",
                    &[],
                    vec![ctor(
                        "MkPair",
                        120,
                        0,
                        vec![Ty::option(Ty::bool()), Ty::bool()],
                    )],
                ),
            ],
        }
    }

    // ---- コア IR を組む補助 ----

    fn var(id: u32, ty: Ty) -> Var {
        Var {
            id: VarId(id),
            name: None,
            ty,
        }
    }

    fn val(x: &Var) -> Val<Comp> {
        Val {
            kind: ValKind::Var(x.id),
            ty: x.ty.clone(),
            origin: span(0),
        }
    }

    fn cval(k: Const, ty: Ty) -> Val<Comp> {
        Val {
            kind: ValKind::Const(k),
            ty,
            origin: span(0),
        }
    }

    fn int(n: i64) -> Val<Comp> {
        cval(Const::Int(n), Ty::int())
    }

    fn comp(kind: CompKind, ty: Ty, eff: EffectSet) -> Comp {
        Comp {
            kind,
            ty,
            eff,
            origin: span(0),
        }
    }

    fn ret(v: Val<Comp>) -> Comp {
        let ty = v.ty.clone();
        comp(CompKind::Return(v), ty, EffectSet::empty())
    }

    /// トップレベルの関数 `f7` を `args` に適用する計算（型は Int、エフェクトは空）。
    fn call_f7(args: Vec<Val<Comp>>) -> Comp {
        let func = Val {
            kind: ValKind::TopFn {
                def: BindingId(7),
                tys: vec![],
                effs: vec![],
            },
            ty: Ty::func(vec![], Ty::int(), EffectSet::empty()),
            origin: span(0),
        };
        comp(CompKind::App { func, args }, Ty::int(), EffectSet::empty())
    }

    fn match_on(x: &Var, ty: Ty, arms: Vec<(CorePat, Comp)>) -> Comp {
        let eff = arms
            .iter()
            .fold(EffectSet::empty(), |e, (_, b)| e.union(&b.eff));
        Comp {
            kind: CompKind::Match {
                scrutinee: val(x),
                arms: arms
                    .into_iter()
                    .map(|(pattern, body)| Arm { pattern, body })
                    .collect(),
            },
            ty,
            eff,
            origin: span(MATCH_AT),
        }
    }

    fn pv(x: &Var) -> CorePat {
        CorePat::Var(x.clone())
    }

    fn pctor(con: TyCon, tag: u32, args: Vec<CorePat>) -> CorePat {
        CorePat::Ctor { con, tag, args }
    }

    fn some(p: CorePat) -> CorePat {
        pctor(TyCon::Option, 0, vec![p])
    }

    fn none() -> CorePat {
        pctor(TyCon::Option, 1, vec![])
    }

    fn mkpair(a: CorePat, b: CorePat) -> CorePat {
        pctor(PAIR, 0, vec![a, b])
    }

    fn pint(n: i64) -> CorePat {
        CorePat::Const(Const::Int(n))
    }

    fn pbool(b: bool) -> CorePat {
        CorePat::Const(Const::Bool(b))
    }

    const W: CorePat = CorePat::Wild;

    fn def(binding: u32, body: Comp, var_count: u32) -> Def<Comp> {
        Def {
            binding: BindingId(binding),
            name: format!("d{binding}"),
            origin: DefOrigin::User,
            type_params: vec![],
            effect_params: vec![],
            params: vec![],
            ret: body.ty.clone(),
            eff: body.eff.clone(),
            body,
            span: span(1),
            var_count,
        }
    }

    fn program(defs: Vec<Def<Comp>>) -> CoreProgram {
        Program {
            defs,
            adts: adts(),
            main: BindingId(1),
            main_returns_result: false,
            lambda_count: 1,
        }
    }

    /// 一つの定義の本体を変換し、変換した本体と更新した `var_count` を返す。
    fn lower_body(body: Comp, var_count: u32) -> (LComp, u32) {
        let out = lower_program(&program(vec![def(1, body, var_count)])).unwrap();
        let d = out.defs.into_iter().next().unwrap();
        (d.body, d.var_count)
    }

    // ---- 下位 IR を短い表記にする補助（型と由来位置は省く） ----

    fn show_const(k: &Const) -> String {
        match k {
            Const::Int(n) => n.to_string(),
            Const::Float(f) => f.to_string(),
            Const::Str(s) => format!("{s:?}"),
            Const::Char(c) => format!("{c:?}"),
            Const::Bool(b) => b.to_string(),
            Const::Unit => "()".to_string(),
        }
    }

    fn show_vals(vs: &[Val<LComp>]) -> String {
        vs.iter().map(show_val).collect::<Vec<_>>().join(", ")
    }

    fn show_vars(vs: &[Var]) -> String {
        vs.iter()
            .map(|v| format!("v{}", v.id.0))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn show_val(v: &Val<LComp>) -> String {
        match &v.kind {
            ValKind::Var(id) => format!("v{}", id.0),
            ValKind::Const(k) => show_const(k),
            ValKind::TopFn { def, .. } => format!("f{}", def.0),
            ValKind::Builtin { id, .. } => format!("{id:?}"),
            ValKind::Lambda(lam) => {
                format!("fn({}) {{ {} }}", show_vars(&lam.params), show(&lam.body))
            }
            ValKind::Ctor { tag, args, .. } => format!("C{tag}({})", show_vals(args)),
            ValKind::List(items) => format!("[{}]", show_vals(items)),
        }
    }

    fn show(c: &LComp) -> String {
        let with_default = |mut parts: Vec<String>, default: &Option<Box<LComp>>| {
            if let Some(d) = default {
                parts.push(format!("_ => {}", show(d)));
            }
            parts.join(" | ")
        };
        match &c.kind {
            LCompKind::Return(v) => format!("return {}", show_val(v)),
            LCompKind::Let { var, bound, body } => {
                format!("let v{} = {} in {}", var.id.0, show(bound), show(body))
            }
            LCompKind::App { func, args } => format!("{}({})", show_val(func), show_vals(args)),
            LCompKind::If {
                cond,
                then_branch,
                else_branch,
            } => format!(
                "if {} then {} else {}",
                show_val(cond),
                show(then_branch),
                show(else_branch)
            ),
            LCompKind::CaseCtor {
                scrutinee,
                arms,
                default,
            } => {
                let parts = arms
                    .iter()
                    .map(|a| {
                        if a.fields.is_empty() {
                            format!("{} => {}", a.tag, show(&a.body))
                        } else {
                            format!("{}({}) => {}", a.tag, show_vars(&a.fields), show(&a.body))
                        }
                    })
                    .collect();
                format!(
                    "case {} {{ {} }}",
                    show_val(scrutinee),
                    with_default(parts, default)
                )
            }
            LCompKind::CaseConst {
                scrutinee,
                arms,
                default,
            } => {
                let parts = arms
                    .iter()
                    .map(|a| format!("{} => {}", show_const(&a.value), show(&a.body)))
                    .collect();
                format!(
                    "case {} {{ {} }}",
                    show_val(scrutinee),
                    with_default(parts, default)
                )
            }
            LCompKind::Join {
                label,
                params,
                handler,
                body,
            } => format!(
                "join k{}({}) = {} in {}",
                label.0,
                show_vars(params),
                show(handler),
                show(body)
            ),
            LCompKind::Jump { label, args } => format!("jump k{}({})", label.0, show_vals(args)),
        }
    }

    /// 下位 IR の計算を、親を子より先に並べて（前順で）集める。
    fn collect<'a>(c: &'a LComp, out: &mut Vec<&'a LComp>) {
        out.push(c);
        match &c.kind {
            LCompKind::Return(_) | LCompKind::App { .. } | LCompKind::Jump { .. } => {}
            LCompKind::Let { bound, body, .. } => {
                collect(bound, out);
                collect(body, out);
            }
            LCompKind::If {
                then_branch,
                else_branch,
                ..
            } => {
                collect(then_branch, out);
                collect(else_branch, out);
            }
            LCompKind::CaseCtor { arms, default, .. } => {
                arms.iter().for_each(|a| collect(&a.body, out));
                default.iter().for_each(|d| collect(d, out));
            }
            LCompKind::CaseConst { arms, default, .. } => {
                arms.iter().for_each(|a| collect(&a.body, out));
                default.iter().for_each(|d| collect(d, out));
            }
            LCompKind::Join { handler, body, .. } => {
                collect(handler, out);
                collect(body, out);
            }
        }
    }

    // ---- 変換の結果の形 ----

    #[test]
    fn lowers_match_to_expected_shape() {
        let int_ty = Ty::int;
        let o_int = var(0, Ty::option(Ty::int()));
        let n = var(0, Ty::int());
        let b = var(0, Ty::bool());
        let r = |n: i64| ret(int(n));

        let cases: Vec<(&str, Comp, u32, &str, u32)> = vec![
            {
                // 代数的データ型: `_` の分岐なし、join なし。構成子の引数の列の変数は var_count から振る
                let t = var(0, tree_ty(Ty::int()));
                let l = var(1, tree_ty(Ty::int()));
                let x = var(2, Ty::int());
                let rr = var(3, tree_ty(Ty::int()));
                (
                    "adt",
                    match_on(
                        &t,
                        int_ty(),
                        vec![
                            (pctor(TREE, 0, vec![]), r(0)),
                            (pctor(TREE, 1, vec![pv(&l), pv(&x), pv(&rr)]), ret(val(&x))),
                        ],
                    ),
                    4,
                    "case v0 { 0 => return 0 | 1(v4, v5, v6) => let v1 = return v4 in \
                     let v2 = return v5 in let v3 = return v6 in return v2 }",
                    7,
                )
            },
            {
                let o = var(0, Ty::option(Ty::option(Ty::int())));
                let x = var(1, Ty::int());
                (
                    "nested option",
                    match_on(
                        &o,
                        int_ty(),
                        vec![
                            (some(some(pv(&x))), ret(val(&x))),
                            (some(none()), r(1)),
                            (none(), r(2)),
                        ],
                    ),
                    2,
                    "case v0 { 0(v2) => case v2 { 0(v3) => let v1 = return v3 in return v1 \
                     | 1 => return 1 } | 1 => return 2 }",
                    4,
                )
            },
            (
                "int constants",
                match_on(
                    &n,
                    int_ty(),
                    vec![(pint(0), r(10)), (pint(1), r(11)), (W, r(12))],
                ),
                1,
                "case v0 { 0 => return 10 | 1 => return 11 | _ => return 12 }",
                1,
            ),
            (
                // 定数は現れた順に並べ、二度目に現れた定数の分岐は選ばれない
                "int constants in order of appearance",
                match_on(
                    &n,
                    int_ty(),
                    vec![
                        (pint(5), r(10)),
                        (pint(0), r(11)),
                        (pint(5), r(12)),
                        (W, r(13)),
                    ],
                ),
                1,
                "case v0 { 5 => return 10 | 0 => return 11 | _ => return 13 }",
                1,
            ),
            (
                "string constants",
                match_on(
                    &var(0, Ty::string()),
                    int_ty(),
                    vec![
                        (CorePat::Const(Const::Str("a".into())), r(10)),
                        (CorePat::Const(Const::Str("b".into())), r(11)),
                        (W, r(12)),
                    ],
                ),
                1,
                "case v0 { \"a\" => return 10 | \"b\" => return 11 | _ => return 12 }",
                1,
            ),
            (
                "bool both",
                match_on(
                    &b,
                    int_ty(),
                    vec![(pbool(true), r(10)), (pbool(false), r(11))],
                ),
                1,
                "case v0 { true => return 10 | false => return 11 }",
                1,
            ),
            (
                "bool one",
                match_on(&b, int_ty(), vec![(pbool(true), r(10)), (W, r(11))]),
                1,
                "case v0 { true => return 10 | _ => return 11 }",
                1,
            ),
            (
                "unit",
                match_on(
                    &var(0, Ty::unit()),
                    int_ty(),
                    vec![(CorePat::Const(Const::Unit), r(10))],
                ),
                1,
                "case v0 { () => return 10 }",
                1,
            ),
            (
                // 分岐 1 は二つの葉から選ばれるので join で一度だけ定める
                "shared body",
                match_on(&o_int, int_ty(), vec![(some(pint(0)), r(10)), (W, r(11))]),
                1,
                "join k0() = return 11 in case v0 { 0(v1) => case v1 { 0 => return 10 \
                 | _ => jump k0() } | _ => jump k0() }",
                2,
            ),
            {
                // 二つの葉の jump は、どちらも x を入れた列の変数 v0 を渡す
                let x = var(1, Ty::option(Ty::int()));
                (
                    "shared body with a variable",
                    match_on(
                        &o_int,
                        int_ty(),
                        vec![(some(pint(0)), r(10)), (pv(&x), call_f7(vec![val(&x)]))],
                    ),
                    2,
                    "join k0(v1) = f7(v1) in case v0 { 0(v2) => case v2 { 0 => return 10 \
                     | _ => jump k0(v0) } | _ => jump k0(v0) }",
                    3,
                )
            },
            {
                // 二つの分岐が共有されるとき、join は分岐の番号の順に入れ子にし、印は 0 から振る
                let p = var(0, Ty::option(pair_ty()));
                (
                    "two shared bodies",
                    match_on(
                        &p,
                        int_ty(),
                        vec![
                            (some(mkpair(some(pbool(true)), pbool(true))), r(10)),
                            (some(mkpair(W, pbool(true))), r(11)),
                            (W, r(12)),
                        ],
                    ),
                    1,
                    "join k0() = return 11 in join k1() = return 12 in case v0 { 0(v1) => \
                     case v1 { 0(v2, v3) => case v2 { 0(v4) => case v4 { true => case v3 { \
                     true => return 10 | _ => jump k1() } | _ => case v3 { true => jump k0() \
                     | _ => jump k1() } } | _ => case v3 { true => jump k0() | _ => jump k1() } \
                     } } | _ => jump k1() }",
                    5,
                )
            },
            {
                // 二つの変数を束縛する分岐を共有する。join の引数はパターンの左から x1, x2 の順、
                // 各 jump は同じ順に、x1・x2 を入れた列の変数 v4・v5 を渡す
                let p = var(0, Ty::option(pair_ty()));
                let x1 = var(1, Ty::option(Ty::bool()));
                let x2 = var(2, Ty::bool());
                (
                    "shared body with two variables",
                    match_on(
                        &p,
                        int_ty(),
                        vec![
                            (some(mkpair(some(pbool(true)), W)), r(10)),
                            (
                                some(mkpair(pv(&x1), pv(&x2))),
                                call_f7(vec![val(&x1), val(&x2)]),
                            ),
                            (none(), r(12)),
                        ],
                    ),
                    3,
                    "join k0(v1, v2) = f7(v1, v2) in case v0 { 0(v3) => case v3 { 0(v4, v5) => \
                     case v4 { 0(v6) => case v6 { true => return 10 | _ => jump k0(v4, v5) } \
                     | _ => jump k0(v4, v5) } } | 1 => return 12 }",
                    7,
                )
            },
            {
                let x = var(1, Ty::option(Ty::int()));
                (
                    "variable pattern only",
                    match_on(&o_int, Ty::option(Ty::int()), vec![(pv(&x), ret(val(&x)))]),
                    2,
                    "let v1 = return v0 in return v1",
                    2,
                )
            },
        ];

        for (name, body, var_count, expected, expected_var_count) in cases {
            let (lowered, new_var_count) = lower_body(body, var_count);
            assert_eq!(show(&lowered), expected, "{name}");
            assert_eq!(new_var_count, expected_var_count, "{name}: var_count");
        }
    }

    #[test]
    fn created_nodes_take_type_effect_and_origin_of_the_match() {
        // Some(0) ⇒ Console.println("a") | _ ⇒ () 。分岐 1 は二つの葉から選ばれる
        let o = var(0, Ty::option(Ty::int()));
        let println = Val {
            kind: ValKind::Builtin {
                id: BuiltinId::ConsolePrintln,
                tys: vec![],
                effs: vec![],
            },
            ty: Ty::func(vec![Ty::string()], Ty::unit(), EffectSet::io()),
            origin: span(0),
        };
        let print_call = Comp {
            kind: CompKind::App {
                func: println,
                args: vec![cval(Const::Str("a".into()), Ty::string())],
            },
            ty: Ty::unit(),
            eff: EffectSet::io(),
            origin: span(3),
        };
        let body = match_on(
            &o,
            Ty::unit(),
            vec![
                (some(pint(0)), print_call),
                (W, ret(cval(Const::Unit, Ty::unit()))),
            ],
        );
        let (lowered, _) = lower_body(body, 1);

        let LCompKind::Join { handler, body, .. } = &lowered.kind else {
            panic!("expected a join: {}", show(&lowered));
        };
        assert_eq!(lowered.eff, EffectSet::io(), "join: handler ∪ tree");
        assert!(handler.eff.is_empty());
        assert!(matches!(body.kind, LCompKind::CaseCtor { .. }));
        assert_eq!(body.eff, EffectSet::io(), "case: union of arms");

        let mut nodes = Vec::new();
        collect(&lowered, &mut nodes);
        let mut jumps = 0;
        for node in nodes {
            match &node.kind {
                LCompKind::Jump { .. } => {
                    jumps += 1;
                    assert!(node.eff.is_empty(), "jump has no effect");
                }
                LCompKind::CaseCtor { .. }
                | LCompKind::CaseConst { .. }
                | LCompKind::Join { .. } => {}
                // 分岐の本体は元の由来位置を保つ
                LCompKind::App { .. } => {
                    assert_eq!(node.origin, span(3));
                    continue;
                }
                LCompKind::Return(_) | LCompKind::Let { .. } | LCompKind::If { .. } => continue,
            }
            assert_eq!(node.ty, Ty::unit());
            assert_eq!(node.origin, span(MATCH_AT));
        }
        assert_eq!(jumps, 2);

        // 葉の前に置く let は、続く計算の型とエフェクトを持ち、match の由来位置を持つ
        let x = var(1, Ty::int());
        let print_x = Comp {
            kind: CompKind::App {
                func: Val {
                    kind: ValKind::TopFn {
                        def: BindingId(8),
                        tys: vec![],
                        effs: vec![],
                    },
                    ty: Ty::func(vec![Ty::int()], Ty::string(), EffectSet::io()),
                    origin: span(0),
                },
                args: vec![val(&x)],
            },
            ty: Ty::string(),
            eff: EffectSet::io(),
            origin: span(3),
        };
        let (lowered, _) = lower_body(
            match_on(
                &o,
                Ty::string(),
                vec![
                    (some(pv(&x)), print_x),
                    (none(), ret(cval(Const::Str("n".into()), Ty::string()))),
                ],
            ),
            2,
        );
        let LCompKind::CaseCtor { arms, .. } = &lowered.kind else {
            panic!("expected a case: {}", show(&lowered));
        };
        let let_node = &arms[0].body;
        assert!(matches!(let_node.kind, LCompKind::Let { .. }));
        assert_eq!(let_node.ty, Ty::string());
        assert_eq!(let_node.eff, EffectSet::io());
        assert_eq!(let_node.origin, span(MATCH_AT));
    }

    #[test]
    fn copies_everything_but_match_and_numbers_per_definition() {
        // let v1 ⇐ f7(v0) in if v1 then return (λ(v2). match v2 { true ⇒ 1 | false ⇒ 2 })
        //                     else return Some([1, 2])
        let x0 = var(0, Ty::int());
        let x1 = var(1, Ty::bool());
        let x2 = var(2, Ty::bool());
        let lam_body = match_on(
            &x2,
            Ty::int(),
            vec![(pbool(true), ret(int(1))), (pbool(false), ret(int(2)))],
        );
        let lam = Val {
            kind: ValKind::Lambda(Box::new(Lambda {
                id: LambdaId(0),
                params: vec![x2.clone()],
                body: lam_body,
                span: span(2),
            })),
            ty: Ty::func(vec![Ty::bool()], Ty::int(), EffectSet::empty()),
            origin: span(2),
        };
        let list = Val {
            kind: ValKind::List(vec![int(1), int(2)]),
            ty: Ty::list(Ty::int()),
            origin: span(0),
        };
        let some_list = Val {
            kind: ValKind::Ctor {
                con: TyCon::Option,
                tag: 0,
                tys: vec![Ty::list(Ty::int())],
                args: vec![list],
            },
            ty: Ty::option(Ty::list(Ty::int())),
            origin: span(0),
        };
        let if_comp = comp(
            CompKind::If {
                cond: val(&x1),
                then_branch: Box::new(ret(lam)),
                else_branch: Box::new(ret(some_list)),
            },
            Ty::unit(),
            EffectSet::empty(),
        );
        let plain = comp(
            CompKind::Let {
                var: x1.clone(),
                bound: Box::new(call_f7(vec![val(&x0)])),
                body: Box::new(if_comp),
            },
            Ty::unit(),
            EffectSet::empty(),
        );

        // 共有する本体を持つ match の定義を二つ置き、join の印が定義ごとに 0 から振られることを見る
        let o = var(0, Ty::option(Ty::int()));
        let shared = || {
            match_on(
                &o,
                Ty::int(),
                vec![(some(pint(0)), ret(int(10))), (W, ret(int(11)))],
            )
        };
        let input = program(vec![
            def(1, plain.clone(), 3),
            def(2, shared(), 1),
            def(3, shared(), 1),
        ]);
        let out = lower_program(&input).unwrap();

        assert_eq!(out.adts, input.adts);
        assert_eq!(out.main, input.main);
        assert_eq!(out.main_returns_result, input.main_returns_result);
        assert_eq!(out.lambda_count, input.lambda_count);
        assert_eq!(out.defs.len(), 3);

        let d = &out.defs[0];
        assert_eq!(
            show(&d.body),
            "let v1 = f7(v0) in if v1 then return fn(v2) { case v2 { true => return 1 \
             | false => return 2 } } else return C0([1, 2])"
        );
        assert_eq!(d.var_count, 3);
        let src = &input.defs[0];
        assert_eq!(
            (
                &d.name, d.binding, d.origin, &d.params, &d.ret, &d.eff, d.span
            ),
            (
                &src.name,
                src.binding,
                src.origin,
                &src.params,
                &src.ret,
                &src.eff,
                src.span
            )
        );
        // 写しただけの計算は、型・エフェクト・由来位置も元のまま
        let LCompKind::Let { bound, .. } = &d.body.kind else {
            panic!("expected a let");
        };
        assert_eq!(
            (&bound.ty, &bound.eff, bound.origin),
            (&Ty::int(), &EffectSet::empty(), span(0))
        );

        for d in &out.defs[1..] {
            assert!(
                show(&d.body).starts_with("join k0() = "),
                "{}",
                show(&d.body)
            );
        }
    }

    #[test]
    fn reports_internal_error_for_impossible_matches() {
        let o = var(0, Ty::option(Ty::int()));
        let not_a_variable = Comp {
            kind: CompKind::Match {
                scrutinee: int(1),
                arms: vec![Arm {
                    pattern: W,
                    body: ret(int(0)),
                }],
            },
            ty: Ty::int(),
            eff: EffectSet::empty(),
            origin: span(0),
        };
        let cases = [
            ("scrutinee is not a variable", not_a_variable),
            ("no arms", match_on(&o, Ty::int(), vec![])),
            // 網羅していない match は、行のない行列を生む（手順 1）
            (
                "not exhaustive",
                match_on(&o, Ty::int(), vec![(none(), ret(int(0)))]),
            ),
        ];
        for (name, body) in cases {
            let err = lower_program(&program(vec![def(1, body, 1)])).unwrap_err();
            assert_eq!(err.stage, "decision", "{name}");
        }
    }

    // ---- 分岐の順序を保つこと ----

    /// テストの中で使う実行時の値。
    #[derive(Clone, PartialEq, Debug)]
    enum TestVal {
        Ctor(u32, Vec<TestVal>),
        Const(Const),
    }

    /// 型のすべての値を並べる（Bool と、Bool からなる代数的データ型だけを扱う）。
    fn all_values(ty: &Ty, adts: &AdtTable) -> Vec<TestVal> {
        let Ty::Con(con, targs) = ty else {
            panic!("unsupported type {ty:?}");
        };
        if *con == TyCon::Bool {
            return vec![
                TestVal::Const(Const::Bool(false)),
                TestVal::Const(Const::Bool(true)),
            ];
        }
        let adt = adts.get(*con).expect("data type");
        let mut out = Vec::new();
        for ctor in &adt.ctors {
            let mut combos: Vec<Vec<TestVal>> = vec![vec![]];
            for fty in adts.field_types(*con, ctor.tag, targs).unwrap() {
                let vals = all_values(&fty, adts);
                combos = combos
                    .into_iter()
                    .flat_map(|prefix| {
                        vals.iter().map(move |v| {
                            let mut p = prefix.clone();
                            p.push(v.clone());
                            p
                        })
                    })
                    .collect();
            }
            out.extend(combos.into_iter().map(|fs| TestVal::Ctor(ctor.tag, fs)));
        }
        out
    }

    /// 01-12 の `match(p, V)`。照合したら束縛した値を左から順に `out` に加える。
    fn pattern_matches(p: &CorePat, v: &TestVal, out: &mut Vec<TestVal>) -> bool {
        match (p, v) {
            (CorePat::Wild, _) => true,
            (CorePat::Var(_), _) => {
                out.push(v.clone());
                true
            }
            (CorePat::Const(k), TestVal::Const(c)) => k == c,
            (CorePat::Ctor { tag, args, .. }, TestVal::Ctor(t, fields)) => {
                tag == t
                    && args
                        .iter()
                        .zip(fields)
                        .all(|(p, f)| pattern_matches(p, f, out))
            }
            (CorePat::Const(_), TestVal::Ctor(..)) | (CorePat::Ctor { .. }, TestVal::Const(_)) => {
                false
            }
        }
    }

    fn eval(v: &Val<LComp>, env: &HashMap<VarId, TestVal>) -> TestVal {
        match &v.kind {
            ValKind::Var(id) => env[id].clone(),
            ValKind::Const(k) => TestVal::Const(k.clone()),
            ValKind::Ctor { tag, args, .. } => {
                TestVal::Ctor(*tag, args.iter().map(|a| eval(a, env)).collect())
            }
            ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::Lambda(_)
            | ValKind::List(_) => {
                panic!("unexpected value")
            }
        }
    }

    /// 下位 IR の判定の木を、変数 `scrutinee` を `value` として辿り、行き着いた `return` の値を返す。
    fn run_tree(c: &LComp, scrutinee: VarId, value: TestVal) -> TestVal {
        let mut env = HashMap::from([(scrutinee, value)]);
        let mut joins: HashMap<JoinId, (&[Var], &LComp)> = HashMap::new();
        let mut cur = c;
        loop {
            match &cur.kind {
                LCompKind::Return(v) => return eval(v, &env),
                LCompKind::Let { var, bound, body } => {
                    let LCompKind::Return(v) = &bound.kind else {
                        panic!("unexpected let");
                    };
                    let x = eval(v, &env);
                    env.insert(var.id, x);
                    cur = body;
                }
                LCompKind::CaseCtor {
                    scrutinee,
                    arms,
                    default,
                } => {
                    let TestVal::Ctor(tag, fields) = eval(scrutinee, &env) else {
                        panic!("case on a constant");
                    };
                    match arms.iter().find(|a| a.tag == tag) {
                        Some(a) => {
                            assert_eq!(a.fields.len(), fields.len());
                            for (f, v) in a.fields.iter().zip(fields) {
                                env.insert(f.id, v);
                            }
                            cur = &a.body;
                        }
                        None => cur = default.as_deref().expect("no default"),
                    }
                }
                LCompKind::CaseConst {
                    scrutinee,
                    arms,
                    default,
                } => {
                    let TestVal::Const(k) = eval(scrutinee, &env) else {
                        panic!("case on a constructor");
                    };
                    cur = match arms.iter().find(|a| a.value == k) {
                        Some(a) => &a.body,
                        None => default.as_deref().expect("no default"),
                    };
                }
                LCompKind::Join {
                    label,
                    params,
                    handler,
                    body,
                } => {
                    joins.insert(*label, (params, handler));
                    cur = body;
                }
                LCompKind::Jump { label, args } => {
                    let (params, handler) = joins[label];
                    let vals: Vec<TestVal> = args.iter().map(|a| eval(a, &env)).collect();
                    assert_eq!(params.len(), vals.len());
                    for (p, v) in params.iter().zip(vals) {
                        env.insert(p.id, v);
                    }
                    cur = handler;
                }
                LCompKind::App { .. } | LCompKind::If { .. } => panic!("unexpected computation"),
            }
        }
    }

    #[test]
    fn decision_tree_selects_the_first_matching_arm_with_its_bindings() {
        let adts = adts();
        let b = Ty::bool;
        let ob = || Ty::option(Ty::bool());
        let op = || Ty::option(pair_ty());
        let t = || pbool(true);
        let f = || pbool(false);
        let x = |id: u32, ty: Ty| pv(&var(id, ty));

        let sets: Vec<(Ty, Vec<CorePat>)> = vec![
            (
                op(),
                vec![
                    some(mkpair(some(t()), W)),
                    some(mkpair(W, f())),
                    some(x(1, pair_ty())),
                    none(),
                ],
            ),
            (
                op(),
                vec![
                    some(mkpair(none(), x(1, b()))),
                    some(mkpair(some(x(2, b())), t())),
                    x(3, op()),
                ],
            ),
            (
                op(),
                vec![
                    some(mkpair(x(1, ob()), t())),
                    some(mkpair(some(f()), x(2, b()))),
                    some(x(3, pair_ty())),
                    none(),
                ],
            ),
            // 最初の行の最も左の列がワイルドカードなので、右の列から分岐する
            (
                pair_ty(),
                vec![
                    mkpair(W, t()),
                    mkpair(some(t()), W),
                    mkpair(x(1, ob()), f()),
                ],
            ),
            // 変数を束縛する分岐を共有する（jump が束縛した値を渡す）
            (op(), vec![some(mkpair(some(t()), x(1, b()))), x(2, op())]),
            (op(), vec![some(mkpair(x(1, ob()), x(2, b()))), none()]),
            // 二つの変数を束縛する分岐を共有する（jump が二つの値を順に渡す）
            (
                op(),
                vec![
                    some(mkpair(some(t()), W)),
                    some(mkpair(x(1, ob()), x(2, b()))),
                    none(),
                ],
            ),
            // 選ばれない分岐を含む
            (ob(), vec![none(), some(W), none(), x(1, ob())]),
        ];

        for (i, (ty, pats)) in sets.into_iter().enumerate() {
            let scrutinee = var(0, ty.clone());
            // 分岐 k の本体は、分岐の番号 k をタグとし、束縛した変数を左から並べた値を返す
            let arms: Vec<(CorePat, Comp)> = pats
                .iter()
                .enumerate()
                .map(|(k, p)| {
                    let mut vars = Vec::new();
                    pattern_vars(p, &mut vars);
                    let body = ret(Val {
                        kind: ValKind::Ctor {
                            con: TyCon::Unit,
                            tag: u32::try_from(k).unwrap(),
                            tys: vec![],
                            args: vars.iter().map(val).collect(),
                        },
                        ty: Ty::unit(),
                        origin: span(0),
                    });
                    (p.clone(), body)
                })
                .collect();
            let (lowered, _) = lower_body(match_on(&scrutinee, Ty::unit(), arms), 10);

            let values = all_values(&ty, &adts);
            assert!(!values.is_empty());
            for value in values {
                let expected = pats
                    .iter()
                    .enumerate()
                    .find_map(|(k, p)| {
                        let mut bound = Vec::new();
                        pattern_matches(p, &value, &mut bound)
                            .then(|| TestVal::Ctor(u32::try_from(k).unwrap(), bound))
                    })
                    .expect("exhaustive");
                let got = run_tree(&lowered, VarId(0), value.clone());
                assert_eq!(
                    got,
                    expected,
                    "set {i}, value {value:?}\n{}",
                    show(&lowered)
                );
            }
        }
    }
}
