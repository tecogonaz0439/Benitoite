//! 構築器の種類だけを corpus 13 へ渡す（設計書 07-04「01-12 との対応」）。
use super::*;
use benitoite::typeck::BuilderKind;

impl Surface<'_> {
    pub(super) fn builder_kind(&mut self, kind: &BuilderKind) -> Value {
        match kind {
            BuilderKind::String => json!("string"),
            BuilderKind::Bytes => json!("bytes"),
            BuilderKind::List(t) => tagged("list", json!({"element":self.ty(t)})),
        }
    }
}
