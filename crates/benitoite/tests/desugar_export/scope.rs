//! 範囲と署名の有限表を交換し、項との境界を保つ（設計書 07-04「交換の形式の版」）。
use super::*;
use benitoite::types::builtin::{BUILTIN_EFFECTS, BUILTIN_TYPES, BuiltinEffectId, RangeIndex};
use benitoite::types::scope::{Family, HostPattern, Kind, NameKind, PathKind, Range};
use benitoite::types::signature::{IoShape, RangeAdmission, RangeSignature};

// 利用者向けの名前は IO/Network を省くが、交換の識別名は既存の完全名を保つ。
pub(crate) fn effect_name(id: BuiltinEffectId) -> String {
    let d = id.def().unwrap();
    if d.module == ["IO", "Process"] && d.name == "Exit" {
        "Process.Exit".to_owned()
    } else if d.module.is_empty() {
        d.name.to_owned()
    } else {
        format!("{}.{}", d.module.join("."), d.name)
    }
}

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
            let a = p.address();
            let family = match a.family() {
                Family::V4 => "v4",
                Family::V6 => "v6",
            };
            // arbitrary_precision なしの Value は IPv6 の全幅を保持できないため、
            // 材料は十進文字列とし、ExchangeJson が最終 JSON に整数として書く。
            match p.prefix_len() {
                Some(n) => {
                    json!({"ip":{"cidr":{"family":family,"network":a.bits().to_string(),"prefixLen":n}}})
                }
                None => json!({"ip":{"exact":{"family":family,"bits":a.bits().to_string()}}}),
            }
        }
    }
}

pub(super) fn range(r: &Range) -> Value {
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

pub(crate) fn index(ix: &RangeIndex, bound: Option<usize>) -> Value {
    if let Some(i) = ix.variable() {
        assert!(
            bound.is_some_and(|n| usize::try_from(i).unwrap() < n),
            "rvar outside signature/rkinds"
        );
        json!({"rvar":i})
    } else {
        json!({"fixed":range(ix.range().expect("closed range index"))})
    }
}

// 関門: signature_valid の事前検査を通さず、交換する添字の上限を直接確かめる。
#[test]
#[should_panic(expected = "rvar outside signature/rkinds")]
fn rejects_range_index_equal_to_signature_bound() {
    assert_eq!(index(&RangeIndex::var(0), Some(1)), json!({"rvar":0}));
    index(&RangeIndex::var(1), Some(1));
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

pub(crate) fn table_data(prims: &[(String, RangeSignature)], request_content: Value) -> Value {
    let eff_kinds: Vec<_> = BUILTIN_EFFECTS
        .iter()
        .enumerate()
        .filter_map(|(i, _)| {
            let id = BuiltinEffectId(u16::try_from(i).unwrap());
            id.scope_kind()
                .map(|k| json!({"name":effect_name(id),"kind":kind(k)}))
        })
        .collect();
    let val_kinds: Vec<_> = BUILTIN_TYPES
        .iter()
        .enumerate()
        .filter_map(|(i, _)| {
            let id = BuiltinTypeId(u16::try_from(i).unwrap());
            id.value_kind()
                .map(|k| json!({"name":format!("{}:[]",id.0),"kind":kind(k)}))
        })
        .collect();
    let admits: Vec<_> = prims
        .iter()
        .map(|(name, s)| {
            let rule = match s.admission {
                RangeAdmission::Any => json!("any"),
                RangeAdmission::Covers { outer, inner } => {
                    assert!(usize::try_from(inner).unwrap() < s.kinds.len());
                    assert!(usize::try_from(outer).unwrap() < s.kinds.len());
                    json!({"covers":{"inner":inner,"outer":outer}})
                }
            };
            json!({"name":name,"rule":rule})
        })
        .collect();
    let contents = json!([{
        "name":format!("{}:[]",BuiltinTypeId::REQUEST_IN.0),
        "content":request_content
    }]);
    json!({"effKinds":eff_kinds,"valKinds":val_kinds,"admitsR":admits,"valContents":contents})
}

/// 表層のリテラルは構文解析済みの文字列であり、範囲の解析には本番と同じ解析器を使う。
/// 未知の文字列や不良なパターンは表に置かず、Lean の所属判定でも未知のままにする。
pub(crate) fn acceptance(input: &Value) -> Value {
    use benitoite::typeck::DEFAULT_SCOPE_LIMITS as limits;
    use benitoite::types::scope::PathPattern;
    let mut strings = BTreeSet::new();
    let mut pending = vec![input];
    while let Some(value) = pending.pop() {
        match value {
            Value::Array(values) => pending.extend(values),
            Value::Object(fields) => {
                if let Some(text) = value.get("string").and_then(|s| s["value"].as_str()) {
                    strings.insert(text);
                }
                pending.extend(fields.values());
            }
            Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {}
        }
    }
    let patterns: Vec<_> = strings
        .iter()
        .filter_map(|text| {
            PathPattern::parse(text)
                .ok()
                .map(|p| json!({"text":text,"range":range(&Range::Path(p))}))
        })
        .collect();
    let hosts: Vec<_> = strings
        .iter()
        .filter_map(|text| {
            HostPattern::parse(text)
                .ok()
                .map(|p| json!({"text":text,"pattern":host(&p)}))
        })
        .collect();
    json!({"patterns":patterns,"hosts":hosts,"limits":{
        "body":{"operations":limits.body.operations,"items":limits.body.items},
        "whole":{"operations":limits.whole.operations,"items":limits.whole.items}}})
}
