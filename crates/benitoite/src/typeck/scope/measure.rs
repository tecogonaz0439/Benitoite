//! 通常ソースを増やして Scope の予算を測る（設計書 02-05「Scope の必須判定の入力」）。
//! 入力・計上点・受理・停止を同じ測定に残し、特殊構成では同じ入力群の個数を減らす。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::*;
use crate::types::scope::{PathPattern, Range};
use serde_json::json;
use sha2::{Digest, Sha256};
use std::fmt::Write as _;
use std::time::Instant;

const IMPORTS: &str = "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.IO.File\n";

fn six_source(count: usize) -> String {
    let mut source = IMPORTS.to_owned();
    for i in 0..count {
        writeln!(source, r#"function sample{i}(path: String, request: Http.ClientRequest) -> Unit
 bind checked <- Scope.checkPathIn(pattern: "/data/**", path: path)
 match checked with
 case Result.Ok(p) ->
  bind projected <- Scope.pathInValue(path: p)
  bind wide: Scope.PathIn <- Scope.widenPathIn(path: p)
  bind copy <- p
  bind branch <- if true then p else p end if
  bind ignored <- Scope.pathInValue(path: branch)
  bind again <- Scope.checkPathIn(pattern: projected, path: path)
  ()
 case Result.Error(_) -> ()
 end match
 bind result <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: 443, request: request)
 match result with
 case Result.Ok(r) ->
  bind projected <- Http.requestInValue(request: r)
  bind wide: Http.RequestIn <- Http.widenRequestIn(request: r)
  bind copy <- r
  bind branch <- block r end block
  bind ignored <- Http.requestInValue(request: branch)
  bind again <- Http.checkRequestIn(hostPattern: "other.example", minimumPort: 443, maximumPort: 443, request: projected)
  ()
 case Result.Error(_) -> ()
 end match
 ()
end function"#).unwrap();
    }
    source
}

fn dense_source(count: usize) -> String {
    let single = six_source(1);
    let body = single
        .split_once("-> Unit\n")
        .unwrap()
        .1
        .strip_suffix("end function\n")
        .unwrap();
    let mut source =
        format!("{IMPORTS}function sample(path: String, request: Http.ClientRequest) -> Unit\n");
    for i in 0..count {
        writeln!(source, " bind block{i} <- block\n{body} end block").unwrap();
    }
    source.push_str(" ()\nend function\n");
    source
}

// 関門: 七つの IO を登録した後も、同じ解析入口で局所費用と範囲の維持を測る。
// 六つの純粋 API だけの入力では、IO 呼び出しを含む本体の読み取り費用を確認できない。
// IO 自体は実行せず、本物の読み込み・名前解決・型検査の結果を使う。
fn seven_io_source(count: usize, dense: bool) -> String {
    let source = if dense {
        dense_source(count)
    } else {
        six_source(count)
    };
    source
        .replace(
            "-> Unit\n",
            "-> Unit uses File.Read, File.Write, Http.Connect\n",
        )
        .replace(
            "  bind projected <- Scope.pathInValue(path: p)",
            "  bind projected <- Scope.pathInValue(path: p)\n  bind io0 <- File.readTextIn(path: p)\n  bind io1 <- File.readBytesIn(path: p)\n  bind io2 <- File.writeTextIn(path: p, text: \"data\")\n  bind io3 <- File.appendTextIn(path: p, text: \"data\")\n  bind io4 <- File.writeBytesIn(path: p, content: String.toUTF8(\"data\"))\n  bind io5 <- File.appendBytesIn(path: p, content: String.toUTF8(\"data\"))",
        )
        .replace(
            "  bind projected <- Http.requestInValue(request: r)",
            "  bind projected <- Http.requestInValue(request: r)\n  bind io6 <- Http.sendIn(request: r)",
        )
}

fn retained_source(count: usize) -> String {
    let mut source = format!("{IMPORTS}function sample(path: String) -> Unit\n");
    for i in 0..count {
        writeln!(
            source,
            " bind kept{i} <- Scope.checkPathIn(pattern: \"/data/**\", path: path)"
        )
        .unwrap();
    }
    source.push_str(" ()\nend function\n");
    source
}

