"""少数の対照入力と公開 lex/parse 境界を呼ぶ観測器を用意する。"""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
probe=r'''use benitoite::{base::{FileId,IdGen,SourceKind},syntax::{lexer,newline,parser}};
use serde_json::{json,Value};
fn diag(d: &benitoite::diag::Diagnostic, text: &[u8]) -> Value {
    json!({"code":format!("{:?}",d.code),"span":d.primary.as_ref().map(|l| [l.span.start.0,l.span.end.0]),
        "text":d.primary.as_ref().map(|l| String::from_utf8_lossy(text.get(l.span.start.0 as usize..l.span.end.0 as usize).unwrap_or_default()).into_owned())})
}
fn main() {
    for path in std::env::args().skip(1) {
        let src=std::fs::read(&path).unwrap();
        let now=std::time::Instant::now();
        let lx=lexer::lex(FileId(0),&src);
        let lex:Vec<_>=lx.diagnostics.iter().map(|d|diag(d,&src)).collect();
        PENDING
        let tokens=newline::resolve_newlines(lx.tokens);
        let newlines:Vec<_>=tokens.iter().filter(|t|t.kind==benitoite::syntax::token::TokenKind::Newline).map(|t| t.span.start.0).collect();
        let token_view:Vec<_>=tokens.iter().take(160).map(|t|json!([format!("{:?}",t.kind),t.span.start.0,t.span.end.0])).collect();
        let out=PARSE;
        let diagnostics:Vec<_>=out.diagnostics.iter().map(|d|diag(d,&src)).collect();
        let ast=if src.len()<5000 {format!("{:?}",out.module)} else {String::new()};
        let formats=FORMATS;
        println!("{}",json!({"path":path,"lex":lex,"parse":diagnostics,"pending":pending_view,
            "formats":formats,"newlines":newlines,"tokens":token_view,"ast":ast,"elapsed_ms":now.elapsed().as_secs_f64()*1000.0}));
    }
}'''
for variant in ['baseline','prototype']:
    text=probe
    if variant=='baseline':
        text=text.replace('PENDING','let pending_view:Vec<Value>=Vec::new();')
        text=text.replace('PARSE','parser::parse(FileId(0),SourceKind::User,&src,tokens,lx.comments,&mut IdGen::new())')
        text=text.replace('FORMATS','Vec::<Value>::new()')
    else:
        text=text.replace('PENDING','let pending_view:Vec<_>=lx.pending.iter().map(|(id,d)| json!({"id":id.0,"diagnostic":diag(d,&src)})).collect();')
        text=text.replace('PARSE','parser::parse_deferred(FileId(0),SourceKind::User,&src,tokens,lx.comments,&mut IdGen::new(),lx.pending)')
        text=text.replace('FORMATS','out.formats.iter().map(|(id,s)| json!({"id":id.0,"span":[s.start.0,s.end.0],"raw":String::from_utf8_lossy(&src[s.start.0 as usize..s.end.0 as usize])})).collect::<Vec<_>>()')
    dest=HERE/variant/'crates/benitoite/examples/f0_probe.rs'
    dest.write_text(text)

