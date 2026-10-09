//! 計算と値の移し方（設計書 02-07「コード生成」、実装プラン 10-07「コード生成」）。

use super::*;
use crate::builtins::table::{ListPatternOp, list_pattern_builtin};
use analysis::with_reads;

impl<'p> Gen<'p> {
    pub(super) fn comp(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        match &c.kind {
            LCompKind::Return(v) => self.return_(fg, v, target, c.origin, future),
            LCompKind::Let { .. } => self.let_(fg, c, target, future),
            LCompKind::App { func, dicts, args } => {
                self.app(fg, func, dicts, args, (target, c.origin), future)
            }
            LCompKind::Method(m) => self.method(fg, m, target, c.origin, future),
            LCompKind::If { .. } => self.if_(fg, c, target, future),
            LCompKind::CaseCtor { .. } => self.case_ctor(fg, c, target, future),
            LCompKind::CaseConst { .. } => self.case_const(fg, c, target, future),
            LCompKind::CaseLength { .. } => self.case_length(fg, c, target, future),
            LCompKind::ListGet { list, from, index } => self.list_prim(
                fg,
                list,
                ListPatternOp::Get(*from),
                &[*index],
                (target, c.origin),
                future,
            ),
            LCompKind::ListSlice {
                list,
                drop_front,
                drop_back,
            } => self.list_prim(
                fg,
                list,
                ListPatternOp::Slice,
                &[*drop_front, *drop_back],
                (target, c.origin),
                future,
            ),
            LCompKind::Join { .. } => self.join(fg, c, target, future),
            LCompKind::Jump { label, args } => self.jump(fg, *label, args, c.origin, future),
            LCompKind::Escape(v) => {
                let mark = fg.next_reg;
                let r = self.operand(fg, v, future)?;
                fg.emit(
                    Instr::abc(
                        if fg.boundary {
                            Opcode::Return
                        } else {
                            Opcode::Escape
                        },
                        r16(r),
                        0,
                        0,
                    ),
                    Some(c.origin),
                );
                fg.release(mark);
                Ok(())
            }
            LCompKind::Use { .. } => self.use_(fg, c, target, future),
            LCompKind::Lazy { body, .. } => {
                let mark = fg.next_reg;
                let dst = fg.result(target);
                let index = self.body_proto(
                    fg,
                    body,
                    &[],
                    (
                        false,
                        text::LAZY.to_string(),
                        ProtoOrigin::UserLazy,
                        c.origin,
                    ),
                )?;
                fg.emit(Instr::abx(Opcode::Lazy, r16(dst), index.0), Some(c.origin));
                fg.returned(target, dst, Some(c.origin));
                fg.release(mark);
                Ok(())
            }
            LCompKind::Handle(h) => self.handle(fg, h, target, c.origin),
            LCompKind::Resume { cont, value } => {
                let mark = fg.next_reg;
                let k = self.key_operand(fg, Key::Var(*cont), c.origin)?;
                let v = self.operand(fg, value, future)?;
                let dst = fg.result(target);
                fg.emit(
                    Instr::abc(Opcode::Resume, r16(dst), r16(k), r16(v)),
                    Some(c.origin),
                );
                fg.returned(target, dst, Some(c.origin));
                fg.release(mark);
                Ok(())
            }
        }
    }

