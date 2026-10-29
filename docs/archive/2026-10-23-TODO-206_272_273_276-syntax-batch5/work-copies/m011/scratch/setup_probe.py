"""F0 の局所コピーだけへ接続試作を適用する。"""
from pathlib import Path
import difflib
import shutil

HERE = Path(__file__).resolve().parent
BASE = HERE / 'baseline/crates/benitoite'
DEST = HERE / 'prototype/crates/benitoite'
shutil.copytree(BASE/'src', DEST/'src', dirs_exist_ok=True)

def change(name, old, new, count=1):
    p = DEST / 'src/syntax' / name
    text = p.read_text()
    assert old in text, (name, old[:60])
    p.write_text(text.replace(old, new, count))

# 数の診断だけを字句段で保留する。BadSymbol は元から parser が報告する。
change('lexer.rs', '    pub diagnostics: Vec<Diagnostic>,', '''    pub diagnostics: Vec<Diagnostic>,
    pub pending: Vec<(BytePos, Diagnostic)>,''')
change('lexer.rs', '        line_limit: None,', '''        line_limit: None,
        active_interp: None,
        pending: Vec::new(),''')
change('lexer.rs', '        diagnostics: lexer.diagnostics,', '''        diagnostics: lexer.diagnostics,
        pending: lexer.pending,''')
change('lexer.rs', "struct Lexer<'a> {", """struct Lexer<'a> {
    active_interp: Option<BytePos>,
    pending: Vec<(BytePos, Diagnostic)>,""")
change('lexer.rs', '                self.report(builder);\n                self.push(TokenKind::Error, start, end, TokenValue::None);', '''                if let Some(id) = self.active_interp {
                    self.pending.push((id, builder.build()));
                } else {
                    self.report(builder);
                }
                self.push(TokenKind::Error, start, end, TokenValue::None);''')
change('lexer/string.rs', '        while let Some(mut frame) = stack.pop() {', '''        while let Some(mut frame) = stack.pop() {
            self.active_interp = None;''')
change('lexer/string.rs', '                            i = self.step(i);', '''                            self.active_interp = Some(byte_pos(expr));
                            i = self.step(i);
                            self.active_interp = None;''')

# 既存の公開 parse は旧読者用に保ち、試行入口だけが保留列を受け取る。
change('parser/mod.rs', '    pub comments: Vec<Comment>,\n', '''    pub comments: Vec<Comment>,
    pub formats: Vec<(BytePos, Span)>,
''')
needle = '    let mut parser = Parser::new(file, kind, text, tokens, &comments, std::mem::take(ids));'
change('parser/mod.rs', needle, '''    parse_deferred(file, kind, text, tokens, comments, ids, Vec::new())
}

pub fn parse_deferred(
    file: FileId, kind: SourceKind, text: &[u8], tokens: Vec<Token>,
    comments: Vec<Comment>, ids: &mut IdGen,
    pending: Vec<(BytePos, Diagnostic)>,
) -> ParseOutput {
''' + needle)
change('parser/mod.rs', '    let diagnostics = std::mem::take(&mut parser.diagnostics);', '''    let confirmed: std::collections::BTreeMap<_, _> = parser.formats.iter().copied().collect();
    for (id, d) in pending {
        if !confirmed.get(&id).is_some_and(|range|
            d.primary.as_ref().is_some_and(|l| range.start <= l.span.start && l.span.end <= range.end)) {
            parser.diagnostics.push(d);
        }
    }
    let formats = std::mem::take(&mut parser.formats);
    let diagnostics = std::mem::take(&mut parser.diagnostics);''')
change('parser/mod.rs', '    ParseOutput {\n        module,', '    ParseOutput {\n        formats,\n        module,')
change('parser/mod.rs', "pub(super) struct Parser<'a> {", """pub(super) struct Parser<'a> {
    pub(super) formats: Vec<(BytePos, Span)>,
    pub(super) interp_depth: usize,""")
change('parser/mod.rs', '        Self {\n            lambda_bounds,', '''        Self {
            formats: Vec::new(), interp_depth: 0,
            lambda_bounds,''')
change('parser/interp.rs', '        let expr = match exprs::parse_expr(p, nth_child(depth, segments.len())) {', '''        p.interp_depth += 1;
        let parsed = exprs::parse_expr(p, nth_child(depth, segments.len()));
        p.interp_depth -= 1;
        let expr = match parsed {''')