// レビューの普通の文と同じ算術・呼び出し、if の密度で番号付けを測る。
fn ordinary_source(count: usize, conditional: bool) -> String {
    let mut source = format!("{IMPORTS}function sample(path: String) -> Unit\n");
    for i in 1..=count {
        if (i - 1) % 500 == 0 {
            writeln!(source, " bind group{} <- block", (i - 1) / 500).unwrap();
        }
        if conditional {
            writeln!(source, " bind x{i} <- if String.byteLength(path) > {i} then String.byteLength(path) + String.characterCount(path) * {i} else String.characterCount(path) - {i} end if").unwrap();
        } else {
            writeln!(
                source,
                " bind x{i} <- String.byteLength(path) + {i} * 2 - String.characterCount(path)"
            )
            .unwrap();
        }
        if i % 500 == 0 || i == count {
            source.push_str(" ()\n end block\n");
        }
    }
    source.push_str(
        " bind result <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n ()\nend function\n",
    );
    source
}

// 射影は成功値の事実を読み、返す文字列へは事実を書かない。
// 本体の操作数だけを増やせる。lambda を並べれば全体の操作数が先に届く。
fn projections_source(groups: usize, count: usize) -> String {
    let mut source = format!("{IMPORTS}function sample(path: String) -> Unit\n");
    for group in 0..groups {
        if groups > 1 {
            writeln!(source, " bind run{group} <- lambda()").unwrap();
        }
        source.push_str(" bind checked <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n match checked with\n case Result.Ok(p) ->\n");
        for i in 0..count {
            if i % 500 == 0 {
                writeln!(source, " bind group{} <- block", i / 500).unwrap();
            }
            writeln!(source, " bind value{i} <- Scope.pathInValue(path: p)").unwrap();
            if (i + 1) % 500 == 0 || i + 1 == count {
                source.push_str(" ()\n end block\n");
            }
        }
        source.push_str(" ()\n case Result.Error(_) -> ()\n end match\n ()\n");
        if groups > 1 {
            source.push_str(" end lambda\n");
        }
    }
    source.push_str(" ()\nend function\n");
    source
}

// 各本体は 512 項目以内で、入口が外側の保持を全体の保持へ足す。
fn nested_retained_source(depth: usize, count: usize) -> String {
    let mut source = format!("{IMPORTS}function sample(path: String) -> Unit\n");
    for level in 0..depth {
        for i in 0..count {
            writeln!(
                source,
                " bind kept{level}_{i} <- Scope.checkPathIn(pattern: \"/data/**\", path: path)"
            )
            .unwrap();
        }
        if level + 1 < depth {
            writeln!(source, " bind run{level} <- lambda()").unwrap();
        }
    }
    source.push_str(" ()\n");
    for _ in 1..depth {
        source.push_str(" end lambda\n ()\n");
    }
    source.push_str("end function\n");
    source
}

fn sequential_handlers(count: usize) -> String {
    let mut source = format!(
        "{IMPORTS}effect Tick\n function tick() -> Integer\nend effect\nfunction sample() -> Unit\n"
    );
    for i in 0..count {
        writeln!(
            source,
            " bind h{i} <- handle tick() with\n case tick() -> resume(1)\n end handle"
        )
        .unwrap();
    }
    source.push_str(" ()\nend function\n");
    source
}

const READ_CLAUSES: &str = r#"case File.readText(path) -> 0
 case File.openReader(path) -> 0
 case File.readLine(reader) -> 0
 case File.readBytes(path) -> 0
 case File.readTextIn(path) -> 0
 case File.readBytesIn(path) -> 0
 case File.readLines(path) -> 0
 case File.exists(path) -> 0
 case File.info(path) -> 0
 case File.listDirectory(path) -> 0
 case File.walk(path) -> 0
 case File.canonicalize(path) -> 0
 case File.readChunk(reader, maximumBytes) -> 0"#;

fn later_handlers(count: usize, complete: bool) -> String {
    let mut source = format!(
        "{IMPORTS}effect Tick\n function tick() -> Integer\nend effect\nfunction protected() -> Integer uses File.Read[\"/data/a\"]\n return 1\nend function\nfunction sample() -> Unit uses File.Read[\"/data/a\"]\n"
    );
    let clauses = if complete {
        READ_CLAUSES
    } else {
        "case File.readText(path) -> 0"
    };
    for i in 0..count {
        writeln!(source, " bind run{i} <- lambda(f)\n  return handle f() with\n  {clauses}\n  end handle\n end lambda").unwrap();
    }
    for i in 0..count {
        writeln!(source, " bind h{i} <- handle tick() with\n case tick() -> resume(run{i}(protected))\n end handle").unwrap();
    }
    source.push_str(" ()\nend function\n");
    source
}