    fn return_(
        &mut self,
        fg: &mut FnGen<'p>,
        v: &'p LowVal,
        target: Target,
        origin: Span,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        match target {
            Target::Reg(r) => self.val(fg, v, r, future),
            Target::Tail => {
                let mark = fg.next_reg;
                let r = self.operand(fg, v, future)?;
                fg.returned(target, r, Some(origin));
                fg.release(mark);
                Ok(())
            }
        }
    }
    fn let_(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::Let { var, bound, body } = &c.kind else {
            return Err(internal("expected let"));
        };
        let mark = fg.next_reg;
        let r = fg.alloc();
        let next = Box::new(with_reads(future, Node::Comp(body)));
        self.comp(fg, bound, Target::Reg(r), &next)?;
        fg.bind(Key::Var(var.id), Loc::Reg(r))?;
        if let LCompKind::Return(LowVal {
            kind: ValKind::Var(of),
            ..
        }) = &bound.kind
        {
            fg.alias(Key::Var(var.id), Key::Var(*of));
        }
        self.comp(fg, body, target, future)?;
        fg.unbind(Key::Var(var.id));
        fg.release(mark);
        Ok(())
    }
    fn app(
        &mut self,
        fg: &mut FnGen<'p>,
        func: &'p LowVal,
        dicts: &'p [DictVal],
        args: &'p [LowVal],
        site: (Target, Span),
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let (target, origin) = site;
        let mark = fg.next_reg;
        if let ValKind::Builtin { id, targs, info } = &func.kind {
            if !dicts.is_empty() {
                return Err(internal("builtin with dictionary arguments"));
            }
            if let Some(intrinsic) = info.intrinsic {
                self.intrinsic(fg, intrinsic, targs, args, (target, origin), future)?;
            } else {
                let decl = crate::builtins::builtin_decl(*id)
                    .ok_or_else(|| internal("unknown builtin"))?;
                if usize::from(decl.arity) != args.len() || decl.capability != info.class {
                    return Err(internal("builtin call disagrees with declaration"));
                }
                let b = self.builtin(*id, info.op)?;
                let base = fg.alloc_block(count(args.len())?);
                self.vals(fg, args, base, future)?;
                let dst = fg.result(target);
                fg.emit(
                    Instr::abc(
                        if info.class == Capability::Io {
                            Opcode::Io
                        } else {
                            Opcode::Prim
                        },
                        r16(dst),
                        r16(b.0),
                        r16(base),
                    ),
                    Some(origin),
                );
                fg.returned(target, dst, Some(origin));
            }
        } else if let ValKind::Op { op, .. } = &func.kind {
            if !dicts.is_empty() {
                return Err(internal("operation with dictionary arguments"));
            }
            let index = self.operation(*op)?;
            let arity = self
                .out
                .op(index)
                .ok_or_else(|| internal("unknown operation"))?
                .arity;
            if usize::from(arity) != args.len() {
                return Err(internal("wrong operation arity"));
            }
            let base = fg.alloc_block(count(args.len())?);
            self.vals(fg, args, base, future)?;
            let dst = fg.result(target);
            fg.emit(
                Instr::abc(Opcode::Perform, r16(dst), r16(index.0), r16(base)),
                Some(origin),
            );
            fg.returned(target, dst, Some(origin));
        } else {
            let n = count(dicts.len().saturating_add(args.len()))?;
            let base = fg.alloc_block(n.saturating_add(1));
            let mut next = future.clone();
            for d in dicts {
                next.extend(free_keys(Node::Dict(d), Vec::new()));
            }
            for a in args {
                next.extend(free_keys(Node::Val(a), Vec::new()));
            }
            self.val(fg, func, base, &next)?;
            self.dicts(fg, dicts, base.saturating_add(1))?;
            self.vals(
                fg,
                args,
                base.saturating_add(1).saturating_add(count(dicts.len())?),
                future,
            )?;
            let instr = match target {
                Target::Reg(r) => Instr::abc(Opcode::Call, r16(r), r16(base), r16(n)),
                Target::Tail => Instr::abc(Opcode::TailCall, 0, r16(base), r16(n)),
            };
            fg.emit(instr, Some(origin));
        }
        fg.release(mark);
        Ok(())
    }
    fn method(
        &mut self,
        fg: &mut FnGen<'p>,
        m: &'p MethodCall<LComp>,
        target: Target,
        origin: Span,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let mark = fg.next_reg;
        let class = self.trait_(m.dict.class)?;
        let base = fg.alloc_block(count(
            m.dicts.len().saturating_add(m.args.len()).saturating_add(1),
        )?);
        self.dict(fg, &m.dict, base)?;
        self.dicts(fg, &m.dicts, base.saturating_add(1))?;
        self.vals(
            fg,
            &m.args,
            base.saturating_add(1).saturating_add(count(m.dicts.len())?),
            future,
        )?;
        let instr = match target {
            Target::Reg(r) => Instr::abc(Opcode::Method, r16(r), r16(base), r16(m.method)),
            Target::Tail => Instr::abc(Opcode::TailMethod, 0, r16(base), r16(m.method)),
        };
        let pc = fg.emit(instr, Some(origin));
        *fg.method_traits
            .get_mut(pc)
            .ok_or_else(|| internal("missing method trait slot"))? = Some(class);
        fg.release(mark);
        Ok(())
    }
    fn intrinsic(
        &mut self,
        fg: &mut FnGen<'p>,
        intrinsic: Intrinsic,
        types: &TypeArgs,
        args: &'p [LowVal],
        site: (Target, Span),
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let (target, origin) = site;
        let plan = plan(intrinsic, types)?;
        let mut regs = Vec::new();
        let mut next = future.clone();
        for a in args {
            next.extend(free_keys(Node::Val(a), Vec::new()));
        }
        for a in args {
            regs.push(self.operand(fg, a, &next)?);
        }
        let dst = fg.result(target);
        self.emit_plan(fg, plan, &regs, dst, Some(origin))?;
        fg.returned(target, dst, Some(origin));
        Ok(())
    }
    fn emit_plan(
        &mut self,
        fg: &mut FnGen<'p>,
        plan: Plan,
        args: &[u32],
        dst: u32,
        origin: Option<Span>,
    ) -> CgResult<()> {
        match plan {
            Plan::Bool(b) => {
                if args.len() != 2 {
                    return Err(internal("equality arity mismatch"));
                }
                let k = self.constant(ConstDesc::Bool(b))?;
                fg.load(dst, k, origin)?;
            }
            Plan::Unary(op) => {
                let [x] = args else {
                    return Err(internal("unary intrinsic arity mismatch"));
                };
                fg.emit(Instr::abc(op, r16(dst), r16(*x), 0), origin);
            }
            Plan::Binary { op, swap, negate } => {
                let [x, y] = args else {
                    return Err(internal("binary intrinsic arity mismatch"));
                };
                let (x, y) = if swap { (y, x) } else { (x, y) };
                fg.emit(Instr::abc(op, r16(dst), r16(*x), r16(*y)), origin);
                if negate {
                    fg.emit(Instr::abc(Opcode::Not, r16(dst), r16(dst), 0), origin);
                }
            }
        }
        Ok(())
    }
    fn if_(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::If {
            cond,
            then_branch,
            else_branch,
        } = &c.kind
        else {
            return Err(internal("expected if"));
        };
        let mark = fg.next_reg;
        let next = with_reads(
            &with_reads(future, Node::Comp(then_branch)),
            Node::Comp(else_branch),
        );
        let r = self.operand(fg, cond, &next)?;
        let jf = fg.jump(Opcode::JmpF, r, c.origin);
        fg.release(mark);
        let before = fg.reuse.clone();
        self.comp(fg, then_branch, target, future)?;
        let after = fg.reuse.clone();
        let end = fg.jump_to_end(target, c.origin);
        fg.patch_here(jf)?;
        fg.reuse = before;
        self.comp(fg, else_branch, target, future)?;
        merge_reuse(&mut fg.reuse, &after);
        fg.end(end)
    }
    fn use_(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::Use { resource, body } = &c.kind else {
            return Err(internal("expected use"));
        };
        let mark = fg.next_reg;
        let dst = fg.result(target);
        let next = with_reads(future, Node::Comp(body));
        let r = self.operand(fg, resource, &next)?;
        fg.emit(Instr::abc(Opcode::Use, r16(r), 0, 0), Some(c.origin));
        self.comp(fg, body, Target::Reg(dst), future)?;
        fg.emit(Instr::abc(Opcode::Release, 0, 0, 0), Some(c.origin));
        fg.returned(target, dst, Some(c.origin));
        fg.release(mark);
        Ok(())
    }
}

