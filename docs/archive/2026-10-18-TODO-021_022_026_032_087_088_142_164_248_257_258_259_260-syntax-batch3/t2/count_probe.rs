//! 一時的な展開物だけへ挿入する節数の計数。処理系の恒久的なテストではない。
use super::*;
use std::cell::Cell;

thread_local! {
    static ZONKS: Cell<usize> = const { Cell::new(0) };
    static NODES: Cell<usize> = const { Cell::new(0) };
    static FINALIZED: Cell<usize> = const { Cell::new(0) };
}

pub(super) fn zonk() {
    ZONKS.set(ZONKS.get() + 1);
}
pub(super) fn node() {
    NODES.set(NODES.get() + 1);
}
pub(super) fn finalized() {
    FINALIZED.set(FINALIZED.get() + 1);
}

fn report(name: &str, solver: &Solver, ty: &ITy) {
    ZONKS.set(0);
    NODES.set(0);
    FINALIZED.set(0);
    let effect = solver.finalize_effect(&IEffect {
        failures: vec![ty.clone()],
        ..IEffect::default()
    });
    println!(
        "T2\t{name}\t{}\t{}\t{}\t{effect:?}",
        ZONKS.get(), NODES.get(), FINALIZED.get(),
    );
}

#[test]
fn counts() {
    let mut solver = Solver::default();
    let bound = solver.fresh_ty();
    // 変数・型構成子・契約名を実際の推論状態から解決する。
    solver.vars[0].binding = Some(ITy::Con(TyCon::Builtin(B::STRING), vec![]));
    let constructor = solver.fresh_head();
    let IHead::Var(head) = constructor else { panic!("head") };
    solver.heads.insert(head.0, TyHead::Con(TyCon::Builtin(B::LIST)));
    let contract = solver.fresh_contract();
    solver.contracts[0].binding = Some(IContract::Known(vec!["value".into()]));
    let row = solver.fresh_effect();
    solver.effs[0].set.insert_var(EffVar(3));
    solver.effs[0].failures.push(bound.clone());
    for depth in [8, 16, 32, 64] {
        let mut payload = bound.clone();
        for _ in 0..depth {
            payload = ITy::Con(TyCon::Adt(crate::base::BindingId(123)), vec![payload]);
        }
        report(&format!("chain-{depth}"), &solver, &payload);
        let mut latent = row.clone();
        latent.failures.push(payload.clone());
        latent.fixed.insert_failure(Ty::Param(4));
        let function = ITy::Fn(Box::new(IFnTy {
            contract: contract.clone(),
            params: vec![ITy::App(constructor, vec![payload.clone()])],
            ret: payload,
            effect: latent,
        }));
        report(&format!("function-{depth}"), &solver, &function);
    }
    let unknown = solver.fresh_ty();
    let unknown_head = solver.fresh_head();
    for (name, ty) in [
        ("unknown", unknown),
        ("error", ITy::Error),
        ("parameter", ITy::Param(2)),
        ("rigid", ITy::Rigid { clause: NodeId(17), index: 2 }),
        ("unknown-head", ITy::App(unknown_head, vec![bound.clone()])),
        ("parameter-head", ITy::App(IHead::Param(2), vec![bound])),
        ("unknown-contract", ITy::Fn(Box::new(IFnTy {
            contract: solver.fresh_contract(),
            params: vec![],
            ret: ITy::Error,
            effect: IEffect::default(),
        }))),
    ] {
        report(name, &solver, &ty);
    }
}