// 完全なハンドラの出力を次のハンドラの保護本体へ流す。
// 後の節から最後の lambda を呼ぶと、handled の改訂が連鎖する。
fn handler_chain(count: usize) -> String {
    let mut source = format!(
        "{IMPORTS}effect Tick\n function tick() -> Integer\nend effect\nfunction protected() -> Integer uses File.Read[\"/data/a\"]\n return 1\nend function\nfunction sample() -> Integer uses File.Read[\"/data/a\"]\n"
    );
    for i in 0..count {
        let body = if i == 0 {
            "f()".to_owned()
        } else {
            format!("run{}(f)", i - 1)
        };
        writeln!(source, " bind run{i} <- lambda(f)\n  return handle {body} with\n  {READ_CLAUSES}\n  end handle\n end lambda").unwrap();
    }
    writeln!(source, " return handle tick() with\n case tick() -> resume(run{}(protected))\n end handle\nend function", count - 1).unwrap();
    source
}

fn cap(operations: u64, items: u64) -> ScopeLimits {
    ScopeLimits {
        body: ScopeCap { operations, items },
        whole: ScopeCap {
            operations: operations.saturating_mul(100),
            items: items.saturating_mul(100),
        },
    }
}

fn rss_kib() -> Option<u64> {
    let output = std::process::Command::new("ps")
        .args(["-o", "rss=", "-p", &std::process::id().to_string()])
        .output()
        .ok()?;
    String::from_utf8(output.stdout).ok()?.trim().parse().ok()
}

