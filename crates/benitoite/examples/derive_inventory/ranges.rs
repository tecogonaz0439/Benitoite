//! 範囲を既存の交換形式で書く（設計書 03-06「外部生成の宣言情報」）。
use super::{Error, text};
use benitoite::types::{
    builtin::RangeIndex,
    scope::{Family, HostPattern, Kind, NameKind, PathKind, Range},
    signature::{IoShape, RangeAdmission, RangeSignature},
};
use serde_core::ser::{Serialize, SerializeMap, SerializeSeq, Serializer};
use serde_json::{Value, json};

pub(super) fn kind(k: Kind) -> &'static str {
    match k {
        Kind::Path => "path",
        Kind::Host => "host",
        Kind::Endpoint => "endpoint",
    }
}

fn host(h: &HostPattern) -> Value {
    match h {
        HostPattern::Name(p) => {
            let tag = match p.kind() {
                NameKind::Exact => "exact",
                NameKind::One => "one",
                NameKind::Many => "many",
            };
            json!({"name":{tag:p.stem().labels()}})
        }
        HostPattern::Ip(p) => {
            let address = p.address();
            let family = match address.family() {
                Family::V4 => "v4",
                Family::V6 => "v6",
            };
            match p.prefix_len() {
                Some(n) => {
                    json!({"ip":{"cidr":{"family":family,"network":address.bits().to_string(),"prefixLen":n}}})
                }
                None => json!({"ip":{"exact":{"family":family,"bits":address.bits().to_string()}}}),
            }
        }
    }
}

fn range(r: &Range) -> Value {
    match r {
        Range::Top => json!("top"),
        Range::Path(p) => {
            let tag = match p.kind() {
                PathKind::Exact => "exact",
                PathKind::Tree => "tree",
            };
            json!({"path":{tag:p.stem().parts()}})
        }
        Range::Host(p) => json!({"host":host(p)}),
        Range::Endpoint(p) => {
            json!({"endpoint":{"host":host(&p.host),"ports":{"lo":p.ports.lo().value(),"hi":p.ports.hi().value()}}})
        }
    }
}

pub(super) fn index(
    ix: &RangeIndex,
    expected: Option<Kind>,
    rs: &RangeSignature,
) -> Result<Value, Error> {
    if let Some(i) = ix.variable() {
        if expected.is_none() || rs.kinds.get(usize::try_from(i)?).copied() != expected {
            return Err(text::INVALID_SCHEMA.into());
        }
        Ok(json!({"rvar":i}))
    } else {
        let r = ix.range().ok_or(text::INVALID_SCHEMA)?;
        if *r != Range::Top && r.kind() != expected {
            return Err(text::INVALID_SCHEMA.into());
        }
        Ok(json!({"fixed":range(r)}))
    }
}

pub(super) fn admission(a: RangeAdmission) -> Value {
    match a {
        RangeAdmission::Any => json!("any"),
        RangeAdmission::Covers { outer, inner } => json!({"covers":{"inner":inner,"outer":outer}}),
    }
}

pub(super) fn shape(s: IoShape) -> Value {
    match s {
        IoShape::Untargeted => json!("untargeted"),
        IoShape::TopTargeted(k) => json!({"topTargeted":{"kind":kind(k)}}),
        IoShape::Single { kind: k, position } => {
            json!({"single":{"kind":kind(k),"position":position}})
        }
    }
}

// Value が保持できない IPv6 の全幅は、交換の出力と同じく材料だけ十進文字列にする。
// 最終 JSON では整数として書き、Python が元のビット列を損失なく読む。
#[derive(Clone, Copy)]
enum Context {
    Inventory,
    Range,
    Data,
}

struct InventoryJson<'a>(&'a Value, Context);

impl Serialize for InventoryJson<'_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        match self.0 {
            Value::Object(object) => {
                let mut output = serializer.serialize_map(Some(object.len()))?;
                for (key, value) in object {
                    if matches!(self.1, Context::Range)
                        && ((key == "bits" && object.contains_key("family"))
                            || (key == "network" && object.contains_key("prefixLen")))
                        && let Value::String(value) = value
                    {
                        let number = value
                            .parse::<u128>()
                            .map_err(serde_core::ser::Error::custom)?;
                        output.serialize_entry(key, &number)?;
                    } else {
                        let context = match self.1 {
                            Context::Inventory => match key.as_str() {
                                "config" | "metadata" => Context::Data,
                                "ix" => Context::Range,
                                _ => Context::Inventory,
                            },
                            context @ (Context::Range | Context::Data) => context,
                        };
                        output.serialize_entry(key, &InventoryJson(value, context))?;
                    }
                }
                output.end()
            }
            Value::Array(array) => {
                let mut output = serializer.serialize_seq(Some(array.len()))?;
                for value in array {
                    output.serialize_element(&InventoryJson(value, self.1))?;
                }
                output.end()
            }
            Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {
                self.0.serialize(serializer)
            }
        }
    }
}

/// 宣言情報の JSON を書き、範囲内の IP のビット列を整数のまま保持する。
pub fn to_string(value: &Value) -> serde_json::Result<String> {
    serde_json::to_string(&InventoryJson(value, Context::Inventory))
}

pub(super) fn sorted(values: Vec<Value>) -> Result<Vec<Value>, Error> {
    let mut keyed = values
        .into_iter()
        .map(|value| Ok((to_string(&value)?, value)))
        .collect::<Result<Vec<_>, Error>>()?;
    keyed.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(keyed.into_iter().map(|(_, value)| value).collect())
}
