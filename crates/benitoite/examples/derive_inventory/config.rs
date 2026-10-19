//! 生成設定の version 1。重複キーを Value へ潰す前に拒む（設計書 03-06「外部生成の宣言情報」）。
use super::text;
use serde_core::de::{self, Deserialize, Deserializer, MapAccess, SeqAccess, Visitor};
use serde_json::{Map, Value};
use std::fmt;

pub type Error = Box<dyn std::error::Error + Send + Sync>;

struct Unique(Value);
impl<'de> Deserialize<'de> for Unique {
    fn deserialize<D: Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        struct Read;
        impl<'de> Visitor<'de> for Read {
            type Value = Unique;
            fn expecting(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                f.write_str(text::JSON_WITHOUT_DUPLICATE_KEYS)
            }
            fn visit_map<A: MapAccess<'de>>(self, mut a: A) -> Result<Unique, A::Error> {
                let mut out = Map::new();
                while let Some(k) = a.next_key::<String>()? {
                    if out.contains_key(&k) {
                        return Err(de::Error::custom(text::duplicate_key(&k)));
                    }
                    out.insert(k, a.next_value::<Unique>()?.0);
                }
                Ok(Unique(Value::Object(out)))
            }
            fn visit_seq<A: SeqAccess<'de>>(self, mut a: A) -> Result<Unique, A::Error> {
                let mut out = vec![];
                while let Some(v) = a.next_element::<Unique>()? {
                    out.push(v.0);
                }
                Ok(Unique(Value::Array(out)))
            }
            fn visit_str<E: de::Error>(self, v: &str) -> Result<Unique, E> {
                Ok(Unique(Value::from(v)))
            }
            fn visit_bool<E: de::Error>(self, v: bool) -> Result<Unique, E> {
                Ok(Unique(Value::from(v)))
            }
            fn visit_i64<E: de::Error>(self, v: i64) -> Result<Unique, E> {
                Ok(Unique(Value::from(v)))
            }
            fn visit_u64<E: de::Error>(self, v: u64) -> Result<Unique, E> {
                Ok(Unique(Value::from(v)))
            }
            fn visit_f64<E: de::Error>(self, v: f64) -> Result<Unique, E> {
                Ok(Unique(Value::from(v)))
            }
            fn visit_unit<E: de::Error>(self) -> Result<Unique, E> {
                Ok(Unique(Value::Null))
            }
        }
        d.deserialize_any(Read)
    }
}

pub fn object<'a>(v: &'a Value, allowed: &[&str]) -> Result<&'a Map<String, Value>, Error> {
    let o = v.as_object().ok_or(text::EXPECTED_AN_OBJECT)?;
    for k in o.keys() {
        if !allowed.contains(&k.as_str()) {
            return Err(text::unknown_key(k).into());
        }
    }
    Ok(o)
}
pub fn string<'a>(v: &'a Value, k: &str) -> Result<&'a str, Error> {
    v.get(k)
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| text::expected_string(k).into())
}
fn strings(v: &Value) -> Result<(), Error> {
    let o = v.as_object().ok_or(text::EXPECTED_AN_OBJECT_OF_STRINGS)?;
    if o.values().any(|v| !v.is_string()) {
        return Err(text::EXPECTED_STRING_VALUES.into());
    }
    Ok(())
}
fn pair(v: &Value, a: &str, b: &str) -> Result<(), Error> {
    if v.get(a).is_some() != v.get(b).is_some() {
        return Err(text::required_pair(a, b).into());
    }
    for key in [a, b] {
        if v.get(key).is_some() {
            string(v, key)?;
        }
    }
    Ok(())
}
pub fn read(bytes: &[u8]) -> Result<Value, Error> {
    let mut d = serde_json::Deserializer::from_slice(bytes);
    let v = Unique::deserialize(&mut d)?.0;
    d.end()?;
    object(&v, &["version", "targets"])?;
    if v.get("version").and_then(Value::as_u64) != Some(1) {
        return Err(text::UNSUPPORTED_CONFIG_VERSION.into());
    }
    let targets = v
        .get("targets")
        .and_then(Value::as_array)
        .ok_or(text::EXPECTED_TARGETS_ARRAY)?;
    let mut identities = std::collections::BTreeSet::new();
    let mut regions = std::collections::BTreeSet::new();
    for t in targets {
        object(
            t,
            &[
                "source", "type", "region", "json", "property", "show", "order", "fields",
            ],
        )?;
        for key in ["show", "order"] {
            if t.get(key).is_some_and(|v| !v.is_boolean()) {
                return Err(text::expected_boolean(key).into());
            }
        }
        let source = string(t, "source")?;
        let ty = string(t, "type")?;
        let region = string(t, "region")?;
        if !region
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'-'))
        {
            return Err(text::INVALID_REGION_NAME.into());
        }
        if !identities.insert((source, ty)) || !regions.insert((source, region)) {
            return Err(text::DUPLICATE_TARGET_OR_REGION.into());
        }
        if let Some(j) = t.get("json") {
            object(j, &["encode", "decode", "keys"])?;
            string(j, "encode")?;
            string(j, "decode")?;
            if let Some(keys) = j.get("keys") {
                strings(keys)?;
            }
        }
        if let Some(p) = t.get("property") {
            object(p, &["generator", "shrinker"])?;
            string(p, "generator")?;
            string(p, "shrinker")?;
        }
        if let Some(fields) = t.get("fields") {
            for f in fields
                .as_object()
                .ok_or(text::EXPECTED_FIELDS_OBJECT)?
                .values()
            {
                object(f, &["encode", "decode", "decodeMissing", "gen", "shrink"])?;
                pair(f, "encode", "decode")?;
                pair(f, "gen", "shrink")?;
                if f.get("decodeMissing").is_some() {
                    string(f, "decodeMissing")?;
                    if f.get("decode").is_none() {
                        return Err(text::DECODEMISSING_REQUIRES_DECODE.into());
                    }
                }
                for value in f.as_object().ok_or(text::EXPECTED_FIELD_OBJECT)?.values() {
                    let name = value.as_str().ok_or(text::EXPECTED_FUNCTION_NAME)?;
                    if !name.contains('.') {
                        return Err(text::CUSTOM_FUNCTIONS_MUST_HAVE_QUALIFIED_NAMES.into());
                    }
                }
            }
        }
    }
    Ok(v)
}
