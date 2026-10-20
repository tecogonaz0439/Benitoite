//! 外部の関数の上限の解釈と集計の報告（設計書 06-01「オプション」）。

use super::text;
use crate::external::{
    Limits,
    stats::{Collector, ExecutionOptions},
};
use crate::runtime::run::OutputTarget;

/// `run` と `test` が受け取る外部の関数の設定。
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct WasmOptions {
    pub(crate) limits: Limits,
    pub(crate) memory_overridden: bool,
    pub(crate) fuel_overridden: bool,
    pub(crate) transfer_overridden: bool,
    pub(crate) stats: bool,
}
impl WasmOptions {
    pub(super) fn accepts(name: &str) -> bool {
        matches!(
            name,
            "--wasm-memory" | "--wasm-fuel" | "--wasm-transfer" | "--wasm-stats"
        )
    }
    pub(super) fn parse(&mut self, name: &str, value: Option<&str>) -> Result<(), String> {
        if name == "--wasm-stats" {
            if value.is_some() {
                return Err(text::OPTION_TAKES_NO_VALUE.replace("{name}", name));
            }
            self.stats = true;
            return Ok(());
        }
        let invalid = || {
            let template = if value.is_none_or(str::is_empty) {
                text::MISSING_OPTION_VALUE
            } else {
                text::BAD_VALUE
            };
            let error = template
                .replace("{name}", name)
                .replace("{value}", value.unwrap_or(""));
            let range = match name {
                "--wasm-memory" | "--wasm-transfer" => Some(text::WASM_SIZE_RANGE),
                "--wasm-fuel" => Some(text::WASM_FUEL_RANGE),
                _ => None,
            };
            match range {
                Some(range) => format!("{error}; {range}"),
                None => error,
            }
        };
        let value = value.ok_or_else(invalid)?;
        let number = if name == "--wasm-fuel" {
            decimal(value).filter(|n| *n > 0)
        } else {
            decimal(value)
                .or_else(|| super::parse_size(value))
                .filter(|n| (1024 * 1024..=4 * 1024 * 1024 * 1024).contains(n))
        }
        .ok_or_else(invalid)?;
        match name {
            "--wasm-memory" => {
                self.limits.memory = number;
                self.memory_overridden = true;
            }
            "--wasm-fuel" => {
                self.limits.fuel = number;
                self.fuel_overridden = true;
            }
            "--wasm-transfer" => {
                self.limits.transfer = number;
                self.transfer_overridden = true;
            }
            _ => return Err(invalid()),
        }
        Ok(())
    }
    pub(super) fn execution(&self) -> ExecutionOptions {
        ExecutionOptions {
            session: None,
            limits: self.limits,
            stats: self.stats.then(Collector::new),
        }
    }
    pub(super) fn report(&self, execution: &ExecutionOptions, target: &OutputTarget) {
        if let Some(stats) = &execution.stats {
            let result = (|| {
                let mut value = stats.json()?;
                let object = value.as_object_mut().ok_or_else(|| {
                    crate::runtime::Stop::Internal("external statistics object missing".into())
                })?;
                object.insert("wasm_stats".into(), serde_json::Value::Bool(true));
                object.insert("limits".into(), serde_json::json!({"memory": self.limits.memory, "fuel": self.limits.fuel, "transfer": self.limits.transfer}));
                object.insert("overrides".into(), serde_json::json!({"memory": self.memory_overridden, "fuel": self.fuel_overridden, "transfer": self.transfer_overridden}));
                Ok::<_, crate::runtime::Stop>(format!("{value}\n"))
            })();
            if let Ok(line) = result {
                let _result = target.write_bytes(line.as_bytes());
            }
        }
    }
}
fn decimal(value: &str) -> Option<u64> {
    if value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    value.parse().ok()
}