def body(s): return 'function f() -> Unit\n'+s+'\nend function\n'
def arm(s): return body('match k with\ncase 1 ->\nlog(k)\n'+s+'\nend match')
cases={
    'when_plain':arm('when + "${n}"'),
    'when_format':arm('when + "${n:>3}"'),
    'when_call':arm('when("${n:>3}")'),
    'when_old':body('match k with\nwhen 1: 2\nend match'),
    'when_real_after_string':body('match k with\nwhen "${n:>3}": 2\nend match'),
    'when_nested':arm('when + "${"${n:>3}"}"'),
    'with_when_plain':body('handle f() with when + "${n}"\nend handle'),
    'with_when_format':body('handle f() with when + "${n:>3}"\nend handle'),
    'with_when_old':body('handle f() with when E.op(x): x\nend handle'),
    'with_real_after_string':body('handle f() with when "${n:>3}": x\nend handle'),
    'default_plain':arm('default + "${n}"'),
    'default_format':arm('default + "${n:>3}"'),
    'default_old':body('match k with\ndefault: 1\nend match'),
    'lambda_plain':body('"${lambda(x: Integer) x}"'),
    'lambda_format':body('"${lambda(x: Integer) x:>8}"'),
    'lambda_header_bad':body('"${lambda(x: Integer): Integer x:>8}"'),
    'lambda_header_good':body('"${lambda(x: Integer) -> Integer x:>8}"'),
    'lambda_nested_plain':body('"${lambda() "${n}"}"'),
    'lambda_nested_format':body('"${lambda() "${n:^8}"}"'),
    'lambda_explicit_format':body('"${lambda() n end lambda:>8}"'),
    'named_arg':body('"${f(x: 1):>8}"'),
    'record':body('"${R(x: 1):>8}"'),
    'record_pattern':body('"${match r with case R(x: n) -> n end match:>8}"'),
    'block_type':body('"${block bind n: Integer <- 1 end block:>8}"'),
    'block_type_plain':body('"${block bind n: Integer <- 1 end block}"'),
    'short_bind':body('"${lambda() bind n: Integer <- 1:>8}"'),
    'function_type':body('"${lambda(f: function(x: Integer) -> Integer) f(1):>8}"'),
    'hash_number':body('"${n:#08x}"'),
    'caret':body('"${n:^8}"'),
    'left_arrow':body('"${n:<-8}"'),
    'number_precision':body('"${n:8.2f}"'),
    'bad_number_expr':body('"${12abc:>8}"'),
    'bad_number_plain':body('"${12abc}"'),
    'bad_number_nested':body('"${"${12abc}":8.2f}"'),
    'failed_expr':body('"${f(:8.2f}"'),
    'multiple':body('"${n:#08x}/${m:^8}/${x:8.2f}"'),
    'bad_symbol_expr':body('"${# + n:>8}"'),
    'bad_symbol_plain':body('"${# + n}"'),
    'unicode_expr':body('"${\u3000:>8}"'),
    'bidi_format':body('"${n:\u202e>8}"'),
    'unicode_escape':body('"${"\\u{D800}":>8}"'),
    'comment_format':body('"${n://x}"'),
    'newline_expr':body('"${n:\n>8}"'),
    'lone_cr':body('"${n:\r>8}"'),
    'newline_lambda_outer':body('(\n"${lambda() n:^8}",\n2\n)'),
    'newline_unmatched_format':body('(\n"${n:(}",\n2\n)'),
    'newline_plain':body('(\n"${n}",\n2\n)'),
    'outer_lambda_nested':body('(lambda() "${lambda() n:^8}",\n2)'),
    'triple':body('"""\n  ${n:>8}\n  """'),
    'raw':body('r"${n:>8}"'),
    'nested_raw':body('"${r"a:b" :>8}"'),
    'bad_number_after':body('"${n:8.2f}"\n12abc'),
    'limit_inside':body('"'+'${n:>8}'*997+'"'),
    'limit_outside':body('"'+'${n:>8}'*1001+'"'),
    'expr_limit':body('"${f('+','.join('n' for _ in range(1001))+'):>8}"'),
    'newline_statement_plain':body('"${n}"\n()'),
    'newline_statement_bracket':body('"${n:(}"\n()'),
    'newline_statement_lambda':body('"${lambda() n:^8}"\n()'),
    'lambda_invalid_end':body('"${lambda() n:end lambda}"'),
    'lambda_nested_both':body('"${lambda() "${lambda() n:^8}":>8}"'),
    'when_old_after_nested':body('match k with\nwhen "${"${n:>3}"}": 2\nend match'),
    'with_resource_plain':body('handle\nwith when = acquire("${n}") do () end with\nwith case E.op() -> resume(())\nend handle'),
    'with_resource_format':body('handle\nwith when = acquire("${n:>3}") do () end with\nwith case E.op() -> resume(())\nend handle'),
    'with_legacy_inner':body('handle\n()\nwith when E.op("${n:>3}"): ()\nend handle'),
    'list_plain':body('[\n"${lambda() n}",\n2\n]'),
    'list_format':body('[\n"${lambda() n:^8}",\n2\n]'),
    'inside_when_outside_colon':body('"${match k with case 1 -> when}:>8"'),
    'inside_when_tail_colon':body('"${match k with case 1 -> when end match}:literal:"'),
    'when_guard_real_colon':body('match k with\nwhen x if "${n:>3}" = "": x\nend match'),
    'when_guard_old_plain':body('match k with\nwhen x if "${n}" = "": x\nend match'),
    'with_invalid_old_string':body('handle\n()\nwith when E.op("${n}"): ()\nend handle'),
    'outer_lambda_explicit':body('lambda() "${n}" end lambda'),
    'outer_lambda_explicit_format':body('lambda() "${n:>8}" end lambda'),
    'explicit_typed_bind':body('"${lambda() bind n: Integer <- 1 end lambda:>8}"'),
    'old_explicit_typed_bind':body('lambda() bind n: Integer <- 1 end lambda'),
    'old_short':body('lambda() bind n: Integer <- 1'),
    'old_explicit_block':body('lambda() block () end block end lambda'),
    'old_explicit_multiline':body('lambda()\n()\nend lambda'),
    'old_nested_lambda':body('lambda() (lambda() n) end lambda'),
    'old_return_lambda':body('lambda() return n end lambda'),
    'old_bad_return':body('lambda(): Integer n end lambda'),
    'string_tail_number_error':body('"${n:8.2f} body ${12abc}"'),
    'japanese_head':body('"あ${n:8.2f}い${m:^8}"'),
    'limit_pending':body('"'+'${n:8.2f}'*1001+'"'),
    'bad_symbol_tail':body('"${n#}"'),
    'number_decimal_spec':body('"${n:+08.2f}"'),
    'number_bad_suffix_expr':body('"${1.2M:>8}"'),
    'number_wrong_form_expr':body('"${1f32:>8}"'),
}
for name in ['when_format','lambda_format','triple','newline_plain']:
    cases[name+'_crlf']=cases[name].replace('\n','\r\n')
inputs=HERE/'inputs';inputs.mkdir(exist_ok=True)
for name,src in cases.items(): (inputs/(name+'.bnt')).write_bytes(src.encode())
(inputs/'utf8_expr.bnt').write_bytes(body('"${BAD:>8}"').encode().replace(b'BAD',b'\xff'))
(inputs/'utf8_format.bnt').write_bytes(body('"${n:BAD>8}"').encode().replace(b'BAD',b'\xff'))
(HERE/'case-list.json').write_text(json.dumps(sorted(p.name for p in inputs.glob('*.bnt')),indent=2)+'\n')
print('prepared',len(list(inputs.glob('*.bnt'))),'inputs')
