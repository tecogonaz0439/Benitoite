//! 制約の最適化を六つの Lean 入口へ接続する局所書き出し（設計書 07-04）。
use super::*;

// 関門: 検査済みの実ソースの型・行・辞書番号と脱糖を独立した Lean の規則へ渡す。
// 既存の全件書き出しは通常 work では実行しないため、接続を少数の入力で守る。
// 公開の段と既存の書き出しだけを用い、本番の差し込み口を追加しない。
#[test]
fn export_batch3_solve() {
    export_batch3(
        "t3",
        &[
            ("higher-order", include_str!("batch3/higher-order.bnt")),
            ("super-paths", include_str!("batch3/super-paths.bnt")),
            ("failure", include_str!("batch3/failure.bnt")),
        ],
    );
}

// 二引数の型構成子を、種類の受理だけでなく辞書とコアの交換まで通す。
#[test]
fn export_batch3_monad2() {
    export_batch3(
        "m1",
        &[
            (
                "binary-minimal",
                include_str!("../../testdata/traits/monad2-minimal.bnt"),
            ),
            (
                "result",
                include_str!("../../testdata/traits/monad2-result.bnt"),
            ),
            (
                "user-result",
                include_str!("../../testdata/traits/monad2-user.bnt"),
            ),
        ],
    );
}

// Scopeの追加拒否を通った通常Call/Resultが、既存の型・脱糖の交換へ渡る契約。
// 実行時の期待値はruntime_builtinsが持ち、ここでは交換とコア型検査の接続だけを守る。
#[test]
fn export_batch3_scope() {
    export_batch3("k3", &[("scope", include_str!("batch3/scope.bnt"))]);
}

// 関門: 定数のErrorを含むRangeのCall/Resultと射影・再検査が交換の対象内に残る。
// 実行結果はCLIのgoldenで守り、ここでは型付き表層とコア検査の接続を確かめる。
#[test]
fn export_batch3_range() {
    export_batch3("k4", &[("range", include_str!("batch3/range.bnt"))]);
}

// 交換の持ち主で、専用情報・通常束縛・辞書・継続を同じ番号空間へ通す。
// 既存の VM テストには交換の読捨てを検出する期待値がない。
#[test]
fn export_batch3_builders() {
    export_batch3(
        "b3",
        &[
            ("higher-order", include_str!("batch3/higher-order.bnt")),
            ("super-paths", include_str!("batch3/super-paths.bnt")),
            ("failure", include_str!("batch3/failure.bnt")),
            (
                "binary-minimal",
                include_str!("../../testdata/traits/monad2-minimal.bnt"),
            ),
            (
                "result",
                include_str!("../../testdata/traits/monad2-result.bnt"),
            ),
            (
                "user-result",
                include_str!("../../testdata/traits/monad2-user.bnt"),
            ),
            ("builders", include_str!("batch3/builders.bnt")),
            ("numbering", include_str!("batch3/numbering.bnt")),
            ("control", include_str!("batch3/control.bnt")),
        ],
    );
}

fn export_batch3(directory: &str, sources: &[(&str, &str)]) {
    let output = std::env::var_os("BENITOITE_DESUGAR_DIFF_DIR")
        .map_or_else(
            || Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/formal-batch3"),
            |path| PathBuf::from(path).join("batch3"),
        )
        .join(directory);
    fs::create_dir_all(&output).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut export = named::Export::new();
    for &(name, source) in sources {
        let checked = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        let program = checked.program.as_ref().unwrap();
        let core = pipeline::desugar_checked(program).unwrap();
        assert!(benitoite::ir::check::check_program(&core).is_empty());
        export.push("golden", name, program, &stdlib);
        let input = export.inputs.last().unwrap();
        assert_eq!(input["excluded"], json!([]));
        let definitions = input["definitions"].as_array().unwrap();
        assert!(!definitions.is_empty());
        for definition in definitions {
            assert!(
                definition["scope"].get("inScope").is_some(),
                "{name}: {definition}"
            );
        }
        // 同じ実ソースの実行を、独立期待値を持つ main と参照実行器へ接続する。
        if matches!(
            name,
            "numbering" | "control" | "binary-minimal" | "result" | "user-result"
        ) {
            use benitoite::runtime::io::services::RunInput;
            for mode in [
                benitoite::vm::ExecMode::Direct,
                benitoite::vm::ExecMode::Request,
            ] {
                let checked = pipeline::check_text(
                    name,
                    source.as_bytes(),
                    CheckOptions {
                        require_main: true,
                        deny_warnings: false,
                    },
                );
                let comparison = differential::compare(
                    checked.program.unwrap(),
                    checked.sources,
                    RunInput {
                        arguments: vec![],
                        working_directory: "/".into(),
                        script_directory: "/".into(),
                    },
                    benitoite::vm::VmConfig::default(),
                    mode,
                    differential::CompareOptions {
                        require_returned: true,
                        ..Default::default()
                    },
                    Box::new(|| Ok(())),
                );
                match comparison {
                    differential::Comparison::Matched => {}
                    differential::Comparison::Failed(reason)
                    | differential::Comparison::Excluded(reason) => panic!("{name}: {reason}"),
                }
            }
        }
    }
    write_batch2(&output, export);
}
