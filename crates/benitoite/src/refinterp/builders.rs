//! 構築器の独立した不変内容。VM の Host バッファを呼ばない（設計書 02-08「参照インタプリタ」）。

use super::value::Value;
use crate::ir::core_ir::BuilderKind;
use crate::resolve::builders::BuilderOp;
use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop};
use std::rc::Rc;

pub(super) struct Contents(Value);

impl Contents {
    pub(super) fn new(kind: &BuilderKind) -> Self {
        Self(match kind {
            BuilderKind::String => Value::Str(Rc::from("")),
            BuilderKind::Bytes => Value::Bytes(Rc::from([])),
            BuilderKind::List(_) => Value::list(vec![]),
        })
    }

    pub(super) fn apply(
        &mut self,
        kind: &BuilderKind,
        op: BuilderOp,
        args: Vec<Value>,
    ) -> Result<Value, Stop> {
        let arity = usize::from(matches!(op, BuilderOp::Append | BuilderOp::AppendAll));
        if args.len() != arity {
            return Err(invalid());
        }
        let length = match (&self.0, kind) {
            (Value::Str(s), BuilderKind::String) => s.len(),
            (Value::Bytes(b), BuilderKind::Bytes) => b.len(),
            (Value::List(v), BuilderKind::List(_)) => v.items.len(),
            _ => return Err(invalid()),
        };
        if op == BuilderOp::Copy {
            return Ok(self.0.clone());
        }
        if op == BuilderOp::Length {
            return Ok(Value::Int(i64::try_from(length).map_err(|_| invalid())?));
        }
        let arg = args.into_iter().next().ok_or_else(invalid)?;
        // 先に全入力を確認して長さを検査し、成功後に新しい不変内容へ置き換える。
        // copy は以前の Rc を持ち続けるため、追記の影響を受けない。
        let next = match (&self.0, kind, op, arg) {
            (Value::Str(old), BuilderKind::String, BuilderOp::Append, Value::Str(text)) => {
                checked(kind, op, length, Some(text.len()))?;
                Value::Str(Rc::from(format!("{old}{text}")))
            }
            (Value::Str(old), BuilderKind::String, BuilderOp::AppendAll, Value::List(texts)) => {
                let mut extra = Some(0_usize);
                for item in &texts.items {
                    let Value::Str(text) = item else {
                        return Err(invalid());
                    };
                    extra = extra.and_then(|n| n.checked_add(text.len()));
                }
                checked(kind, op, length, extra)?;
                let mut next = old.to_string();
                for item in &texts.items {
                    if let Value::Str(text) = item {
                        next.push_str(text);
                    }
                }
                Value::Str(Rc::from(next))
            }
            (Value::Bytes(old), BuilderKind::Bytes, BuilderOp::Append, Value::Byte(byte)) => {
                checked(kind, op, length, Some(1))?;
                let mut next = old.to_vec();
                next.push(byte);
                Value::Bytes(Rc::from(next))
            }
            (Value::Bytes(old), BuilderKind::Bytes, BuilderOp::AppendAll, Value::Bytes(bytes)) => {
                checked(kind, op, length, Some(bytes.len()))?;
                let mut next = old.to_vec();
                next.extend_from_slice(&bytes);
                Value::Bytes(Rc::from(next))
            }
            (Value::List(old), BuilderKind::List(_), BuilderOp::Append, value) => {
                checked(kind, op, length, Some(1))?;
                let mut next = old.items.clone();
                next.push(value);
                Value::list(next)
            }
            (Value::List(old), BuilderKind::List(_), BuilderOp::AppendAll, Value::List(values)) => {
                checked(kind, op, length, Some(values.items.len()))?;
                let mut next = old.items.clone();
                next.extend(values.items.iter().cloned());
                Value::list(next)
            }
            _ => return Err(invalid()),
        };
        self.0 = next;
        Ok(Value::Unit)
    }
}

fn checked(
    kind: &BuilderKind,
    op: BuilderOp,
    old: usize,
    extra: Option<usize>,
) -> Result<(), Stop> {
    let (max, unit, function) = match (kind, op) {
        (BuilderKind::String, BuilderOp::Append) => {
            (MAX_STRING_BYTES, SizeUnit::Bytes, "StringBuilder.append")
        }
        (BuilderKind::String, _) => (MAX_STRING_BYTES, SizeUnit::Bytes, "StringBuilder.appendAll"),
        (BuilderKind::Bytes, BuilderOp::Append) => {
            (MAX_STRING_BYTES, SizeUnit::Bytes, "BytesBuilder.append")
        }
        (BuilderKind::Bytes, _) => (MAX_STRING_BYTES, SizeUnit::Bytes, "BytesBuilder.appendAll"),
        (BuilderKind::List(_), BuilderOp::Append) => {
            (MAX_LIST_LEN, SizeUnit::Elements, "ListBuilder.append")
        }
        (BuilderKind::List(_), _) => (MAX_LIST_LEN, SizeUnit::Elements, "ListBuilder.appendAll"),
    };
    let next = extra
        .and_then(|n| old.checked_add(n))
        .and_then(|n| u64::try_from(n).ok());
    if next.is_none_or(|n| n > max) {
        return Err(Stop::Resource(ResourceError::ValueTooLarge {
            function,
            size: next.unwrap_or(u64::MAX),
            limit: max,
            unit,
        }));
    }
    Ok(())
}

fn invalid() -> Stop {
    Stop::Internal("invalid reference builder operation".into())
}
