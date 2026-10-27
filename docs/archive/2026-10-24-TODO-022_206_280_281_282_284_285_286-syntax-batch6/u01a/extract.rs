//! U01a の入力アダプタ。既存の doc 抽出器を使い、検査・実行は行わない。
use benitoite::base::{FileId, IdGen, SourceKind};
use benitoite::cli::tools::doc_examples::{self, Expectation, Format};
use benitoite::syntax::{lexer, newline, parser};
use serde_json::{Value, json};
use std::{fs, path::Path};

fn expectation(e: &Expectation) -> Value {
    match e {
        Expectation::Run {
            stdout,
            stderr,
            exit,
        } => json!({"mode":"run","stdout":stdout,"stderr":stderr,"exit":exit}),
        Expectation::Static => json!({"mode":"check"}),
        Expectation::Test => json!({"mode":"test"}),
        Expectation::Error { lines } => json!({"mode":"error","lines":lines}),
    }
}

fn main() {
    for module in benitoite::prelude::STDLIB {
        let name = format!(
            "Benitoite.{}{}",
            if module.unofficial { "Unofficial." } else { "" },
            module.path.join(".")
        );
        println!(
            "{}",
            json!({"kind":"standardModule","name":name,"path":module.path,"prelude":module.prelude})
        );
    }
    let list = std::env::args().nth(1).expect("host list");
    let hosts: Vec<String> = serde_json::from_slice(&fs::read(list).unwrap()).unwrap();
    for host in hosts {
        let text = match fs::read_to_string(&host) {
            Ok(text) => text,
            Err(_) => {
                println!(
                    "{}",
                    json!({"kind":"extractionError","host":host,"errors":"non-UTF-8 input"})
                );
                continue;
            }
        };
        if Path::new(&host).extension().is_some_and(|s| s == "bnt") {
            let kind = if host.contains("/src/prelude/") {
                SourceKind::Prelude
            } else {
                SourceKind::User
            };
            let lexed = lexer::lex(FileId(0), text.as_bytes());
            let parsed = parser::parse(
                FileId(0),
                kind,
                text.as_bytes(),
                newline::resolve_newlines(lexed.tokens),
                lexed.comments,
                lexed.pending,
                &mut IdGen::default(),
            );
            match doc_examples::extract(&parsed.module) {
                Ok(extracted) => {
                    println!(
                        "{}",
                        json!({"kind":"extraction","host":host,"examples":extracted.examples.len(),"ignored":extracted.ignored_blocks})
                    );
                    for (index, example) in extracted.examples.iter().enumerate() {
                        let start = usize::try_from(example.span.start.0).unwrap();
                        let line = text[..start].bytes().filter(|b| *b == b'\n').count() + 1;
                        println!(
                            "{}",
                            json!({"kind":"example","host":host,"index":index,"line":line,"source":example.source,"files":[],"expectation":expectation(&example.expectation)})
                        );
                    }
                }
                Err(errors) => println!(
                    "{}",
                    json!({"kind":"extractionError","host":host,"errors":format!("{errors:?}")})
                ),
            }
        } else {
            let blocks = match doc_examples::blocks(&text) {
                Ok(blocks) => blocks,
                Err(error) => {
                    println!(
                        "{}",
                        json!({"kind":"extractionError","host":host,"errors":error.reason})
                    );
                    continue;
                }
            };
            let mut index = 0;
            let mut files = Vec::new();
            while index < blocks.len() {
                if blocks[index].info == "files" {
                    let (first, body) = blocks[index]
                        .body
                        .split_once('\n')
                        .unwrap_or((&blocks[index].body, ""));
                    if let Some(name) = first.strip_prefix("name: ") {
                        files.push(json!({"name":name,"source":body}));
                    }
                    index += 1;
                    continue;
                }
                match doc_examples::example(&blocks, index, Format::Markdown) {
                    Ok(Some((example, next))) => {
                        println!(
                            "{}",
                            json!({"kind":"example","host":host,"index":index,"line":example.line,"source":example.source,"files":files,"expectation":expectation(&example.expectation)})
                        );
                        files.clear();
                        index = next;
                    }
                    Ok(None) => index += 1,
                    Err(error) => {
                        // 生成参照のシグネチャには実行の期待値がない。本文を捨てず別分類する。
                        let kind = if host.contains("/skill/references/stdlib/") {
                            "nonExecutableFence"
                        } else {
                            "extractionError"
                        };
                        println!(
                            "{}",
                            json!({"kind":kind,"host":host,"line":blocks[index].line,"source":blocks[index].body,"errors":error.reason})
                        );
                        index += 1;
                    }
                }
            }
        }
    }
}