fn measure(label: &str, source: &str, definitions: usize, handlers: usize, limits: ScopeLimits) {
    let directory = std::env::var_os("BENITOITE_SCOPE_MEASURE_DIR");
    if let Some(ref directory) = directory {
        std::fs::create_dir_all(directory).unwrap();
        std::fs::write(
            std::path::Path::new(directory).join(format!("{label}.bnt")),
            source,
        )
        .unwrap();
    }
    let digest: String = Sha256::digest(source.as_bytes())
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect();
    let started = Instant::now();
    let (_, _, output, diagnostics) =
        crate::typeck::test_support::check_files(&[(".bnt", source)], false);
    let check_seconds = started.elapsed().as_secs_f64();
    let errors: Vec<_> = diagnostics.iter().filter(|d| d.is_error()).collect();
    if label == "reach-whole-items" && !errors.is_empty() {
        assert!(
            errors
                .iter()
                .all(|d| d.code == Some(crate::diag::DiagCode::E0208)),
            "{label}: {errors:#?}"
        );
        let record = json!({
            "case": label, "sha256": digest, "source_bytes": source.len(), "definitions": definitions,
            "blocked_before_scope": "parser_depth_1000", "diagnostics": errors.iter().map(|d| &d.message).collect::<Vec<_>>(),
            "typecheck_seconds": check_seconds, "rss_kib_after": rss_kib(), "exit": 0,
        });
        println!("SCOPE_MEASURE {record}");
        if let Some(directory) = directory {
            std::fs::write(
                std::path::Path::new(&directory).join(format!("{label}.json")),
                serde_json::to_vec_pretty(&record).unwrap(),
            )
            .unwrap();
        }
        return;
    }
    assert!(errors.is_empty(), "{label}: {errors:#?}");
    let mut bodies = Vec::new();
    let mut occurrences = 0;
    let mut candidates = Vec::new();
    let mut accepted = 0;
    let mut rejected = Vec::new();
    let narrow = Range::Path(PathPattern::parse("/data/**").unwrap());
    let analysis_started = Instant::now();
    for body in output
        .scope_inputs
        .bodies
        .iter()
        .filter(|b| b.body_key.definition.starts_with(".sample"))
    {
        let local_started = Instant::now();
        let analysis = body.analyze(1_000_000, limits);
        let local_seconds = local_started.elapsed().as_secs_f64();
        occurrences += analysis.input.occurrences.len();
        for call in &analysis.input.calls {
            let ranges = analysis.selected_ranges(call).unwrap();
            assert!(
                analysis.accept_call(call, &ranges).is_ok(),
                "{label}: selected ranges rejected"
            );
            accepted += 1;
            if let Err(ScopeAcceptError::Rejected(reason)) =
                analysis.accept_call(call, std::slice::from_ref(&narrow))
            {
                rejected.push(format!(
                    "{:?}:{}:{:?}",
                    call.declaration, call.preorder, reason.reason
                ));
            }
        }
        let unrestricted;
        let baseline = if analysis.stopped.is_some() {
            unrestricted = body.analyze(DEFAULT_NUMBERING_OPERATIONS, cap(1_000_000, 100_000));
            &unrestricted
        } else {
            &analysis
        };
        // 候補の局所上限と、本番の独立した番号上限で範囲の維持を測る。
        // 候補自身が選んだ列から期待値を作らない。
        for (name, body_operations, body_items, whole_operations, whole_items) in [
            ("small", 128, 8, 512, 32),
            ("middle", 2048, 128, 8192, 512),
            ("large", 16384, 512, 65536, 2048),
        ] {
            let candidate_limits = ScopeLimits {
                body: ScopeCap {
                    operations: body_operations,
                    items: body_items,
                },
                whole: ScopeCap {
                    operations: whole_operations,
                    items: whole_items,
                },
            };
            let candidate = body.analyze_with_limits(candidate_limits);
            let mut lost_ranges = 0;
            let mut failures = Vec::new();
            for call in &baseline.input.calls {
                let original = baseline.selected_ranges(call).unwrap();
                match candidate.selected_ranges(call) {
                    Ok(selected) if selected == original => {}
                    Ok(_) | Err(_) => lost_ranges += 1,
                }
                if let Err(failure) = candidate.accept_call(call, &original) {
                    failures.push(format!(
                        "{:?}:{}:{failure:?}",
                        call.declaration, call.preorder
                    ));
                }
            }
            candidates.push(json!({
                "name": name, "definition": body.body_key.definition,
                "limits": {"body": {"operations": body_operations, "items": body_items}, "whole": {"operations": whole_operations, "items": whole_items}},
                "numbering_operations": candidate.input.numbering_operations,
                "numbering_stopped": format!("{:?}", candidate.input.stopped),
                "local_stopped": format!("{:?}", candidate.stopped),
                "stops": candidate.metrics.stops.iter().map(|(position, reason)| json!({"preorder": position, "reason": format!("{reason:?}")})).collect::<Vec<_>>(),
                "lost_ranges": lost_ranges, "rejections": failures,
            }));
        }
        let mut numbering_candidates = Vec::new();
        for limit in [100_000, 200_000, 300_000] {
            let mut seconds = Vec::new();
            let mut numbered = None;
            for _ in 0..5 {
                let started = Instant::now();
                let current = body.numbered(limit);
                seconds.push(started.elapsed().as_secs_f64());
                numbered = Some(current);
            }
            let numbered = numbered.unwrap();
            seconds.sort_by(f64::total_cmp);
            numbering_candidates.push(json!({
                "limit": limit, "events": numbered.numbering_operations,
                "stopped": format!("{:?}", numbered.stopped),
                "numbering_seconds_median": seconds[2], "samples_seconds": seconds,
            }));
        }
        bodies.push(json!({
            "numbering_candidates": numbering_candidates,
            "numbering_and_local_seconds": local_seconds,
            "definition": body.body_key.definition,
            "occurrences": analysis.input.occurrences.len(),
            "numbering_operations": analysis.input.numbering_operations,
            "calls": analysis.input.calls.len(),
            "metrics": {
                "body_operations": analysis.metrics.body_operations,
                "whole_operations": analysis.metrics.whole_operations,
                "max_body_items": analysis.metrics.max_body_items,
                "max_whole_items": analysis.metrics.max_whole_items,
                "stops": analysis.metrics.stops.iter().map(|(position, reason)| json!({"preorder": position, "reason": format!("{reason:?}")})).collect::<Vec<_>>(),
            },
            "stopped": format!("{:?}", analysis.stopped),
        }));
    }
    let record = json!({
        "case": label, "configuration": if cfg!(feature = "gc-stress") { "gc-stress" } else if cfg!(feature = "heap-verify") { "heap-verify" } else { "release-default" },
        "sha256": digest, "source_bytes": source.len(), "definitions": definitions,
        "handlers": handlers, "handler_reinferences": output.handler_reinferences, "occurrences": occurrences,
        "limits": {"body": {"operations": limits.body.operations, "items": limits.body.items}, "whole": {"operations": limits.whole.operations, "items": limits.whole.items}},
        "body_operations_max": bodies.iter().filter_map(|b| b["metrics"]["body_operations"].as_u64()).max().unwrap_or(0),
        "whole_operations_total": bodies.iter().filter_map(|b| b["metrics"]["whole_operations"].as_u64()).sum::<u64>(),
        "body_items_max": bodies.iter().filter_map(|b| b["metrics"]["max_body_items"].as_u64()).max().unwrap_or(0),
        "whole_items_max": bodies.iter().filter_map(|b| b["metrics"]["max_whole_items"].as_u64()).max().unwrap_or(0),
        "accepted_selected_calls": accepted, "narrow_rejections": rejected,
        "typecheck_seconds": check_seconds, "scope_analysis_and_candidates_seconds": analysis_started.elapsed().as_secs_f64(),
        "rss_kib_after": rss_kib(), "rss_method": "ps RSS after input in KiB; null means unavailable in sandbox; outer per-input runner records process high-water mark",
        "bodies": bodies, "candidates": candidates, "exit": 0,
    });
    println!("SCOPE_MEASURE {record}");
    if let Some(directory) = directory {
        std::fs::write(
            std::path::Path::new(&directory).join(format!("{label}.json")),
            serde_json::to_vec_pretty(&record).unwrap(),
        )
        .unwrap();
    }
}

