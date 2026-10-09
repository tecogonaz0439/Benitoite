//! 診断に埋める字句と構文の呼び名（設計書 02-03「構文の規則に伴う診断」）。
use crate::syntax::token::{Token, TokenKind, TokenValue};

pub(super) fn token_name(kind: TokenKind) -> &'static str {
    match kind {
        TokenKind::LowerIdent => "a lowercase name",
        TokenKind::UpperIdent => "an uppercase name",
        TokenKind::IntLit => "an integer literal",
        TokenKind::FloatLit => "a floating-point literal",
        TokenKind::DecimalLit => "a Decimal literal",
        TokenKind::StringLit => "a string literal",
        TokenKind::StrStart => "an interpolated string",
        TokenKind::StrMid => "an interpolation segment",
        TokenKind::StrEnd => "the end of an interpolated string",
        TokenKind::CharLit => "a character literal",
        TokenKind::KwAnd => "`and`",
        TokenKind::KwBind => "`bind`",
        TokenKind::KwCase => "`case`",
        TokenKind::KwConst => "`const`",
        TokenKind::KwData => "`data`",
        TokenKind::KwDiv => "`div`",
        TokenKind::KwDo => "`do`",
        TokenKind::KwEffect => "`effect`",
        TokenKind::KwElse => "`else`",
        TokenKind::KwEnd => "`end`",
        TokenKind::KwFalse => "`false`",
        TokenKind::KwFunction => "`function`",
        TokenKind::KwHandle => "`handle`",
        TokenKind::KwIf => "`if`",
        TokenKind::KwImplement => "`implement`",
        TokenKind::KwImport => "`import`",
        TokenKind::KwLambda => "`lambda`",
        TokenKind::KwLazy => "`lazy`",
        TokenKind::KwMatch => "`match`",
        TokenKind::KwMod => "`mod`",
        TokenKind::KwNot => "`not`",
        TokenKind::KwOr => "`or`",
        TokenKind::KwPublic => "`public`",
        TokenKind::KwRecord => "`record`",
        TokenKind::KwResume => "`resume`",
        TokenKind::KwReturn => "`return`",
        TokenKind::KwShadow => "`shadow`",
        TokenKind::KwThen => "`then`",
        TokenKind::KwTrait => "`trait`",
        TokenKind::KwTrue => "`true`",
        TokenKind::KwTry => "`try`",
        TokenKind::KwType => "`type`",
        TokenKind::KwUses => "`uses`",
        TokenKind::KwWith => "`with`",
        TokenKind::Plus => "`+`",
        TokenKind::Minus => "`-`",
        TokenKind::Star => "`*`",
        TokenKind::Slash => "`/`",
        TokenKind::Eq => "`=`",
        TokenKind::NotEq => "`<>`",
        TokenKind::Lt => "`<`",
        TokenKind::Le => "`<=`",
        TokenKind::Gt => "`>`",
        TokenKind::Ge => "`>=`",
        TokenKind::PipeGt => "`|>`",
        TokenKind::Arrow => "`->`",
        TokenKind::LeftArrow => "`<-`",
        TokenKind::Colon => "`:`",
        TokenKind::Comma => "`,`",
        TokenKind::Dot => "`.`",
        TokenKind::DotDot => "`..`",
        TokenKind::Amp => "`&`",
        TokenKind::At => "`@`",
        TokenKind::LParen => "`(`",
        TokenKind::RParen => "`)`",
        TokenKind::LBracket => "`[`",
        TokenKind::RBracket => "`]`",
        TokenKind::Underscore => "`_`",
        TokenKind::LineBreak => "a line break",
        TokenKind::Newline => "a newline",
        TokenKind::Error => "an invalid token",
        TokenKind::BadSymbol => "an invalid symbol",
        TokenKind::Eof => "the end of the file",
    }
}