change('parser/interp.rs', '        if !matches!(p.peek_kind(), TokenKind::StrMid | TokenKind::StrEnd) {', '''        if p.at(TokenKind::Colon) {
            let begin = p.peek().span.start;
            let mut nested = 0usize;
            while !p.at(TokenKind::Eof) {
                let kind = p.peek_kind();
                if nested == 0 && matches!(kind, TokenKind::StrMid | TokenKind::StrEnd) { break; }
                if kind == TokenKind::StrStart { nested += 1; }
                if kind == TokenKind::StrEnd { nested = nested.saturating_sub(1); }
                // advance は BadSymbol を報告するので、確定した範囲だけ直接読み飛ばす。
                p.pos += 1;
            }
            if matches!(p.peek_kind(), TokenKind::StrMid | TokenKind::StrEnd) {
                p.formats.push((BytePos(opening.end.0.saturating_sub(2)), Span {
                    file: p.file, start: begin, end: p.peek().span.start,
                }));
            }
        }
        if !matches!(p.peek_kind(), TokenKind::StrMid | TokenKind::StrEnd) {''')
change('parser/exprs.rs', '    if same_line\n        && !block_end', '''    if same_line
        && !(p.interp_depth > 0 && p.at(TokenKind::Colon))
        && !block_end''')

# 同一行のラムダは一文を通常の文法で読み、その直後の明示終端を確定する。
# 書式の誤り ':end lambda' を本体の終端候補とする事前分類を使わない。
change('parser/exprs.rs', '    let explicit = bound.is_none_or(|b| b.explicit);', '''    let header_line = p.tokens.get(p.pos.saturating_sub(1)).map_or(first_line, |t| t.end_line);
    let explicit = bound.is_none_or(|b| b.explicit && b.line > header_line);''')
change('parser/exprs.rs', '    let ending = if explicit {', '''    let same_line_end = !explicit && p.at(TokenKind::KwEnd)
        && p.peek_nth_kind(1) == TokenKind::KwLambda
        && p.peek().start_line == header_line;
    if same_line_end { p.open_block(TokenKind::KwLambda, opened); }
    let ending = if explicit || same_line_end {''')

# 外側の旧式の先読みは、文字列全体を飛ばした後も本物の ':' を探す。
for name, start in [('parser/foreign.rs', 'p.pos.saturating_add(1)'), ('parser/exprs.rs', 'p.pos.saturating_add(2)')]:
    change(name, f'    let mut nesting = 0_u32;\n    for token in p.tokens.get({start}..).unwrap_or_default() {{', f'''    let mut nesting = 0_u32;
    let mut strings = 0usize;
    for token in p.tokens.get({start}..).unwrap_or_default() {{
        if token.kind == TokenKind::StrStart {{ strings += 1; continue; }}
        if strings > 0 {{
            if token.kind == TokenKind::StrEnd {{ strings -= 1; }}
            continue;
        }}
        if matches!(token.kind, TokenKind::StrMid | TokenKind::StrEnd) {{ return false; }}''')

# 改行判定の式の状態を、文字列の入れ子の前後で保存・復帰する。
change('newline.rs', '    let mut input = tokens.iter().peekable();', '''    let mut strings = Vec::new();
    let mut input = tokens.iter().peekable();''')
change('newline.rs', '        let kind = token.kind;', '''        let kind = token.kind;
        if kind == K::StrStart {
            strings.push((std::mem::take(&mut stack), depth,
                std::mem::take(&mut die_message_depths)));
            depth = 0;
            previous = None;
            previous_ends_die = false;
            previous_is_end_word = false;
            output.push(token);
            continue;
        }
        if matches!(kind, K::StrMid | K::StrEnd) {
            stack.clear(); depth = 0; die_message_depths.clear();
            previous = None; previous_ends_die = false; previous_is_end_word = false;
            if kind == K::StrEnd {
                if let Some((saved, saved_depth, saved_die)) = strings.pop() {
                    stack = saved; depth = saved_depth; die_message_depths = saved_die;
                }
                previous = Some(K::StringLit);
            }
            output.push(token);
            continue;
        }''')

# ラムダ境界の対応表も、入れ子の文字列内の未対応の区切りから外側を保護する。
change('lambda_bounds.rs', '    for (i, t) in ts.iter().enumerate() {', '''    let mut strings = Vec::new();
    for (i, t) in ts.iter().enumerate() {
        if t.kind == K::StrStart {
            strings.push(std::mem::take(&mut stack));
            stack.push((K::StrStart, i, None));
            continue;
        }
        if t.kind == K::StrMid {
            if let Some(open) = stack.first().copied().filter(|o| o.0 == K::StrStart) {
                stack.clear(); stack.push(open);
            }
            continue;
        }
        if t.kind == K::StrEnd {
            if let Some(open) = stack.first().filter(|o| o.0 == K::StrStart) {
                pairs.insert(open.1, i.saturating_add(1));
            }
            if let Some(saved) = strings.pop() { stack = saved; }
            continue;
        }''')
patch = []
for p in sorted((DEST/'src/syntax').rglob('*.rs')):
    rel=p.relative_to(DEST)
    old=(BASE/rel).read_text(); new=p.read_text()
    if old != new:
        patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+str(rel),tofile='b/'+str(rel)))
(HERE/'prototype.patch').write_text(''.join(patch))
print('prototype patch saved')