fn merge_reuse(into: &mut [state::Reuse], other: &[state::Reuse]) {
    for (a, b) in into.iter_mut().zip(other) {
        a.used |= b.used;
        a.captured |= b.captured;
    }
}

enum Plan {
    Bool(bool),
    Unary(Opcode),
    Binary {
        op: Opcode,
        swap: bool,
        negate: bool,
    },
}
fn binary(op: Opcode) -> Plan {
    Plan::Binary {
        op,
        swap: false,
        negate: false,
    }
}

fn plan(intrinsic: Intrinsic, types: &TypeArgs) -> CgResult<Plan> {
    match intrinsic {
        Intrinsic::Force => Ok(Plan::Unary(Opcode::Force)),
        Intrinsic::Update => Ok(binary(Opcode::Update)),
        Intrinsic::Eq | Intrinsic::Ne => {
            let ty = match types.tys.first() {
                Some(TypeArg::Ty(ty)) => ty,
                Some(TypeArg::Head(_)) | None => {
                    return Err(internal("equality has no value type argument"));
                }
            };
            equality(ty, intrinsic == Intrinsic::Ne)
        }
        Intrinsic::Operator { op, operand } => {
            use BuiltinTypeId as T;
            use OperatorKind as O;
            let opcode = match (op, operand) {
                (O::Add, T::INTEGER) => Opcode::AddI,
                (O::Sub, T::INTEGER) => Opcode::SubI,
                (O::Mul, T::INTEGER) => Opcode::MulI,
                (O::IntDiv, T::INTEGER) => Opcode::DivI,
                (O::Mod, T::INTEGER) => Opcode::ModI,
                (O::Neg, T::INTEGER) => Opcode::NegI,
                (O::Add, T::FLOAT) => Opcode::AddF,
                (O::Sub, T::FLOAT) => Opcode::SubF,
                (O::Mul, T::FLOAT) => Opcode::MulF,
                (O::Div, T::FLOAT) => Opcode::DivF,
                (O::Neg, T::FLOAT) => Opcode::NegF,
                (O::Add, T::DECIMAL) => Opcode::AddD,
                (O::Sub, T::DECIMAL) => Opcode::SubD,
                (O::Mul, T::DECIMAL) => Opcode::MulD,
                (O::Div, T::DECIMAL) => Opcode::DivD,
                (O::Neg, T::DECIMAL) => Opcode::NegD,
                (O::Add, T::STRING) => Opcode::Concat,
                (O::Lt | O::Gt, T::INTEGER) => Opcode::LtI,
                (O::Le | O::Ge, T::INTEGER) => Opcode::LeI,
                (O::Lt | O::Gt, T::FLOAT) => Opcode::LtF,
                (O::Le | O::Ge, T::FLOAT) => Opcode::LeF,
                (O::Lt | O::Gt, T::DECIMAL) => Opcode::LtD,
                (O::Le | O::Ge, T::DECIMAL) => Opcode::LeD,
                (O::Lt | O::Gt, T::STRING) => Opcode::LtS,
                (O::Le | O::Ge, T::STRING) => Opcode::LeS,
                (O::Lt | O::Gt, T::CHARACTER) => Opcode::LtC,
                (O::Le | O::Ge, T::CHARACTER) => Opcode::LeC,
                (O::Lt | O::Gt, T::BYTE) => Opcode::LtBt,
                (O::Le | O::Ge, T::BYTE) => Opcode::LeBt,
                _ => return Err(internal("unsupported operator and operand type")),
            };
            Ok(if op == O::Neg {
                Plan::Unary(opcode)
            } else {
                Plan::Binary {
                    op: opcode,
                    swap: matches!(op, O::Gt | O::Ge),
                    negate: false,
                }
            })
        }
    }
}

fn equality(ty: &Ty, negate: bool) -> CgResult<Plan> {
    use BuiltinTypeId as T;
    let op = match ty {
        Ty::Con(TyCon::Builtin(id), _) => match *id {
            T::INTEGER => Opcode::EqI,
            T::FLOAT => Opcode::EqF,
            T::DECIMAL => Opcode::EqD,
            T::STRING => Opcode::EqS,
            T::CHARACTER => Opcode::EqC,
            T::BYTE => Opcode::EqBt,
            T::BOOLEAN => Opcode::EqB,
            T::UNIT => return Ok(Plan::Bool(!negate)),
            T::LIST | T::MAP | T::SET | T::BYTES => Opcode::EqV,
            _ => return Err(internal("equality on an opaque type")),
        },
        Ty::Con(TyCon::Adt(_), _) | Ty::Param(_) | Ty::App(_, _) | Ty::Rigid { .. } => Opcode::EqV,
        Ty::Fn(_) => return Err(internal("equality on a function type")),
    };
    Ok(Plan::Binary {
        op,
        swap: false,
        negate,
    })
}

