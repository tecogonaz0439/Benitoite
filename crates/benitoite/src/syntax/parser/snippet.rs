//! 修正案に使うソースの写し（設計書 02-10「修正案」、02-02「span」）。
use crate::base::Span;
pub(super) fn snippet(text: &[u8], span: Span) -> String {
    let bytes = usize::try_from(span.start.0)
        .ok()
        .zip(usize::try_from(span.end.0).ok())
        .and_then(|(start, end)| text.get(start..end))
        .unwrap_or_default();
    String::from_utf8_lossy(bytes).into_owned()
}
