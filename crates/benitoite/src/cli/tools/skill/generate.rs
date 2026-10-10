//! 同梱の Agent Skill の参照の文書の生成（設計書 06-06「同梱の Agent Skill の構成」）。
//! 生成の道具（`examples/gen_skill.rs`）と、生成物が古くないことのテスト（`tests/skill_docs.rs`）が呼ぶ。
//!
//! 生成物は、構文の章・標準ライブラリのソース・診断の表だけから決まる。実行の日時や環境を読まない（設計書 06-06「同梱の Agent Skill の構成」）。

use crate::base::{FileId, IdGen, SourceKind, Span};
use crate::diag::codes::ALL;
use crate::diag::{ReportKind, Severity};
use crate::modules::StdlibModuleSource;
use crate::prelude::STDLIB;
use crate::syntax::ast::{Item, TopDecl};
use crate::syntax::lexer::lex;
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::parse;

/// 生成する文書一つ。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct GeneratedFile {
    /// Skill の中のパス（`references/grammar.md` など）
    pub path: String,
    pub text: String,
}

/// 生成物の見出しと固定の文（06-06 により生成物の本文は英語）。
mod text {
    pub const GRAMMAR_HEADING: &str = "初回リリース版の文法の全体";
    pub const GRAMMAR_TITLE: &str = "# Benitoite grammar";
    pub const GRAMMAR_INTRO: &str = "The complete grammar of Benitoite in EBNF. \
`{ ... }` means zero or more repetitions, `[ ... ]` means optional, and `|` separates alternatives. \
`NL` is a line break that separates items. `CommaList(X)` is a comma-separated list of `X` that may be \
empty and may end with a comma; `LineList(X)` is a list of `X` separated by line breaks.";
    pub const DIAG_TITLE: &str = "# Benitoite diagnostic codes";
    pub const DIAG_INTRO: &str = "Each diagnostic code with its message template and explanation. \
Words in braces such as `{name}` are filled in when the diagnostic is reported.";
    pub const INDEX_TITLE: &str = "# Benitoite standard library";
    pub const INDEX_INTRO: &str = "The modules of the standard library. Each module has its own file \
in this directory. Unofficial modules may change; their import name changes when they become standard.";
    pub const INDEX_HEADER: &str = "| Module | Status | Import | Description |\n|---|---|---|---|";
    pub const STATUS_PRELUDE: &str = "standard (prelude)";
    pub const STATUS_STANDARD: &str = "standard";
    pub const STATUS_UNOFFICIAL: &str = "unofficial";
    pub const IMPORT_NONE: &str = "not needed";
    pub const LINE_PRELUDE: &str =
        "Status: standard, in the prelude. It can be used without `import`.";
    pub const LINE_STANDARD: &str = "Status: standard. Import it with `import Benitoite.{name}`.";
    pub const LINE_UNOFFICIAL: &str = "Status: unofficial. Import it with \
`import Benitoite.Unofficial.{name}`. When the module becomes standard, the import name changes to \
`import Benitoite.{name}`.";
    pub const LINE_QUALIFY: &str =
        "Refer to its declarations as `{last}.<name>`, for example `{last}.{example}`.";
    pub const KIND_CHECK: &str = "check";
    pub const KIND_LIMIT: &str = "limit";
    pub const KIND_RUNTIME: &str = "runtime";
    pub const KIND_RESOURCE: &str = "resource";
    pub const KIND_RELEASE: &str = "release";
    pub const KIND_ARGS: &str = "args";
    pub const KIND_INTERNAL: &str = "internal";
    pub const SEVERITY_ERROR: &str = "error";
    pub const SEVERITY_WARNING: &str = "warning";
    pub const DIAG_KIND: &str = "- Kind:";
    pub const DIAG_MESSAGE: &str = "- Message:";
    pub const DIAG_LABEL: &str = "- Label:";
    pub const CODE_FENCE: &str = "```benitoite";
    pub const BUNDLE_HEADER: &str =
        "//! 同梱の Agent Skill の埋め込みの一覧（設計書 06-06「同梱の Agent Skill の構成」）。
//! 生成の道具（`cargo run -p benitoite --example gen_skill`）が書いたファイルであり、手で直さない。

use super::SkillFile;

/// Skill のすべてのファイル。`path` は Skill の中のパスである。
";
    pub const NO_GRAMMAR_HEADING: &str =
        "the syntax chapter has no heading `初回リリース版の文法の全体`";
    pub const NO_GRAMMAR_BLOCK: &str =
        "the grammar section of the syntax chapter has no code block";
    pub const PARSE_FAILED: &str = "cannot parse the standard library source";
}