impl<'p> Gen<'p> {
    fn case_ctor(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::CaseCtor {
            scrutinee,
            adt,
            arms,
            default,
        } = &c.kind
        else {
            return Err(internal("expected constructor case"));
        };
        let tag_count = self
            .input
            .adts
            .get(*adt)
            .ok_or_else(|| internal("case of unknown type"))?
            .ctors
            .len();
        let mark = fg.next_reg;
        let next = with_reads(future, Node::Comp(c));
        let s = self.operand(fg, scrutinee, &next)?;
        let table = fg.switch_tables.len();
        fg.switch_tables.push(SwitchTable {
            targets: vec![None; tag_count],
            default: None,
        });
        let switch = fg.emit(
            Instr::abx(Opcode::Switch, r16(s), count(table)?),
            Some(c.origin),
        );
        let arm_mark = fg.next_reg;
        let before = Box::new(fg.reuse.clone());
        let mut after = before.clone();
        let mut ends = Vec::new();
        for (i, arm) in arms.iter().enumerate() {
            fg.reuse = (*before).clone();
            let offset = relative(switch, fg.code.len())?;
            let slot = usize::try_from(arm.tag)
                .ok()
                .and_then(|i| fg.switch_tables.get_mut(table)?.targets.get_mut(i))
                .ok_or_else(|| internal("invalid case tag"))?;
            if slot.is_some() {
                return Err(internal("duplicate case tag"));
            }
            *slot = Some(offset);
            for (i, field) in arm.fields.iter().enumerate() {
                let r = fg.alloc();
                fg.bind(Key::Var(field.id), Loc::Reg(r))?;
                fg.emit(
                    Instr::abc(Opcode::Field, r16(r), r16(s), r16(count(i)?)),
                    Some(c.origin),
                );
            }
            let aliases = if let ValKind::Var(x) = scrutinee.kind {
                fg.aliases
                    .get(&Key::Var(x))
                    .cloned()
                    .unwrap_or_else(|| HashSet::from([Key::Var(x)]))
            } else {
                HashSet::new()
            };
            let captured = analysis::captured(Node::Comp(&arm.body));
            fg.reuse.push(state::Reuse {
                reg: s,
                captured: !aliases.is_disjoint(&captured),
                aliases,
                arity: arm.fields.len(),
                used: false,
            });
            self.comp(fg, &arm.body, target, future)?;
            fg.reuse.pop();
            merge_reuse(&mut after, &fg.reuse);
            for field in &arm.fields {
                fg.unbind(Key::Var(field.id));
            }
            fg.release(arm_mark);
            if (default.is_some() || i.saturating_add(1) < arms.len())
                && let Some(j) = fg.jump_to_end(target, c.origin)
            {
                ends.push(j);
            }
        }
        if let Some(body) = default {
            fg.reuse = (*before).clone();
            let offset = relative(switch, fg.code.len())?;
            fg.switch_tables
                .get_mut(table)
                .ok_or_else(|| internal("missing switch table"))?
                .default = Some(offset);
            self.comp(fg, body, target, future)?;
            merge_reuse(&mut after, &fg.reuse);
        }
        fg.reuse = *after;
        for j in ends {
            fg.patch_here(j)?;
        }
        fg.release(mark);
        Ok(())
    }
    fn test_const(
        &mut self,
        fg: &mut FnGen<'p>,
        s: u32,
        test: &ConstTest,
        origin: Span,
    ) -> CgResult<Vec<usize>> {
        let mark = fg.next_reg;
        let t = fg.alloc();
        let mut jumps = Vec::new();
        match test {
            ConstTest::Eq(c) => {
                let k = self.constant(tables::scalar(c))?;
                fg.load(t, k, Some(origin))?;
                let ty = const_ty(c);
                self.emit_plan(fg, equality(&ty, false)?, &[s, t], t, Some(origin))?;
                jumps.push(fg.jump(Opcode::JmpF, t, origin));
            }
            ConstTest::Range(lo, hi) => {
                let op = match (lo, hi) {
                    (Const::Int(_), Const::Int(_)) => Opcode::LeI,
                    (Const::Char(_), Const::Char(_)) => Opcode::LeC,
                    _ => return Err(internal("invalid constant range")),
                };
                let k = self.constant(tables::scalar(lo))?;
                fg.load(t, k, Some(origin))?;
                fg.emit(Instr::abc(op, r16(t), r16(t), r16(s)), Some(origin));
                jumps.push(fg.jump(Opcode::JmpF, t, origin));
                let k = self.constant(tables::scalar(hi))?;
                fg.load(t, k, Some(origin))?;
                fg.emit(Instr::abc(op, r16(t), r16(s), r16(t)), Some(origin));
                jumps.push(fg.jump(Opcode::JmpF, t, origin));
            }
        }
        fg.release(mark);
        Ok(jumps)
    }
    fn case_const(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::CaseConst {
            scrutinee,
            arms,
            default,
        } = &c.kind
        else {
            return Err(internal("expected constant case"));
        };
        let mark = fg.next_reg;
        let s = self.operand(fg, scrutinee, &with_reads(future, Node::Comp(c)))?;
        let before = Box::new(fg.reuse.clone());
        let mut after = before.clone();
        let mut ends = Vec::new();
        for (i, arm) in arms.iter().enumerate() {
            fg.reuse = (*before).clone();
            let compare = default.is_some() || i.saturating_add(1) < arms.len();
            let jumps = if compare {
                self.test_const(fg, s, &arm.test, c.origin)?
            } else {
                Vec::new()
            };
            self.comp(fg, &arm.body, target, future)?;
            merge_reuse(&mut after, &fg.reuse);
            if compare && let Some(j) = fg.jump_to_end(target, c.origin) {
                ends.push(j);
            }
            for j in jumps {
                fg.patch_here(j)?;
            }
        }
        if let Some(body) = default {
            fg.reuse = (*before).clone();
            self.comp(fg, body, target, future)?;
            merge_reuse(&mut after, &fg.reuse);
        }
        if arms.is_empty() && default.is_none() {
            return Err(internal("empty constant case"));
        }
        fg.reuse = *after;
        for j in ends {
            fg.patch_here(j)?;
        }
        fg.release(mark);
        Ok(())
    }
    fn case_length(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::CaseLength {
            scrutinee,
            exact,
            at_least,
            otherwise,
        } = &c.kind
        else {
            return Err(internal("expected length case"));
        };
        let mark = fg.next_reg;
        let len = fg.alloc();
        self.list_prim(
            fg,
            scrutinee,
            ListPatternOp::Length,
            &[],
            (Target::Reg(len), c.origin),
            &with_reads(future, Node::Comp(c)),
        )?;
        let before = Box::new(fg.reuse.clone());
        let mut after = before.clone();
        let mut ends = Vec::new();
        if exact.is_empty() {
            self.comp(fg, otherwise, target, future)?;
            fg.release(mark);
            return Ok(());
        }
        // 大きい長さを先に分け、残る小さい長さを昇順で調べる（10-06「下位 IR」）。
        let temp_mark = fg.next_reg;
        let t = fg.alloc();
        let k = self.constant(ConstDesc::Int(i64::from(*at_least)))?;
        fg.load(t, k, Some(c.origin))?;
        fg.emit(
            Instr::abc(Opcode::LeI, r16(t), r16(t), r16(len)),
            Some(c.origin),
        );
        let jf = fg.jump(Opcode::JmpF, t, c.origin);
        fg.release(temp_mark);
        self.comp(fg, otherwise, target, future)?;
        merge_reuse(&mut after, &fg.reuse);
        if let Some(j) = fg.jump_to_end(target, c.origin) {
            ends.push(j);
        }
        fg.patch_here(jf)?;
        for (i, arm) in exact.iter().enumerate() {
            // 残る長さは最後の分岐の長さに等しい。比較を省き、最後を必ず終端にする。
            let jumps = if i.saturating_add(1) < exact.len() {
                self.test_const(
                    fg,
                    len,
                    &ConstTest::Eq(Const::Int(i64::from(arm.len))),
                    c.origin,
                )?
            } else {
                Vec::new()
            };
            fg.reuse = (*before).clone();
            self.comp(fg, &arm.body, target, future)?;
            merge_reuse(&mut after, &fg.reuse);
            if i.saturating_add(1) < exact.len()
                && let Some(j) = fg.jump_to_end(target, c.origin)
            {
                ends.push(j);
            }
            for j in jumps {
                fg.patch_here(j)?;
            }
        }
        fg.reuse = *after;
        for j in ends {
            fg.patch_here(j)?;
        }
        fg.release(mark);
        Ok(())
    }
    fn list_prim(
        &mut self,
        fg: &mut FnGen<'p>,
        list: &'p LowVal,
        op: ListPatternOp,
        indices: &[u32],
        site: (Target, Span),
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let (target, origin) = site;
        let mark = fg.next_reg;
        let id =
            list_pattern_builtin(op).ok_or_else(|| internal("missing list pattern builtin"))?;
        let b = self.builtin(id, None)?;
        let base = fg.alloc_block(count(indices.len().saturating_add(1))?);
        self.val(fg, list, base, future)?;
        for (i, index) in indices.iter().enumerate() {
            let k = self.constant(ConstDesc::Int(i64::from(*index)))?;
            fg.load(
                base.saturating_add(1).saturating_add(count(i)?),
                k,
                Some(origin),
            )?;
        }
        let dst = fg.result(target);
        fg.emit(
            Instr::abc(Opcode::Prim, r16(dst), r16(b.0), r16(base)),
            Some(origin),
        );
        fg.returned(target, dst, Some(origin));
        fg.release(mark);
        Ok(())
    }
    fn join(
        &mut self,
        fg: &mut FnGen<'p>,
        c: &'p LComp,
        target: Target,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let LCompKind::Join {
            label,
            params,
            handler,
            body,
        } = &c.kind
        else {
            return Err(internal("expected join"));
        };
        let mark = fg.next_reg;
        let regs: Vec<u32> = params.iter().map(|_| fg.alloc()).collect();
        if fg
            .joins
            .insert(
                *label,
                state::JoinState {
                    params: regs.clone(),
                    target: None,
                    pending: Vec::new(),
                    reuse: fg.reuse.clone(),
                },
            )
            .is_some()
        {
            return Err(internal("duplicate join label"));
        }
        let next = Box::new(with_reads(future, Node::Comp(handler)));
        self.comp(fg, body, target, &next)?;
        let end = fg.jump_to_end(target, c.origin);
        let here = fg.code.len();
        let join = fg
            .joins
            .get_mut(label)
            .ok_or_else(|| internal("missing join"))?;
        join.target = Some(here);
        let pending = std::mem::take(&mut join.pending);
        let incoming = join.reuse.clone();
        for pc in pending {
            fg.patch(pc, here)?;
        }
        for (param, reg) in params.iter().zip(regs) {
            fg.bind(Key::Var(param.id), Loc::Reg(reg))?;
        }
        // 合流へ跳んだ道筋だけで使用と捕捉を合わせる。合流を通らない道筋の使用で候補を失わない（02-07「その場での再利用」）。
        let mut saved = std::mem::replace(&mut fg.reuse, incoming);
        self.comp(fg, handler, target, future)?;
        merge_reuse(&mut saved, &fg.reuse);
        fg.reuse = saved;
        for param in params {
            fg.unbind(Key::Var(param.id));
        }
        fg.joins.remove(label);
        fg.end(end)?;
        fg.release(mark);
        Ok(())
    }
    fn jump(
        &mut self,
        fg: &mut FnGen<'p>,
        label: JoinId,
        args: &'p [LowVal],
        origin: Span,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let params = fg
            .joins
            .get(&label)
            .ok_or_else(|| internal("jump to unknown join"))?
            .params
            .clone();
        if params.len() != args.len() {
            return Err(internal("jump arity mismatch"));
        }
        // 合流の引数が元の値を上書きしないよう、全引数を読んでから移す（02-07「分岐と合流の並べ方」）。
        let mark = fg.next_reg;
        let base = fg.alloc_block(count(args.len())?);
        self.vals(fg, args, base, future)?;
        for (i, r) in params.iter().enumerate() {
            fg.emit(
                Instr::abc(
                    Opcode::Move,
                    r16(*r),
                    r16(base.saturating_add(count(i)?)),
                    0,
                ),
                Some(origin),
            );
        }
        fg.release(mark);
        let pc = fg.jump(Opcode::Jmp, 0, origin);
        let join = fg
            .joins
            .get_mut(&label)
            .ok_or_else(|| internal("jump to unknown join"))?;
        merge_reuse(&mut join.reuse, &fg.reuse);
        if let Some(target) = join.target {
            fg.patch(pc, target)?;
        } else {
            join.pending.push(pc);
        }
        Ok(())
    }
}

