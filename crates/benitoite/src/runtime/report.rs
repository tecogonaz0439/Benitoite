//! 止まったときの報告の組み立て（設計書 02-08「実行時エラーの情報の記録」、02-10「実行時エラーと資源の不足の報告」
//! 「処理系の不具合と処理系の制限の報告」）。
//!
//! 報告を標準エラー出力に書くのは呼び出し側である。ここでは `Diagnostic` を作るだけにする。

use super::panic::PanicReport;
use super::{ResourceError, RuntimeError, SizeUnit, Stop, Stream};
use crate::base::{SourceKind, Span};
use crate::bytecode::program::{CompiledProgram, ProtoOrigin};
use crate::diag::codes::{fill_template, text};
use crate::diag::{
    CallTrace, DiagBuilder, DiagCode, Diagnostic, FrameName, Label, ReportKind, Severity,
    TraceFrame,
};
use crate::vm::{InstrRef, StopInfo};

/// 履歴に全部の段を示す上限と、超えたときに残す内側・外側の段の数（ADR 0034）。
const TRACE_MAX: usize = 20;
const TRACE_KEEP: usize = 10;

/// R0902 の `{unit}` に埋める単位の呼び名。
const UNIT_BYTES: &str = "bytes";
const UNIT_ELEMENTS: &str = "elements";

/// panic の位置が分からないときに `{location}` に埋める値。
const UNKNOWN_LOCATION: &str = "<unknown>";

/// 止まったときの記録から、実行時エラー・資源の不足・処理系の不具合の報告を作る。
/// 主な位置と呼び出しの履歴は 02-08「実行時エラーの情報の記録」の 1〜4 で作る。
/// 書き込みの失敗は主な位置と履歴を持たない。
pub fn stop_diagnostic(program: &CompiledProgram, info: &StopInfo) -> Diagnostic {
    let builder = match &info.stop {
        Stop::Runtime(RuntimeError::DivisionByZero) => DiagBuilder::new(DiagCode::R0101),
        Stop::Runtime(RuntimeError::IntegerOverflow) => DiagBuilder::new(DiagCode::R0102),
        Stop::Runtime(RuntimeError::WriteFailed { stream, reason }) => {
            let code = match stream {
                Stream::Stdout => DiagCode::R0201,
                Stream::Stderr => DiagCode::R0202,
            };
            // 書き込みの失敗は命令の位置と関係しないので、主な位置と履歴を作らない（02-10）。
            return DiagBuilder::new(code)
                .arg("reason", reason.clone())
                .note("reason")
                .build();
        }
        Stop::Resource(ResourceError::CallStackTooDeep { frames }) => {
            DiagBuilder::new(DiagCode::R0901)
                .arg("frames", frames.to_string())
                .note("frames")
                .help("raise")
        }
        Stop::Resource(ResourceError::ValueTooLarge {
            function,
            size,
            unit,
            limit,
        }) => {
            let unit = match unit {
                SizeUnit::Bytes => UNIT_BYTES,
                SizeUnit::Elements => UNIT_ELEMENTS,
            };
            DiagBuilder::new(DiagCode::R0902)
                .arg("function", *function)
                .arg("size", size.to_string())
                .arg("unit", unit)
                .arg("limit", limit.to_string())
                .note("size")
        }
        Stop::Internal(msg) => return internal_diagnostic("run", msg, None),
    };
    let mut diag = builder.build();
    diag.primary = primary_span(program, info).map(|span| Label {
        span,
        text: String::new(),
    });
    diag.trace = Some(call_trace(program, info));
    // 履歴を持つ報告の注記の最後に、末尾呼び出しで消えた段があることを示す（02-10）。
    diag.notes.push(String::from(text::TRACE_TAIL_NOTE));
    diag
}

/// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）。
/// コードを持たないので `DiagBuilder` を使わず、`Diagnostic` を直接組み立てる（kind は `Internal`、文言は `codes::text::INTERNAL_*`）。
/// `stage` は段の名前、`message` は不具合の説明、`panic` は捕らえた panic の内容。
pub fn internal_diagnostic(stage: &str, message: &str, panic: Option<&PanicReport>) -> Diagnostic {
    let mut notes = vec![
        fill_template(
            text::INTERNAL_VERSION,
            &[("version", String::from(env!("CARGO_PKG_VERSION")))],
        ),
        fill_template(text::INTERNAL_STAGE, &[("stage", String::from(stage))]),
    ];
    if !message.is_empty() {
        notes.push(String::from(message));
    }
    if let Some(p) = panic {
        let location = p
            .location
            .clone()
            .unwrap_or_else(|| String::from(UNKNOWN_LOCATION));
        notes.push(fill_template(
            text::INTERNAL_PANIC,
            &[("message", p.message.clone()), ("location", location)],
        ));
    }
    notes.push(String::from(text::INTERNAL_REPORT));
    Diagnostic {
        kind: ReportKind::Internal,
        severity: Severity::Error,
        code: None,
        message: String::from(text::INTERNAL_MESSAGE),
        primary: None,
        secondary: Vec::new(),
        notes,
        helps: Vec::new(),
        trace: None,
        backtrace: panic.and_then(|p| p.backtrace.clone()),
    }
}

/// 命令の由来位置。
fn position(program: &CompiledProgram, at: InstrRef) -> Option<Span> {
    let proto = program.proto(at.proto)?;
    let pc = usize::try_from(at.pc).ok()?;
    proto.positions.get(pc).copied().flatten()
}

/// 由来位置が利用者のソースにあるときだけ返す。
fn user_position(program: &CompiledProgram, at: InstrRef) -> Option<Span> {
    let span = position(program, at)?;
    let source = program.sources.get(span.file)?;
    (source.kind() == SourceKind::User).then_some(span)
}

/// 主な位置（02-08「実行時エラーの情報の記録」の 3）。止まった命令が利用者のソースになければ、
/// 内側の段から順に、利用者のソースにある最初の呼び出した位置を使う。
fn primary_span(program: &CompiledProgram, info: &StopInfo) -> Option<Span> {
    info.at
        .and_then(|at| user_position(program, at))
        .or_else(|| {
            info.frames
                .iter()
                .find_map(|f| f.call_site.and_then(|cs| user_position(program, cs)))
        })
}

