//! テスト用の IO の口。環境・時計・乱数に与えた値を返し、出力を書き込みごとに記録する
//! （設計書 02-08「組み込みの関数の呼び出し」）。

use std::collections::BTreeMap;
use std::ffi::OsString;
use std::path::Path;

use crate::builtins::iface::{IoServices, IoWait, OsResource};
use crate::runtime::heap::ResourceId;
use crate::runtime::io::services::RunInput;
use crate::runtime::{ResourceKind, Stop, Stream};
use crate::vm::InstrRef;

/// テスト用の IO。環境・時計・乱数には与えた値を使い、出力は書き込みごとに順を記録する。
/// 登録の口は使わない。呼ばれたら `take_internal_error` で不具合として取り出す。
pub struct FixedIo {
    input: RunInput,
    output: Vec<(Stream, Vec<u8>)>,
    /// テストが与える環境変数。
    pub environment: BTreeMap<String, OsString>,
    /// テストが与える UTC のミリ秒。
    pub now: i64,
    /// テストが与える地方時の差。
    pub local_offset: i32,
    /// テストが与える単調な時計のミリ秒。
    pub monotonic: i64,
    /// テストが与える乱数の値。
    pub random: u64,
    internal_error: Option<&'static str>,
}

impl FixedIo {
    /// テストが与える入力から作る。
    pub fn new(input: RunInput) -> Self {
        Self {
            input,
            output: Vec::new(),
            environment: BTreeMap::new(),
            now: 0,
            local_offset: 0,
            monotonic: 0,
            random: 0,
            internal_error: None,
        }
    }
    /// 書いた順のバイト列を取り出す。出力の種類を各書き込みとともに返す。
    pub fn take_output(&mut self) -> Vec<(Stream, Vec<u8>)> {
        std::mem::take(&mut self.output)
    }
    /// 未対応の登録の口を呼んだ記録。実行の終わりにも確かめる。
    pub fn take_internal_error(&mut self) -> Option<Stop> {
        self.internal_error
            .take()
            .map(|reason| Stop::Internal(reason.into()))
    }
}

impl IoServices for FixedIo {
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop> {
        if let Some(error) = self.take_internal_error() {
            return Err(error);
        }
        self.output.push((stream, text.as_bytes().to_vec()));
        Ok(None)
    }
    fn arguments(&self) -> &[String] {
        &self.input.arguments
    }
    fn script_directory(&self) -> &Path {
        &self.input.script_directory
    }
    fn working_directory(&self) -> &Path {
        &self.input.working_directory
    }
    fn environment_variable(&self, name: &str) -> Option<OsString> {
        self.environment.get(name).cloned()
    }
    fn now_millis(&self) -> i64 {
        self.now
    }
    fn local_offset_minutes(&self) -> i32 {
        self.local_offset
    }
    fn monotonic_millis(&self) -> i64 {
        self.monotonic
    }
    fn random_u64(&mut self) -> u64 {
        self.random
    }
    fn register_resource(
        &mut self,
        _kind: ResourceKind,
        _handle: Box<dyn OsResource>,
        _opened_at: Option<InstrRef>,
    ) -> ResourceId {
        self.internal_error = Some("FixedIo must not register resources");
        ResourceId(u64::MAX)
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;

    #[derive(Debug)]
    struct UnusedResource;
    impl OsResource for UnusedResource {
        fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
            self
        }
        fn release(self: Box<Self>) -> Result<(), String> {
            Ok(())
        }
    }

    fn input() -> RunInput {
        let directory = std::env::current_dir().unwrap();
        RunInput {
            arguments: vec!["arg".into()],
            working_directory: directory.clone(),
            script_directory: directory.join("scripts"),
        }
    }

    #[test]
    fn fixed_io_supplies_environment_clocks_and_records_unexpected_registration() {
        let input = input();
        let mut services = FixedIo::new(input.clone());
        services
            .environment
            .insert("EXAMPLE".into(), "value".into());
        services.now = 123;
        services.local_offset = 540;
        services.monotonic = 456;
        services.random = 789;
        assert_eq!(services.arguments(), input.arguments);
        assert_eq!(services.working_directory(), input.working_directory);
        assert_eq!(services.script_directory(), input.script_directory);
        assert_eq!(
            services.environment_variable("EXAMPLE"),
            Some("value".into())
        );
        assert_eq!(services.environment_variable("MISSING"), None);
        assert_eq!(services.now_millis(), 123);
        assert_eq!(services.local_offset_minutes(), 540);
        assert_eq!(services.monotonic_millis(), 456);
        assert_eq!(services.random_u64(), 789);
        assert!(services.take_internal_error().is_none());
        services.register_resource(ResourceKind::FileReader, Box::new(UnusedResource), None);
        assert!(
            matches!(services.take_internal_error(), Some(Stop::Internal(reason)) if reason.contains("must not register resources"))
        );
    }
}