pub(super) fn run() {
    let counts: &[usize] = if cfg!(feature = "gc-stress") {
        &[1, 2, 3]
    } else {
        &[1, 10, 100]
    };
    let filter = std::env::var("BENITOITE_SCOPE_MEASURE_CASE").ok();
    let mut cases = Vec::new();
    for count in counts {
        cases.push((
            format!("seven-io-{count}"),
            seven_io_source(*count, false),
            *count,
            0,
            cap(1_000_000, 100_000),
        ));
        cases.push((
            format!("seven-io-dense-{count}"),
            seven_io_source(*count, true),
            1,
            0,
            cap(1_000_000, 100_000),
        ));
        cases.push((
            format!("six-{count}"),
            six_source(*count),
            *count,
            0,
            cap(1_000_000, 100_000),
        ));
        cases.push((
            format!("exceeded-{count}"),
            six_source(*count),
            *count,
            0,
            cap(8, 2),
        ));
    }
    for count in counts {
        cases.push((
            format!("dense-{count}"),
            dense_source(*count),
            1,
            0,
            cap(1_000_000, 100_000),
        ));
        cases.push((
            format!("retained-{count}"),
            retained_source(*count),
            1,
            0,
            cap(1_000_000, 100_000),
        ));
    }
    let ordinary_counts: &[usize] = if cfg!(feature = "gc-stress") {
        &[10, 20, 40]
    } else {
        &[500, 1000, 2000, 4000]
    };
    for count in ordinary_counts {
        for conditional in [false, true] {
            cases.push((
                format!(
                    "ordinary-{}-{count}",
                    if conditional { "if" } else { "arithmetic" }
                ),
                ordinary_source(*count, conditional),
                1,
                0,
                cap(1_000_000, 100_000),
            ));
        }
    }
    let scale = if cfg!(feature = "gc-stress") { 10 } else { 1 };
    for (label, source) in [
        ("reach-body-operations", projections_source(1, 6000 / scale)),
        (
            "reach-whole-operations",
            projections_source(44 / scale, 500 / scale),
        ),
        ("reach-body-items", retained_source(513 / scale)),
        ("reach-whole-items", nested_retained_source(5, 512 / scale)),
        (
            "whole-items-under-depth",
            nested_retained_source(3, 300 / scale),
        ),
    ] {
        cases.push((label.to_owned(), source, 1, 0, cap(1_000_000, 100_000)));
    }
    let handler_counts: &[usize] = if cfg!(feature = "gc-stress") {
        &[2, 4, 8]
    } else {
        &[100, 200, 400]
    };
    for count in handler_counts {
        cases.push((
            format!("handlers-sequential-{count}"),
            sequential_handlers(*count),
            1,
            *count,
            cap(1_000_000, 100_000),
        ));
        cases.push((
            format!("handlers-later-{count}"),
            later_handlers(*count, false),
            2,
            *count * 2,
            cap(1_000_000, 100_000),
        ));
        cases.push((
            format!("handlers-reinfer-{count}"),
            later_handlers(*count, true),
            2,
            *count * 2,
            cap(1_000_000, 100_000),
        ));
    }
    let chain_counts: &[usize] = if cfg!(feature = "gc-stress") {
        &[1, 2, 3]
    } else {
        &[1, 10, 40, 400]
    };
    for count in chain_counts {
        cases.push((
            format!("handlers-chain-{count}"),
            handler_chain(*count),
            2,
            *count + 1,
            cap(1_000_000, 100_000),
        ));
    }
    let mut measured = 0;
    for (label, source, definitions, handlers, limits) in cases {
        if filter.as_ref().is_none_or(|selected| *selected == label) {
            measure(&label, &source, definitions, handlers, limits);
            measured += 1;
        }
    }
    assert!(measured > 0, "measurement filter selected no inputs");
}