/// 生成できる参照の文書をすべて作る。`syntax_chapter` は設計書の構文の章（01-02）の Markdown の全文である。
/// 章から文法の節のコードブロックを見つけられないとき、標準ライブラリのソースを構文解析できないときは、理由を返す。
pub fn generate_references(syntax_chapter: &str) -> Result<Vec<GeneratedFile>, String> {
    let mut files = vec![
        GeneratedFile {
            path: "references/grammar.md".to_string(),
            text: grammar(syntax_chapter)?,
        },
        GeneratedFile {
            path: "references/diagnostics.md".to_string(),
            text: diagnostics(),
        },
    ];
    let mut index = format!(
        "{}\n\n{}\n\n{}\n",
        text::INDEX_TITLE,
        text::INDEX_INTRO,
        text::INDEX_HEADER
    );
    for module in STDLIB {
        let name = module.path.join(".");
        let (doc, body) = module_reference(module, &name)?;
        let (status, import) = if module.unofficial {
            (
                text::STATUS_UNOFFICIAL,
                format!("`import Benitoite.Unofficial.{name}`"),
            )
        } else if module.prelude {
            (text::STATUS_PRELUDE, text::IMPORT_NONE.to_string())
        } else {
            (text::STATUS_STANDARD, format!("`import Benitoite.{name}`"))
        };
        index.push_str(&format!(
            "| [{name}]({name}.md) | {status} | {import} | {} |\n",
            first_sentence(&doc)
        ));
        files.push(GeneratedFile {
            path: format!("references/stdlib/{name}.md"),
            text: body,
        });
    }
    files.push(GeneratedFile {
        path: "references/stdlib/index.md".to_string(),
        text: index,
    });
    files.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(files)
}

/// 構文の章の「初回リリース版の文法の全体」の節の最初のコードブロックから、日本語の注釈を除いた文法を作る。
fn grammar(chapter: &str) -> Result<String, String> {
    let mut lines = chapter.lines();
    let heading_found = lines.any(|line| {
        line.starts_with('#') && line.trim_start_matches('#').trim() == text::GRAMMAR_HEADING
    });
    if !heading_found {
        return Err(text::NO_GRAMMAR_HEADING.to_string());
    }
    // 節の終わり（次の見出し）までに最初のコードブロックを探す。
    let mut in_block = false;
    let mut found = false;
    let mut rules = String::new();
    for line in lines {
        if in_block {
            if line.trim_start().starts_with("```") {
                found = true;
                break;
            }
            let stripped = strip_comments(line);
            if stripped.trim().is_empty() && !line.trim().is_empty() {
                continue;
            }
            rules.push_str(stripped.trim_end());
            rules.push('\n');
        } else if line.trim_start().starts_with("```") {
            in_block = true;
        } else if line.starts_with('#') {
            break;
        }
    }
    if !found {
        return Err(text::NO_GRAMMAR_BLOCK.to_string());
    }
    let rules = rules.trim_matches('\n');
    Ok(format!(
        "{}\n\n{}\n\n```text\n{rules}\n```\n",
        text::GRAMMAR_TITLE,
        text::GRAMMAR_INTRO
    ))
}

/// 一行から `(* … *)` の注釈を除く。注釈は入れ子にならない前提とする（D20「手順の要点」の 1）。
fn strip_comments(line: &str) -> String {
    let mut out = String::new();
    let mut rest = line;
    while let Some(start) = rest.find("(*") {
        out.push_str(rest.get(..start).unwrap_or(""));
        let after = rest.get(start..).unwrap_or("");
        rest = match after.find("*)") {
            Some(end) => after.get(end..).and_then(|s| s.get(2..)).unwrap_or(""),
            None => "",
        };
    }
    out.push_str(rest);
    out
}

