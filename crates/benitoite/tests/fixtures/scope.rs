//! Scopeの独立した入力と期待値を静的・実行時の公開入口で共有する。
use serde_json::Value;

pub fn cases() -> Vec<Value> {
    serde_json::from_str(include_str!("checked-scope.json")).unwrap()
}

pub fn quoted(text: &str) -> String {
    serde_json::to_string(text)
        .unwrap()
        .replace("\\u0000", "\\u{0}")
}

pub fn arguments(case: &Value) -> String {
    let kind = case.get("kind").unwrap().as_str().unwrap();
    let pattern = quoted(case.get("pattern").unwrap().as_str().unwrap());
    let target = quoted(case.get("target").unwrap().as_str().unwrap());
    match kind {
        "endpoint" => format!(
            "hostPattern: {pattern}, host: {target}, minimumPort: {}, maximumPort: {}, port: {}",
            case.get("minimum").unwrap(),
            case.get("maximum").unwrap(),
            case.get("port").unwrap()
        ),
        "path" => format!("pattern: {pattern}, path: {target}"),
        _ => format!("pattern: {pattern}, host: {target}"),
    }
}

pub fn operation(case: &Value) -> &str {
    match case.get("kind").unwrap().as_str().unwrap() {
        "host" => "Host",
        "path" => "Path",
        _ => "Endpoint",
    }
}
