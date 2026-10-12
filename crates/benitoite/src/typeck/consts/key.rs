//! 定数の鍵を診断に示す表記（設計書 02-05「定数の検査と評価」）。
use crate::base::literal::{quoted, text};
use crate::types::{AdtTable, ConstValue, FieldInfo};

const MAX_KEY_BYTES: usize = 4096;

enum KeyWork<'a> {
    Value(&'a ConstValue),
    Text(&'a str),
    Values {
        rest: std::slice::Iter<'a, ConstValue>,
        fields: Option<std::slice::Iter<'a, FieldInfo>>,
        first: bool,
    },
    Entries(std::slice::Iter<'a, (ConstValue, ConstValue)>, bool),
}

/// 鍵を `Show.show` の形で示す。構造の走査と出力を上限で止め、深い値や長い値でも
/// 診断の生成が Rust のスタックや値全体の大きさに依存しないようにする（設計書 02-05「定数の検査と評価」）。
pub(super) fn const_key(adts: &AdtTable, value: &ConstValue) -> String {
    use ConstValue as V;
    let mut out = String::new();
    let mut stack = vec![KeyWork::Value(value)];
    while out.len() <= MAX_KEY_BYTES {
        let Some(work) = stack.pop() else {
            break;
        };
        match work {
            KeyWork::Text(s) => key_append(&mut out, s),
            KeyWork::Values {
                mut rest,
                mut fields,
                first,
            } => {
                if let Some(value) = rest.next() {
                    if !first {
                        key_append(&mut out, text::SEPARATOR);
                    }
                    if let Some(field) = fields.as_mut().and_then(Iterator::next) {
                        key_append(&mut out, &field.name);
                        key_append(&mut out, text::FIELD_SEPARATOR);
                    }
                    stack.push(KeyWork::Values {
                        rest,
                        fields,
                        first: false,
                    });
                    stack.push(KeyWork::Value(value));
                }
            }
            KeyWork::Entries(mut rest, first) => {
                if let Some((key, value)) = rest.next() {
                    if !first {
                        key_append(&mut out, text::SEPARATOR);
                    }
                    stack.push(KeyWork::Entries(rest, false));
                    stack.push(KeyWork::Text(text::ARGS_CLOSE));
                    stack.push(KeyWork::Value(value));
                    stack.push(KeyWork::Text(text::SEPARATOR));
                    stack.push(KeyWork::Value(key));
                    stack.push(KeyWork::Text(text::PAIR_OPEN));
                }
            }
            KeyWork::Value(v) => match v {
                V::Integer(n) => key_append(&mut out, &n.to_string()),
                V::Byte(n) => key_append(&mut out, &n.to_string()),
                V::Float(n) => key_append(&mut out, &crate::base::prim::float_to_text(*n)),
                V::Decimal(n) => key_append(&mut out, &n.to_text()),
                V::String(s) => {
                    let budget = MAX_KEY_BYTES.saturating_sub(out.len()).saturating_add(1);
                    key_append(&mut out, &quoted(s.chars().take(budget), '"'));
                }
                V::Character(c) => key_append(&mut out, &quoted([*c].into_iter(), '\'')),
                V::Boolean(b) => key_append(&mut out, if *b { text::TRUE } else { text::FALSE }),
                V::Unit => key_append(&mut out, text::UNIT),
                V::Ctor { adt, tag, args } => {
                    let Some(def) = adts.get(*adt) else {
                        key_append(
                            &mut out,
                            &text::UNKNOWN_CONSTRUCTOR.replace("{tag}", &tag.to_string()),
                        );
                        continue;
                    };
                    let Some(ctor) = def.ctors.iter().find(|c| c.tag == *tag) else {
                        key_append(
                            &mut out,
                            &text::UNKNOWN_CONSTRUCTOR.replace("{tag}", &tag.to_string()),
                        );
                        continue;
                    };
                    if def.record.is_some() {
                        key_append(&mut out, &def.name);
                    } else {
                        if def.ctors.len() != 1 || ctor.name != def.name {
                            key_append(&mut out, &def.name);
                            key_append(&mut out, text::QUALIFIER);
                        }
                        key_append(&mut out, &ctor.name);
                    }
                    if !args.is_empty() || def.record.is_some() {
                        key_append(&mut out, text::ARGS_OPEN);
                        stack.push(KeyWork::Text(text::ARGS_CLOSE));
                        stack.push(KeyWork::Values {
                            rest: args.iter(),
                            fields: def.record.as_ref().map(|f| f.iter()),
                            first: true,
                        });
                    }
                }
                V::List(values) | V::Set(values) => {
                    let set = matches!(v, V::Set(_));
                    key_append(&mut out, if set { text::SET_OPEN } else { text::LIST_OPEN });
                    stack.push(KeyWork::Text(if set {
                        text::FROM_LIST_CLOSE
                    } else {
                        text::LIST_CLOSE
                    }));
                    stack.push(KeyWork::Values {
                        rest: values.iter(),
                        fields: None,
                        first: true,
                    });
                }
                V::Map(entries) => {
                    key_append(&mut out, text::MAP_OPEN);
                    stack.push(KeyWork::Text(text::FROM_LIST_CLOSE));
                    stack.push(KeyWork::Entries(entries.iter(), true));
                }
            },
        }
    }
    if out.len() > MAX_KEY_BYTES {
        let mut end = MAX_KEY_BYTES.saturating_sub(text::ELLIPSIS.len());
        while !out.is_char_boundary(end) {
            end = end.saturating_sub(1);
        }
        out.truncate(end);
        out.push_str(text::ELLIPSIS);
    }
    out
}

fn key_append(out: &mut String, s: &str) {
    let remaining = MAX_KEY_BYTES.saturating_sub(out.len()).saturating_add(1);
    let mut end = s.len().min(remaining);
    while !s.is_char_boundary(end) {
        end = end.saturating_add(1);
    }
    if let Some(prefix) = s.get(..end) {
        out.push_str(prefix);
    }
}