/// 診断コードの説明（`codes::ALL` の順）。
fn diagnostics() -> String {
    let mut out = format!("{}\n\n{}\n", text::DIAG_TITLE, text::DIAG_INTRO);
    for code in ALL {
        let info = code.info();
        let kind = match info.kind {
            ReportKind::Check => text::KIND_CHECK,
            ReportKind::Limit => text::KIND_LIMIT,
            ReportKind::Runtime => text::KIND_RUNTIME,
            ReportKind::Resource => text::KIND_RESOURCE,
            ReportKind::Release => text::KIND_RELEASE,
            ReportKind::Args => text::KIND_ARGS,
            ReportKind::Internal => text::KIND_INTERNAL,
        };
        let severity = match info.severity {
            Severity::Error => text::SEVERITY_ERROR,
            Severity::Warning => text::SEVERITY_WARNING,
        };
        out.push_str(&format!(
            "\n## {}\n\n{} {kind} ({severity})\n{} {}\n",
            info.id,
            text::DIAG_KIND,
            text::DIAG_MESSAGE,
            info.message
        ));
        if !info.label.is_empty() {
            out.push_str(&format!("{} {}\n", text::DIAG_LABEL, info.label));
        }
        for (key, template) in info.extras {
            out.push_str(&format!("- `{key}`: {template}\n"));
        }
        if !info.explanation.is_empty() {
            out.push_str(&format!("\n{}\n", info.explanation));
        }
    }
    out
}

/// モジュール一つのリファレンス。モジュールの説明と、リファレンスの本文を返す。
fn module_reference(module: &StdlibModuleSource, name: &str) -> Result<(String, String), String> {
    let source = module.text.as_bytes();
    let file = FileId(0);
    let lexed = lex(file, source);
    let parsed = parse(
        file,
        SourceKind::Prelude,
        source,
        resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut IdGen::new(),
    );
    if !lexed.diagnostics.is_empty() || !parsed.diagnostics.is_empty() {
        return Err(format!("{}: {name}", text::PARSE_FAILED));
    }
    let doc = parsed
        .module
        .doc
        .as_ref()
        .map(|d| doc_text(&d.text))
        .unwrap_or_default();
    let status = if module.unofficial {
        text::LINE_UNOFFICIAL
    } else if module.prelude {
        text::LINE_PRELUDE
    } else {
        text::LINE_STANDARD
    };
    let mut out = format!("# Benitoite.{name}\n\n{}\n", status.replace("{name}", name));
    // prelude の関数も修飾して使い、非公式のモジュールも名前の最後の要素で修飾する（01-03）。
    let example = parsed
        .module
        .decls
        .iter()
        .filter(|d| d.public.is_some())
        .find_map(|d| decl_name(&d.item));
    if let Some(example) = example {
        let last = module.path.last().copied().unwrap_or(name);
        out.push_str(&format!(
            "\n{}\n",
            text::LINE_QUALIFY
                .replace("{last}", last)
                .replace("{example}", example)
        ));
    }
    if !doc.is_empty() {
        out.push_str(&format!("\n{doc}\n"));
    }
    for decl in &parsed.module.decls {
        let Some(public) = decl.public else {
            continue;
        };
        let Some(head) = decl_head(module.text, public, decl) else {
            return Err(format!("{}: {name}", text::PARSE_FAILED));
        };
        out.push_str(&format!("\n{}\n{head}\n```\n", text::CODE_FENCE));
        if let Some(doc) = &decl.doc {
            out.push_str(&format!("\n{}\n", doc_text(&doc.text)));
        }
    }
    Ok((doc, out))
}

/// 宣言の頭をソースのとおりに切り出す。`public` から始めるので、その前の `@builtin` などの属性の行は含まない。
/// 関数は戻りの型（`uses` があればその終わり）までとし、本体を除く。定数は型までとし、右辺を除く。
/// 型・エフェクト・型クラスは、構成子・操作・メソッドの宣言を含む宣言の全体とする（10-19「Skill のファイルの置き場所」）。
fn decl_head(source: &str, public: Span, decl: &TopDecl) -> Option<String> {
    let end = match &decl.item {
        Item::Fn(f) => match &f.uses {
            Some(uses) => uses.span.end,
            None => f.ret.span().end,
        },
        Item::Const(c) => c.ty.span().end,
        Item::Data(d) => d.span.end,
        Item::Alias(a) => a.span.end,
        Item::Record(r) => r.span.end,
        Item::Trait(t) => t.span.end,
        Item::Effect(e) => e.span.end,
        Item::Impl(_) | Item::Error(_) => return None,
    };
    let start = usize::try_from(public.start.0).ok()?;
    let end = usize::try_from(end.0).ok()?;
    Some(source.get(start..end)?.trim_end().to_string())
}