/// 呼び出しの履歴（02-08「実行時エラーの情報の記録」の 1・2・4）。
fn call_trace(program: &CompiledProgram, info: &StopInfo) -> CallTrace {
    let mut frames = Vec::new();
    for record in &info.frames {
        let Some(proto) = program.proto(record.proto) else {
            continue;
        };
        // prelude の補助の関数は利用者に意味がないので示さない（02-07「原型の名前と由来の種類」）。
        let name = match (proto.origin, proto.lambda_span) {
            (ProtoOrigin::PreludeHelper, _) => continue,
            (ProtoOrigin::UserLambda, Some(span)) => FrameName::Lambda(span),
            _ => FrameName::Named(proto.name.clone()),
        };
        // prelude のソースの中の呼び出した位置は示さない（02-10）。
        let call_site = record.call_site.and_then(|cs| user_position(program, cs));
        frames.push(TraceFrame { name, call_site });
    }
    let mut omitted = 0;
    if frames.len() > TRACE_MAX {
        let cut = frames.len().saturating_sub(TRACE_MAX);
        omitted = u32::try_from(cut).unwrap_or(u32::MAX);
        frames.drain(TRACE_KEEP..TRACE_KEEP.saturating_add(cut));
    }
    CallTrace { frames, omitted }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // 手で組んだプログラムと StopInfo から報告を作り、主な位置と履歴を確かめる（設計書 02-08、02-10）。
    use std::sync::Arc;

    use super::{internal_diagnostic, stop_diagnostic};
    use crate::base::{BytePos, FileId, Source, SourceKind, SourceTable, Span};
    use crate::bytecode::instr::{Instr, Opcode};
    use crate::bytecode::program::{CompiledProgram, MainKind, Proto, ProtoIdx, ProtoOrigin};
    use crate::diag::codes::text;
    use crate::diag::{DiagCode, FrameName, ReportKind, TraceFrame};
    use crate::runtime::panic::PanicReport;
    use crate::runtime::{ResourceError, RuntimeError, Stop, Stream};
    use crate::vm::{FrameRecord, InstrRef, StopInfo};

    const USER: FileId = FileId(0);
    const PRELUDE: FileId = FileId(1);

    fn span(file: FileId, start: u32) -> Span {
        Span {
            file,
            start: BytePos(start),
            end: BytePos(start + 1),
        }
    }

    /// 由来位置だけを持つ原型。命令は位置の数だけ並べる。
    fn proto(name: &str, origin: ProtoOrigin, positions: Vec<Option<Span>>) -> Proto {
        Proto {
            name: String::from(name),
            origin,
            lambda_span: (origin == ProtoOrigin::UserLambda).then(|| span(USER, 90)),
            code: vec![Instr::abc(Opcode::Return, 0, 0, 0); positions.len()],
            consts: Vec::new(),
            switch_tables: Vec::new(),
            num_regs: 1,
            num_params: 0,
            captures: Vec::new(),
            positions,
        }
    }

    fn program(protos: Vec<Proto>) -> CompiledProgram {
        let mut sources = SourceTable::new();
        let user = sources.add(Source::new(
            String::from("main.bt"),
            SourceKind::User,
            vec![b' '; 200],
        ));
        let prelude = sources.add(Source::new(
            String::from("prelude"),
            SourceKind::Prelude,
            vec![b' '; 200],
        ));
        assert_eq!((user, prelude), (USER, PRELUDE));
        CompiledProgram {
            protos,
            top_fns: Vec::new(),
            ctors: Vec::new(),
            builtins: Vec::new(),
            main: ProtoIdx(0),
            main_kind: MainKind::Unit,
            sources: Arc::new(sources),
        }
    }

    fn at(proto: u32, pc: u32) -> InstrRef {
        InstrRef {
            proto: ProtoIdx(proto),
            pc,
        }
    }

    fn frame(proto: u32, call_site: Option<InstrRef>) -> FrameRecord {
        FrameRecord {
            proto: ProtoIdx(proto),
            call_site,
        }
    }

    /// 0: 利用者の関数（main）→ 1: prelude の公開の関数 → 2: prelude の補助の関数 → 3: 利用者のラムダ。
    /// 各原型の命令 0 が次の段を呼ぶ位置、ラムダの命令 0 が除算。
    fn chain() -> CompiledProgram {
        program(vec![
            proto("main", ProtoOrigin::UserFn, vec![Some(span(USER, 10))]),
            proto(
                "List.map",
                ProtoOrigin::PreludePublic,
                vec![Some(span(PRELUDE, 20))],
            ),
            proto(
                "List.mapHelper",
                ProtoOrigin::PreludeHelper,
                vec![Some(span(PRELUDE, 30))],
            ),
            proto(
                "lambda",
                ProtoOrigin::UserLambda,
                vec![Some(span(USER, 40))],
            ),
        ])
    }

    #[test]
    fn trace_skips_helpers_and_primary_is_the_stopping_instruction() {
        let p = chain();
        let info = StopInfo {
            stop: Stop::Runtime(RuntimeError::DivisionByZero),
            at: Some(at(3, 0)),
            frames: vec![
                frame(3, Some(at(2, 0))),
                frame(2, Some(at(1, 0))),
                frame(1, Some(at(0, 0))),
                frame(0, None),
            ],
        };
        let d = stop_diagnostic(&p, &info);
        assert_eq!(d.code, Some(DiagCode::R0101));
        assert_eq!(d.kind, ReportKind::Runtime);
        let primary = d.primary.unwrap();
        assert_eq!((primary.span, primary.text.as_str()), (span(USER, 40), ""));
        let trace = d.trace.unwrap();
        assert_eq!(trace.omitted, 0);
        assert_eq!(
            trace.frames,
            vec![
                // 補助の関数（prelude のソース）から呼ばれたラムダは、呼び出した位置を示さない。
                TraceFrame {
                    name: FrameName::Lambda(span(USER, 90)),
                    call_site: None,
                },
                TraceFrame {
                    name: FrameName::Named(String::from("List.map")),
                    call_site: Some(span(USER, 10)),
                },
                TraceFrame {
                    name: FrameName::Named(String::from("main")),
                    call_site: None,
                },
            ]
        );
        assert_eq!(
            d.notes.last().map(String::as_str),
            Some(text::TRACE_TAIL_NOTE)
        );
    }

    #[test]
    fn stop_inside_prelude_points_at_the_innermost_user_call_site() {
        let p = chain();
        let info = StopInfo {
            stop: Stop::Runtime(RuntimeError::IntegerOverflow),
            at: Some(at(2, 0)),
            frames: vec![
                frame(2, Some(at(1, 0))),
                frame(1, Some(at(0, 0))),
                frame(0, None),
            ],
        };
        let d = stop_diagnostic(&p, &info);
        assert_eq!(d.code, Some(DiagCode::R0102));
        assert_eq!(d.primary.unwrap().span, span(USER, 10));
    }

    #[test]
    fn long_trace_keeps_ten_innermost_and_ten_outermost_frames() {
        // 原型 i（0..25）は名前 fi。段 i は原型 i を実行し、原型 i+1 の命令 0 から呼ばれた。
        let protos = (0..25)
            .map(|i| {
                proto(
                    &format!("f{i}"),
                    ProtoOrigin::UserFn,
                    vec![Some(span(USER, i))],
                )
            })
            .collect();
        let p = program(protos);
        let frames = (0..25)
            .map(|i| frame(i, (i < 24).then(|| at(i + 1, 0))))
            .collect();
        let info = StopInfo {
            stop: Stop::Resource(ResourceError::CallStackTooDeep { frames: 25 }),
            at: Some(at(0, 0)),
            frames,
        };
        let d = stop_diagnostic(&p, &info);
        assert_eq!(d.code, Some(DiagCode::R0901));
        let trace = d.trace.unwrap();
        assert_eq!(trace.omitted, 5);
        let names: Vec<String> = trace
            .frames
            .iter()
            .map(|f| match &f.name {
                FrameName::Named(n) => n.clone(),
                FrameName::Lambda(_) => panic!("unexpected lambda"),
            })
            .collect();
        let expected: Vec<String> = (0..10).chain(15..25).map(|i| format!("f{i}")).collect();
        assert_eq!(names, expected);
        // R0901 の注記は frames の注記、末尾呼び出しの注記の順。修正案は raise。
        assert_eq!(
            d.notes,
            vec![
                String::from("25 calls were active"),
                String::from(text::TRACE_TAIL_NOTE)
            ]
        );
        assert_eq!(d.helps.len(), 1);
    }

    #[test]
    fn write_failure_has_no_position_and_no_trace() {
        let p = chain();
        for (stream, code) in [
            (Stream::Stdout, DiagCode::R0201),
            (Stream::Stderr, DiagCode::R0202),
        ] {
            let info = StopInfo {
                stop: Stop::Runtime(RuntimeError::WriteFailed {
                    stream,
                    reason: String::from("Broken pipe"),
                }),
                at: Some(at(0, 0)),
                frames: vec![frame(0, None)],
            };
            let d = stop_diagnostic(&p, &info);
            assert_eq!(d.code, Some(code));
            assert_eq!(d.primary, None);
            assert_eq!(d.trace, None);
            assert_eq!(d.notes, vec![String::from("Broken pipe")]);
        }
    }

    #[test]
    fn value_too_large_and_internal_stops() {
        let p = chain();
        let info = StopInfo {
            stop: Stop::Resource(ResourceError::ValueTooLarge {
                function: "File.readText",
                size: 5,
                unit: crate::runtime::SizeUnit::Bytes,
                limit: 4,
            }),
            at: Some(at(0, 0)),
            frames: vec![frame(0, None)],
        };
        let d = stop_diagnostic(&p, &info);
        assert_eq!(d.code, Some(DiagCode::R0902));
        assert!(d.message.contains("File.readText"), "{}", d.message);
        assert_eq!(d.notes[0], "the result would have 5 bytes; the limit is 4");

        let info = StopInfo {
            stop: Stop::Internal(String::from("bad register")),
            at: None,
            frames: Vec::new(),
        };
        let d = stop_diagnostic(&p, &info);
        assert_eq!(d.kind, ReportKind::Internal);
        assert_eq!(d.code, None);
        assert!(d.notes.contains(&String::from("bad register")));
    }

    #[test]
    fn internal_diagnostic_orders_its_notes() {
        let panic = PanicReport {
            message: String::from("boom"),
            location: Some(String::from("src/x.rs:1:2")),
            backtrace: Some(String::from("bt")),
        };
        let d = internal_diagnostic("run", "", Some(&panic));
        assert_eq!(d.message, text::INTERNAL_MESSAGE);
        assert_eq!(
            d.notes,
            vec![
                format!("benitoite {}", env!("CARGO_PKG_VERSION")),
                String::from("the error occurred in the run stage"),
                String::from("panic: boom at src/x.rs:1:2"),
                String::from(text::INTERNAL_REPORT),
            ]
        );
        assert_eq!(d.backtrace.as_deref(), Some("bt"));
    }
}