pub(super) fn keyword(kind: TokenKind) -> Option<&'static str> {
    match kind {
        TokenKind::LowerIdent => None,
        TokenKind::UpperIdent => None,
        TokenKind::IntLit => None,
        TokenKind::FloatLit => None,
        TokenKind::DecimalLit => None,
        TokenKind::StringLit => None,
        TokenKind::StrStart => None,
        TokenKind::StrMid => None,
        TokenKind::StrEnd => None,
        TokenKind::CharLit => None,
        TokenKind::KwAnd => Some("and"),
        TokenKind::KwBind => Some("bind"),
        TokenKind::KwCase => Some("case"),
        TokenKind::KwConst => Some("const"),
        TokenKind::KwData => Some("data"),
        TokenKind::KwDiv => Some("div"),
        TokenKind::KwDo => Some("do"),
        TokenKind::KwEffect => Some("effect"),
        TokenKind::KwElse => Some("else"),
        TokenKind::KwEnd => Some("end"),
        TokenKind::KwFalse => Some("false"),
        TokenKind::KwFunction => Some("function"),
        TokenKind::KwHandle => Some("handle"),
        TokenKind::KwIf => Some("if"),
        TokenKind::KwImplement => Some("implement"),
        TokenKind::KwImport => Some("import"),
        TokenKind::KwLambda => Some("lambda"),
        TokenKind::KwLazy => Some("lazy"),
        TokenKind::KwMatch => Some("match"),
        TokenKind::KwMod => Some("mod"),
        TokenKind::KwNot => Some("not"),
        TokenKind::KwOr => Some("or"),
        TokenKind::KwPublic => Some("public"),
        TokenKind::KwRecord => Some("record"),
        TokenKind::KwResume => Some("resume"),
        TokenKind::KwReturn => Some("return"),
        TokenKind::KwShadow => Some("shadow"),
        TokenKind::KwThen => Some("then"),
        TokenKind::KwTrait => Some("trait"),
        TokenKind::KwTrue => Some("true"),
        TokenKind::KwTry => Some("try"),
        TokenKind::KwType => Some("type"),
        TokenKind::KwUses => Some("uses"),
        TokenKind::KwWith => Some("with"),
        TokenKind::Plus => None,
        TokenKind::Minus => None,
        TokenKind::Star => None,
        TokenKind::Slash => None,
        TokenKind::Eq => None,
        TokenKind::NotEq => None,
        TokenKind::Lt => None,
        TokenKind::Le => None,
        TokenKind::Gt => None,
        TokenKind::Ge => None,
        TokenKind::PipeGt => None,
        TokenKind::Arrow => None,
        TokenKind::LeftArrow => None,
        TokenKind::Colon => None,
        TokenKind::Comma => None,
        TokenKind::Dot => None,
        TokenKind::DotDot => None,
        TokenKind::Amp => None,
        TokenKind::At => None,
        TokenKind::LParen => None,
        TokenKind::RParen => None,
        TokenKind::LBracket => None,
        TokenKind::RBracket => None,
        TokenKind::Underscore => None,
        TokenKind::LineBreak => None,
        TokenKind::Newline => None,
        TokenKind::Error => None,
        TokenKind::BadSymbol => None,
        TokenKind::Eof => None,
    }
}

pub(super) fn describe(token: &Token) -> String {
    if let TokenValue::Ident(name) | TokenValue::Symbol(name) = &token.value {
        return format!("`{name}`");
    }
    token_name(token.kind).to_owned()
}
pub(super) const NAME: &str = "a name";
pub(super) const LOWER_NAME: &str = "a lowercase name";
pub(super) const UPPER_NAME: &str = "an uppercase name";
pub(super) const EXPRESSION: &str = "an expression";
pub(super) const PATTERN: &str = "a pattern";
pub(super) const TYPE: &str = "a type";
pub(super) const DECLARATION: &str = "a declaration";
pub(super) const FUNCTION: &str = "a function declaration";
pub(super) const IMPORT: &str = "an import declaration";
pub(super) const ATTRIBUTE: &str = "an attribute";
pub(super) const RECORD: &str = "a record declaration";
pub(super) const RECORD_EXPR: &str = "a record construction";
pub(super) const RECORD_PATTERN: &str = "a record pattern";
pub(super) const ALIAS: &str = "a type alias";
pub(super) const CONSTANT: &str = "a constant declaration";
pub(super) const TRAIT: &str = "a trait declaration";
pub(super) const IMPLEMENT: &str = "an implementation declaration";
pub(super) const EFFECT: &str = "an effect declaration";
pub(super) const HANDLE: &str = "an effect handler";
pub(super) const RESUME: &str = "a resume expression";
pub(super) const WITH: &str = "a resource scope";
pub(super) const LAZY: &str = "a lazy expression";
pub(super) const LAZY_BODY: &str = "a lazy body";
pub(super) const GUARD: &str = "a match guard";
pub(super) const TRY: &str = "a try expression";
pub(super) const INTERP: &str = "an interpolated string";
pub(super) const SPREAD: &str = "a list spread";
pub(super) const RANGE: &str = "a range pattern";
pub(super) const LIST_PATTERN: &str = "a list pattern";
pub(super) const CONSTRAINT: &str = "a builtin constraint";
pub(super) const FIELD: &str = "a record field";
pub(super) const FIELD_ARG: &str = "a field argument";
pub(super) const FIELD_PAT: &str = "a field pattern";
pub(super) const METHOD: &str = "a trait method";
pub(super) const OPERATION: &str = "an effect operation";
pub(super) const HANDLE_CLAUSE: &str = "a handler clause";
pub(super) const PARAMETER: &str = "a parameter";
pub(super) const TYPE_PARAMETER: &str = "a type parameter";
pub(super) const ARM: &str = "a match branch";
pub(super) const STATEMENT: &str = "a statement";
pub(super) const COMMA_OR_RPAREN: &str = "`,` or `)`";
pub(super) const COMMA_OR_RBRACKET: &str = "`,` or `]`";
pub(super) const NEWLINE_OR_END: &str = "a newline or the end of the block";
pub(super) const RETURN_ARROW: &str = "`->`";
pub(super) const DATA: &str = "a data declaration";
pub(super) const BODY: &str = "a function body";
pub(super) const USES: &str = "an effect name";
pub(super) const RPAREN: &str = "`)`";