impl<'p> Gen<'p> {
    fn operand(
        &mut self,
        fg: &mut FnGen<'p>,
        v: &'p LowVal,
        future: &HashSet<Key>,
    ) -> CgResult<u32> {
        if let Some(r) = fg.reg_of(v) {
            return Ok(r);
        }
        let r = fg.alloc();
        self.val(fg, v, r, future)?;
        Ok(r)
    }
    fn key_operand(&mut self, fg: &mut FnGen<'p>, key: Key, origin: Span) -> CgResult<u32> {
        if let Some(Loc::Reg(r)) = fg.env.get(&key) {
            return Ok(*r);
        }
        let r = fg.alloc();
        self.key_into(fg, key, r, origin)?;
        Ok(r)
    }
    fn key_into(&mut self, fg: &mut FnGen<'p>, key: Key, dst: u32, origin: Span) -> CgResult<()> {
        if let Key::ImplParam(i) = key
            && fg.method_body
        {
            fg.emit(
                Instr::abc(Opcode::GetDict, r16(dst), r16(i), 0),
                Some(origin),
            );
            return Ok(());
        }
        match fg.lookup(key)? {
            Loc::Reg(r) => {
                if r != dst {
                    fg.emit(Instr::abc(Opcode::Move, r16(dst), r16(r), 0), Some(origin));
                }
            }
            Loc::Cap(i) => {
                fg.emit(
                    Instr::abc(Opcode::GetCap, r16(dst), r16(i), 0),
                    Some(origin),
                );
            }
        }
        Ok(())
    }
    fn vals(
        &mut self,
        fg: &mut FnGen<'p>,
        values: &'p [LowVal],
        base: u32,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        // まだ移していない引数の読み出しを数える。長いリストでも同じ接尾列を何度も走査しない。
        let keys: Vec<Vec<Key>> = values
            .iter()
            .map(|v| free_keys(Node::Val(v), Vec::new()))
            .collect();
        let mut reads: HashMap<Key, usize> = HashMap::new();
        for ks in &keys {
            for k in ks {
                let n = reads.entry(*k).or_default();
                *n = n.saturating_add(1);
            }
        }
        for (i, v) in values.iter().enumerate() {
            if let Some(ks) = keys.get(i) {
                for k in ks {
                    if let Some(n) = reads.get_mut(k) {
                        *n = n.saturating_sub(1);
                        if *n == 0 {
                            reads.remove(k);
                        }
                    }
                }
            }
            let mut next = future.clone();
            next.extend(reads.keys().copied());
            self.val(fg, v, base.saturating_add(count(i)?), &next)?;
        }
        Ok(())
    }
    fn val(
        &mut self,
        fg: &mut FnGen<'p>,
        v: &'p LowVal,
        dst: u32,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        match &v.kind {
            ValKind::Var(x) => self.key_into(fg, Key::Var(*x), dst, v.origin),
            ValKind::Const(c) => {
                let k = self.constant(tables::scalar(c))?;
                fg.load(dst, k, Some(v.origin))
            }
            ValKind::ConstRef(binding) => {
                let k = self.const_ref(*binding)?;
                fg.load(dst, k, Some(v.origin))
            }
            ValKind::TopFn { def, .. } => {
                let index = self
                    .def_protos
                    .get(def)
                    .copied()
                    .ok_or_else(|| internal("unknown top-level function"))?;
                let k = self.constant(ConstDesc::Func(index))?;
                fg.load(dst, k, Some(v.origin))
            }
            ValKind::Builtin { id, targs, info } => {
                let index = self.builtin_value(*id, targs, *info, fg.def)?;
                let k = self.constant(ConstDesc::Func(index))?;
                fg.load(dst, k, Some(v.origin))
            }
            ValKind::Op { op, .. } => {
                let index = self.op_value(*op, fg.def)?;
                let k = self.constant(ConstDesc::Func(index))?;
                fg.load(dst, k, Some(v.origin))
            }
            ValKind::Lambda(l) => {
                let mark = fg.next_reg;
                let params: Vec<Key> = l.params.iter().map(|p| Key::Var(p.id)).collect();
                let index = self.body_proto(
                    fg,
                    &l.body,
                    &params,
                    (
                        true,
                        text::LAMBDA.to_string(),
                        ProtoOrigin::UserLambda,
                        l.span,
                    ),
                )?;
                fg.emit(
                    Instr::abx(Opcode::Closure, r16(dst), index.0),
                    Some(v.origin),
                );
                fg.release(mark);
                Ok(())
            }
            ValKind::Ctor { .. } => self.ctor_val(fg, v, dst, future),
            ValKind::List(items) => {
                let mark = fg.next_reg;
                let n = count(items.len())?;
                let base = fg.alloc_block(n);
                self.vals(fg, items, base, future)?;
                fg.emit(
                    Instr::abc(Opcode::List, r16(dst), r16(base), r16(n)),
                    Some(v.origin),
                );
                fg.release(mark);
                Ok(())
            }
        }
    }
    fn ctor_val(
        &mut self,
        fg: &mut FnGen<'p>,
        v: &'p LowVal,
        dst: u32,
        future: &HashSet<Key>,
    ) -> CgResult<()> {
        let ValKind::Ctor { adt, tag, args, .. } = &v.kind else {
            return Err(internal("expected constructor"));
        };
        let ctor = self.ctor(*adt, *tag)?;
        if args.is_empty() {
            let k = self.constant(ConstDesc::Ctor {
                ctor,
                args: Vec::new(),
            })?;
            return fg.load(dst, k, Some(v.origin));
        }
        let mark = fg.next_reg;
        let n = count(args.len())?;
        let base = fg.alloc_block(n);
        let mut reads = HashSet::new();
        for a in args {
            reads.extend(free_keys(Node::Val(a), Vec::new()));
        }
        self.vals(fg, args, base, &with_reads(future, Node::Val(v)))?;
        let candidate = fg.reuse.iter_mut().rev().find(|candidate| {
            !candidate.used
                && !candidate.captured
                && candidate.arity == args.len()
                && candidate.aliases.is_disjoint(future)
                && candidate.aliases.is_disjoint(&reads)
                && !(base..base.saturating_add(n)).contains(&candidate.reg)
        });
        if let Some(candidate) = candidate {
            candidate.used = true;
            let r = candidate.reg;
            fg.emit(
                Instr::abc(Opcode::ConR, r16(r), r16(ctor.0), r16(base)),
                Some(v.origin),
            );
            if dst != r {
                fg.emit(
                    Instr::abc(Opcode::Move, r16(dst), r16(r), 0),
                    Some(v.origin),
                );
            }
        } else {
            fg.emit(
                Instr::abc(Opcode::Con, r16(dst), r16(ctor.0), r16(base)),
                Some(v.origin),
            );
        }
        fg.release(mark);
        Ok(())
    }
    fn dicts(&mut self, fg: &mut FnGen<'p>, values: &[DictVal], base: u32) -> CgResult<()> {
        for (i, d) in values.iter().enumerate() {
            self.dict(fg, d, base.saturating_add(count(i)?))?;
        }
        Ok(())
    }
    fn dict(&mut self, fg: &mut FnGen<'p>, d: &DictVal, dst: u32) -> CgResult<()> {
        match &d.kind {
            DictKind::Param(x) => self.key_into(fg, Key::Var(*x), dst, d.origin),
            DictKind::ImplParam(i) => self.key_into(fg, Key::ImplParam(*i), dst, d.origin),
            DictKind::Super { of, index } => {
                let mark = fg.next_reg;
                let r = fg.alloc();
                self.dict(fg, of, r)?;
                fg.emit(
                    Instr::abc(Opcode::Super, r16(dst), r16(r), r16(*index)),
                    Some(d.origin),
                );
                fg.release(mark);
                Ok(())
            }
            DictKind::Impl {
                impl_decl, args, ..
            } => {
                let index = self.implementation(*impl_decl)?;
                if args.is_empty() {
                    let k = self.constant(ConstDesc::Dict(index))?;
                    fg.load(dst, k, Some(d.origin))
                } else {
                    let mark = fg.next_reg;
                    let base = fg.alloc_block(count(args.len())?);
                    self.dicts(fg, args, base)?;
                    fg.emit(
                        Instr::abc(Opcode::Dict, r16(dst), r16(index.0), r16(base)),
                        Some(d.origin),
                    );
                    fg.release(mark);
                    Ok(())
                }
            }
        }
    }
    fn body_proto(
        &mut self,
        fg: &mut FnGen<'p>,
        body: &'p LComp,
        params: &[Key],
        meta: (bool, String, ProtoOrigin, Span),
    ) -> CgResult<ProtoIdx> {
        let (boundary, name, user_origin, span) = meta;
        let free = free_keys(Node::Comp(body), params.to_vec());
        let mut inner = Box::new(FnGen::new(fg.def, boundary));
        inner.method_body = false;
        for key in params {
            let r = inner.alloc();
            inner.bind(*key, Loc::Reg(r))?;
        }
        for (i, key) in free.iter().enumerate() {
            let loc = if let Key::ImplParam(_) = key
                && fg.method_body
            {
                Loc::Reg(self.key_operand(fg, *key, span)?)
            } else {
                fg.lookup(*key)?
            };
            inner.captures.push(match loc {
                Loc::Reg(r) => CaptureSource::Reg(r16(r)),
                Loc::Cap(i) => CaptureSource::Capture(r16(i)),
            });
            inner.bind(*key, Loc::Cap(count(i)?))?;
            for candidate in &mut fg.reuse {
                if candidate.aliases.contains(key) {
                    candidate.captured = true;
                }
            }
        }
        let index = self.reserve_proto()?;
        let origin = if fg.def.origin == DefOrigin::User {
            user_origin
        } else {
            ProtoOrigin::StdlibHelper
        };
        self.pending.push_back(PendingBody {
            index,
            body,
            inner,
            name,
            origin,
            span,
            params: count(params.len())?,
        });
        Ok(index)
    }
    pub(super) fn drain_bodies(&mut self) -> CgResult<()> {
        while let Some(PendingBody {
            index,
            body,
            mut inner,
            name,
            origin,
            span,
            params,
        }) = self.pending.pop_front()
        {
            self.comp(&mut inner, body, Target::Tail, &HashSet::new())?;
            let proto = self.finish(*inner, name, origin, Some(span), params)?;
            self.set_proto(index, proto)?;
        }
        Ok(())
    }
    fn handle(
        &mut self,
        fg: &mut FnGen<'p>,
        h: &'p Handle<LComp>,
        target: Target,
        origin: Span,
    ) -> CgResult<()> {
        let mark = fg.next_reg;
        let base = fg.alloc_block(count(h.clauses.len().saturating_add(1))?);
        let index = self.body_proto(
            fg,
            &h.body,
            &[],
            (
                false,
                text::HANDLE.to_string(),
                ProtoOrigin::UserHandleBody,
                origin,
            ),
        )?;
        fg.emit(
            Instr::abx(Opcode::Closure, r16(base), index.0),
            Some(origin),
        );
        let mut clauses = Vec::new();
        for (i, cl) in h.clauses.iter().enumerate() {
            let op = self.operation(cl.op)?;
            let info = self
                .out
                .op(op)
                .ok_or_else(|| internal("missing operation"))?;
            let name = format!("{}{}>", text::CASE_PREFIX, info.name);
            let params: Vec<Key> = cl
                .params
                .iter()
                .map(|p| Key::Var(p.id))
                .chain(std::iter::once(Key::Var(cl.cont.id)))
                .collect();
            let index = self.body_proto(
                fg,
                &cl.body,
                &params,
                (false, name, ProtoOrigin::UserHandleClause, cl.span),
            )?;
            fg.emit(
                Instr::abx(
                    Opcode::Closure,
                    r16(base.saturating_add(1).saturating_add(count(i)?)),
                    index.0,
                ),
                Some(cl.span),
            );
            clauses.push(ClauseDesc {
                op,
                tail_resumptive: cl.tail_resumptive,
            });
        }
        let index = HandlerIdx(count(self.out.handlers.len())?);
        self.out.handlers.push(HandlerDesc { clauses });
        let local = count(fg.handlers.len())?;
        fg.handlers.push(index);
        let dst = fg.result(target);
        fg.emit(
            Instr::abc(Opcode::Handle, r16(dst), r16(base), r16(local)),
            Some(origin),
        );
        fg.returned(target, dst, Some(origin));
        fg.release(mark);
        Ok(())
    }
    fn builtin_value(
        &mut self,
        id: BuiltinId,
        types: &TypeArgs,
        info: BuiltinInfo,
        def: &'p LowerDef,
    ) -> CgResult<ProtoIdx> {
        if let Some(index) = self.builtin_protos.get(&id) {
            return Ok(*index);
        }
        let decl = crate::builtins::builtin_decl(id).ok_or_else(|| internal("unknown builtin"))?;
        let index = self.reserve_proto()?;
        let mut fg = FnGen::new(def, true);
        let n = u32::from(decl.arity);
        fg.alloc_block(n.max(1));
        if let Some(intrinsic) = info.intrinsic {
            let args: Vec<u32> = (0..n).collect();
            self.emit_plan(&mut fg, plan(intrinsic, types)?, &args, 0, None)?;
        } else {
            let b = self.builtin(id, info.op)?;
            fg.emit(
                Instr::abc(
                    if info.class == Capability::Io {
                        Opcode::Io
                    } else {
                        Opcode::Prim
                    },
                    0,
                    r16(b.0),
                    0,
                ),
                None,
            );
        }
        fg.emit(Instr::abc(Opcode::Return, 0, 0, 0), None);
        let proto = self.finish(
            fg,
            decl.name.to_string(),
            ProtoOrigin::BuiltinValue,
            None,
            n,
        )?;
        self.set_proto(index, proto)?;
        self.builtin_protos.insert(id, index);
        Ok(index)
    }
    fn op_value(&mut self, binding: BindingId, def: &'p LowerDef) -> CgResult<ProtoIdx> {
        if let Some(index) = self.op_protos.get(&binding) {
            return Ok(*index);
        }
        let op = self.operation(binding)?;
        let info = self
            .out
            .op(op)
            .ok_or_else(|| internal("missing operation"))?;
        let name = info.name.clone();
        let n = u32::from(info.arity);
        let index = self.reserve_proto()?;
        let mut fg = FnGen::new(def, true);
        fg.alloc_block(n.max(1));
        fg.emit(Instr::abc(Opcode::Perform, 0, r16(op.0), 0), None);
        fg.emit(Instr::abc(Opcode::Return, 0, 0, 0), None);
        let proto = self.finish(fg, name, ProtoOrigin::BuiltinValue, None, n)?;
        self.set_proto(index, proto)?;
        self.op_protos.insert(binding, index);
        Ok(index)
    }
}

fn const_ty(c: &Const) -> Ty {
    use BuiltinTypeId as T;
    Ty::Con(
        TyCon::Builtin(match c {
            Const::Int(_) => T::INTEGER,
            Const::Float(_) => T::FLOAT,
            Const::Str(_) => T::STRING,
            Const::Char(_) => T::CHARACTER,
            Const::Bool(_) => T::BOOLEAN,
            Const::Unit => T::UNIT,
            Const::Byte(_) => T::BYTE,
            Const::Decimal(_) => T::DECIMAL,
        }),
        Vec::new(),
    )
}

mod text {
    pub const LAMBDA: &str = "<lambda>";
    pub const LAZY: &str = "<lazy>";
    pub const HANDLE: &str = "<handle>";
    pub const CASE_PREFIX: &str = "<case ";
}
