//! 境界の型を具体化し、照合とエフェクトの検査で同じ欄と予算を辿る（設計書 03-10「型の対応」）。

use crate::base::BindingId;
use crate::resolve::ResolveOutput;
use crate::types::{AdtTable, Ty, TyCon};
use std::collections::BTreeSet;
use std::rc::Rc;

pub(super) const MAX_DEPTH: u32 = 100;
pub(super) const MAX_NODES: usize = 100_000;

/// 木を複製せず、型パラメータの参照先に元の環境を残す。
#[derive(Clone)]
struct Concrete<'a> {
    ty: &'a Ty,
    args: Rc<Vec<Concrete<'a>>>,
}

impl<'a> Concrete<'a> {
    fn resolved(mut self) -> Self {
        while let Ty::Param(index) = self.ty {
            let Some(arg) = usize::try_from(*index)
                .ok()
                .and_then(|index| self.args.get(index))
            else {
                break;
            };
            self = arg.clone();
        }
        self
    }

    fn child(&self, ty: &'a Ty) -> Self {
        Self {
            ty,
            args: Rc::clone(&self.args),
        }
    }
}

/// 入口から数えた予算切れと、宣言の依存の循環を区別する。
pub(crate) enum ExpansionError<'a> {
    Budget,
    Recursive(&'a Ty, BindingId),
}

/// 行きに型の種類、帰りに具体化した子の数を通知する。
pub(crate) enum Visit {
    Enter,
    Leave(usize),
    Result { ok: bool, err: bool },
}

/// 走査自身の制限と、利用側の型の拒否を分ける。
pub(crate) enum WalkError<'a, E> {
    Expansion(ExpansionError<'a>),
    Visitor(E),
}

enum Pending<'a> {
    Enter(Concrete<'a>, u32),
    Leave(&'a Ty, Visit),
}

/// 使う欄だけを展開し、未使用の型引数には走査も予算の消費も行わない。
pub(crate) fn walk<'a, E>(
    ty: &'a Ty,
    resolved: &ResolveOutput,
    adts: &'a AdtTable,
    total: &mut usize,
    mut visit: impl FnMut(&'a Ty, Visit) -> Result<(), E>,
) -> Result<(), WalkError<'a, E>> {
    let mut remaining = MAX_NODES;
    let mut checked = BTreeSet::new();
    let mut pending = vec![Pending::Enter(
        Concrete {
            ty,
            args: Rc::new(Vec::new()),
        },
        1,
    )];
    while let Some(next) = pending.pop() {
        let (concrete, depth) = match next {
            Pending::Leave(ty, event) => {
                visit(ty, event).map_err(WalkError::Visitor)?;
                continue;
            }
            Pending::Enter(concrete, depth) => (concrete.resolved(), depth),
        };
        if depth > MAX_DEPTH || remaining == 0 || *total == 0 {
            return Err(WalkError::Expansion(ExpansionError::Budget));
        }
        remaining = remaining.saturating_sub(1);
        *total = total.saturating_sub(1);
        visit(concrete.ty, Visit::Enter).map_err(WalkError::Visitor)?;
        let mut result = None;
        let children = match concrete.ty {
            Ty::Con(TyCon::Adt(id), args, _) => {
                // パラメータを葉とする宣言の依存を先に検査するため、有限の同型の入れ子を拒まない。
                check_dependencies(*id, adts, &mut checked, total).map_err(|error| {
                    WalkError::Expansion(match error {
                        DependencyError::Budget => ExpansionError::Budget,
                        DependencyError::Recursive(id) => {
                            ExpansionError::Recursive(concrete.ty, id)
                        }
                    })
                })?;
                if Some(*id) == resolved.stdlib("Benitoite.Result.Result") {
                    let sides: Vec<_> = args
                        .iter()
                        .map(|ty| concrete.child(ty).resolved())
                        .collect();
                    let present = |index: usize| {
                        sides
                            .get(index)
                            .is_some_and(|child| !super::types::is_unit(child.ty))
                    };
                    result = Some(Visit::Result {
                        ok: present(0),
                        err: present(1),
                    });
                    sides
                        .into_iter()
                        .filter(|child| !super::types::is_unit(child.ty))
                        .collect::<Vec<_>>()
                } else if let Some(def) = adts.get(*id) {
                    let args = Rc::new(args.iter().map(|ty| concrete.child(ty)).collect());
                    def.ctors
                        .iter()
                        .flat_map(|ctor| &ctor.fields)
                        .map(|ty| Concrete {
                            ty,
                            args: Rc::clone(&args),
                        })
                        .collect()
                } else {
                    Vec::new()
                }
            }
            Ty::Con(_, args, _) | Ty::App(_, args) => {
                args.iter().map(|ty| concrete.child(ty)).collect()
            }
            Ty::Fn(f) => f
                .params
                .iter()
                .chain([&f.ret])
                .map(|ty| concrete.child(ty))
                .collect(),
            Ty::Param(_) | Ty::Rigid { .. } => Vec::new(),
        };
        pending.push(Pending::Leave(
            concrete.ty,
            result.unwrap_or(Visit::Leave(children.len())),
        ));
        pending.extend(
            children
                .into_iter()
                .rev()
                .map(|child| Pending::Enter(child, depth.saturating_add(1))),
        );
    }
    Ok(())
}

enum DependencyError {
    Budget,
    Recursive(BindingId),
}

fn check_dependencies(
    id: BindingId,
    adts: &AdtTable,
    checked: &mut BTreeSet<BindingId>,
    total: &mut usize,
) -> Result<(), DependencyError> {
    enum Work<'a> {
        Declaration(BindingId),
        Type(&'a Ty),
        Leave(BindingId),
    }
    let mut visiting = BTreeSet::new();
    let mut work = vec![Work::Declaration(id)];
    while let Some(next) = work.pop() {
        if let Work::Declaration(id) = &next
            && checked.contains(id)
        {
            continue;
        }
        // 根ごとの展開量とは別に、繰り返す依存の走査も検査全体の予算で制限する。
        if !matches!(&next, Work::Leave(_)) {
            if *total == 0 {
                return Err(DependencyError::Budget);
            }
            *total = total.saturating_sub(1);
        }
        match next {
            Work::Leave(id) => {
                visiting.remove(&id);
                checked.insert(id);
            }
            Work::Declaration(id) => {
                if visiting.contains(&id) {
                    return Err(DependencyError::Recursive(id));
                }
                if let Some(def) = adts.get(id) {
                    visiting.insert(id);
                    work.push(Work::Leave(id));
                    work.extend(
                        def.ctors
                            .iter()
                            .flat_map(|ctor| &ctor.fields)
                            .rev()
                            .map(Work::Type),
                    );
                }
            }
            Work::Type(ty) => {
                let args = match ty {
                    Ty::Con(con, args, _) => {
                        if let TyCon::Adt(id) = con {
                            work.push(Work::Declaration(*id));
                        }
                        args.as_slice()
                    }
                    Ty::App(_, args) => args,
                    Ty::Fn(f) => {
                        work.extend(f.params.iter().chain([&f.ret]).map(Work::Type));
                        continue;
                    }
                    Ty::Param(_) | Ty::Rigid { .. } => continue,
                };
                work.extend(args.iter().rev().map(Work::Type));
            }
        }
    }
    Ok(())
}