/// 宣言の名前（修飾の例に使う）。
fn decl_name(item: &Item) -> Option<&str> {
    let name = match item {
        Item::Fn(f) => &f.name,
        Item::Const(c) => &c.name,
        Item::Data(d) => &d.name,
        Item::Alias(a) => &a.name,
        Item::Record(r) => &r.name,
        Item::Trait(t) => &t.name,
        Item::Effect(e) => &e.name,
        Item::Impl(_) | Item::Error(_) => return None,
    };
    Some(&name.text)
}

/// ドキュメントコメントの本文。各行の先頭の空白（`/// ` の後の空白）を除く。
fn doc_text(text: &str) -> String {
    text.lines()
        .map(str::trim_start)
        .collect::<Vec<_>>()
        .join("\n")
        .trim()
        .to_string()
}

/// 説明の最初の文。改行を空白にし、逆引用符の外にある最初の「. 」までとする。表の区切りの `|` は逃がす。
fn first_sentence(doc: &str) -> String {
    let flat = doc.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut in_code = false;
    let mut cut = None;
    let mut chars = flat.char_indices().peekable();
    while let Some((pos, c)) = chars.next() {
        if c == '`' {
            in_code = !in_code;
        } else if c == '.' && !in_code && chars.peek().is_some_and(|&(_, n)| n == ' ') {
            cut = Some(pos);
            break;
        }
    }
    let sentence = match cut {
        Some(pos) => flat.get(..=pos).unwrap_or(&flat).to_string(),
        None => flat.clone(),
    };
    sentence.replace('|', "\\|")
}

/// 埋め込みの一覧 `bundle.rs` の Rust のソースを作る。`paths` は Skill の中のパスの並び（手で書く文書と生成物と
/// ライセンス文）で、この順に `FILES` に並べる。書く前に rustfmt の書き方に揃えた文字列を返す。
pub fn bundle_source(paths: &[String]) -> String {
    let mut out = String::from(text::BUNDLE_HEADER);
    if paths.is_empty() {
        out.push_str("pub const FILES: &[SkillFile] = &[];\n");
        return out;
    }
    out.push_str("pub const FILES: &[SkillFile] = &[\n");
    for path in paths {
        // ライセンス文はリポジトリの根に、ほかは処理系のクレートの `skill/` に置く（10-19「Skill のファイルの置き場所」）。
        let source = if path.starts_with("LICENSE") {
            format!("../../../../../../{path}")
        } else {
            format!("../../../../skill/{path}")
        };
        out.push_str(&format!(
            "    SkillFile {{\n        path: \"{path}\",\n        text: include_str!(\"{source}\"),\n    }},\n"
        ));
    }
    out.push_str("];\n");
    out
}

#[cfg(test)]
// テストの失敗は panic で表す（実装プラン 00-02「`#[allow]` を書いてよい箇所」）。
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn first_sentence_ignores_periods_inside_backticks() {
        assert_eq!(
            first_sentence("Values made with `lazy ... end lazy`. The type is shared."),
            "Values made with `lazy ... end lazy`."
        );
        assert_eq!(first_sentence("One. Two."), "One.");
        assert_eq!(first_sentence("a | b"), "a \\| b");
    }

    #[test]
    fn doc_lines_lose_leading_spaces() {
        assert_eq!(doc_text(" One\n two"), "One\ntwo");
    }

    #[test]
    fn grammar_without_heading_is_an_error() {
        assert!(generate_references("# 構文\n\n```text\nA = B .\n```\n").is_err());
    }

    #[test]
    fn grammar_heading_without_block_is_an_error() {
        let chapter = "### 初回リリース版の文法の全体\n\ntext\n\n### 次\n\n```text\nA = B .\n```\n";
        assert!(generate_references(chapter).is_err());
    }

    #[test]
    fn comments_and_lines_left_empty_are_removed() {
        let chapter = "### 初回リリース版の文法の全体\n\n```text\n(* 注釈 *)\nA = B . (* 説明 *)\n\nC = D .\n```\n";
        let files = generate_references(chapter).unwrap();
        let grammar = files
            .iter()
            .find(|f| f.path == "references/grammar.md")
            .unwrap();
        assert!(grammar.text.contains("```text\nA = B .\n\nC = D .\n```"));
    }
}
