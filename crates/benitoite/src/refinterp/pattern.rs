//! 元の行の順に使うパターンの照合（設計書 01-05「match の意味」、02-06「パターンの拡張」）。
//! パターンだけを構文の深さで再帰し、リストの値は平坦な並びで走査する。
use super::value::{Value, values_equal};
use crate::ir::core_ir::{Const, CorePat, VarId};
use crate::runtime::Stop;
use std::rc::Rc;

pub(super) fn constant(c: &Const) -> Value {
    match c {
        Const::Int(n) => Value::Int(*n),
        Const::Float(n) => Value::Float(*n),
        Const::Str(s) => Value::Str(Rc::from(s.as_str())),
        Const::Char(c) => Value::Char(*c),
        Const::Bool(b) => Value::Bool(*b),
        Const::Unit => Value::Unit,
        Const::Byte(b) => Value::Byte(*b),
        Const::Decimal(d) => Value::Decimal(*d),
    }
}
pub(super) fn matches(
    p: &CorePat,
    v: &Value,
    binds: &mut Vec<(VarId, Value)>,
) -> Result<bool, Stop> {
    let fault = || Stop::Internal("pattern and value kinds differ".into());
    match p {
        CorePat::Wild => Ok(true),
        CorePat::Var(id) => {
            binds.push((*id, v.clone()));
            Ok(true)
        }
        CorePat::Const(c) => values_equal(&constant(c), v),
        CorePat::Range { lo, hi } => match (lo, hi, v) {
            (Const::Int(lo), Const::Int(hi), Value::Int(n)) => Ok(lo <= n && n <= hi),
            (Const::Char(lo), Const::Char(hi), Value::Char(n)) => Ok(lo <= n && n <= hi),
            _ => Err(fault()),
        },
        CorePat::Ctor { tag, args, .. } => {
            let Value::Ctor {
                tag: actual,
                args: values,
            } = v
            else {
                return Err(fault());
            };
            if tag != actual {
                return Ok(false);
            }
            if args.len() != values.items.len() {
                return Err(fault());
            }
            for (p, v) in args.iter().zip(&values.items) {
                if !matches(p, v, binds)? {
                    return Ok(false);
                }
            }
            Ok(true)
        }
        CorePat::List {
            before,
            rest,
            after,
        } => {
            let Value::List(values) = v else {
                return Err(fault());
            };
            let required = before.len().checked_add(after.len()).ok_or_else(fault)?;
            let len = values.items.len();
            if len < required || (rest.is_none() && len != required) {
                return Ok(false);
            }
            let suffix = len.checked_sub(after.len()).ok_or_else(fault)?;
            for (p, v) in before.iter().zip(&values.items) {
                if !matches(p, v, binds)? {
                    return Ok(false);
                }
            }
            for (p, v) in after
                .iter()
                .zip(values.items.get(suffix..).ok_or_else(fault)?)
            {
                if !matches(p, v, binds)? {
                    return Ok(false);
                }
            }
            if let Some(id) = rest.as_ref().and_then(|r| r.var) {
                binds.push((
                    id,
                    Value::list(
                        values
                            .items
                            .get(before.len()..suffix)
                            .ok_or_else(fault)?
                            .to_vec(),
                    ),
                ));
            }
            Ok(true)
        }
    }
}
