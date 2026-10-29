//! 名前の種類と閉じた範囲の照合（設計書 02-04「範囲引数の解決」）。
use super::{BindingKind, DeclSite, collect::Resolver, lookup::Ctx, lookup::dotted};
use crate::base::{BindingId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::modules::ModuleKind;
use crate::syntax::ast::{
    EffectRef, Item, NamedType, ScopeArg, ScopeArgKind, ScopeArgs, TypeParamKind,
};
use crate::types::builtin::{BuiltinEffectId, find_builtin_effect};
use crate::types::scope::{
    EndpointPattern, HostPattern, InvalidScope, Kind, PathPattern, Port, PortRange, Range,
};

impl Resolver<'_> {
    fn builtin_effect(&self, id: BindingId) -> Option<BuiltinEffectId> {
        let b = self.out.bindings.get(id)?;
        if let BindingKind::BuiltinEffect(e) = b.kind {
            return Some(e);
        }
        let module = self.modules.get(b.module)?;
        if !matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib) {
            return None;
        }
        let path: Vec<_> = module.name.0.iter().skip(1).map(String::as_str).collect();
        find_builtin_effect(&path, &b.name)
    }
    pub(super) fn effect_arguments(&mut self, ctx: &mut Ctx, e: &EffectRef, id: BindingId) {
        let failure = self.out.stdlib("Benitoite.Failure.Fail") == Some(id);
        let kind = self
            .builtin_effect(id)
            .and_then(BuiltinEffectId::scope_kind);
        if let Some(kind) = kind {
            if e.args.is_none() && e.scope.is_none() {
                return;
            }
            match e.scope.as_deref().map(|s| normalize(s, kind)) {
                Some(Ok(range)) => {
                    self.out.scopes.insert(e.id, range);
                }
                Some(Err(error)) => self.scope_error(
                    &dotted(&e.path),
                    kind,
                    false,
                    e.scope.as_deref().map_or(e.span, ScopeArgs::element_span),
                    error,
                ),
                None => self.scope_error(
                    &dotted(&e.path),
                    kind,
                    false,
                    e.span,
                    InvalidScope::PathPattern,
                ),
            }
            return;
        }
        if failure && e.scope.is_none() && e.args.as_ref().is_some_and(|args| args.len() == 1) {
            if let Some(args) = &e.args {
                for ty in args {
                    self.ty(ctx, ty);
                }
            }
        } else if failure || e.args.is_some() || e.scope.is_some() {
            // 同じ不正な略記の群は一度だけ報告する。
            if e.scope.as_deref().is_none_or(|s| s.element.start == 0) {
                self.out.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0513)
                        .primary(e.span)
                        .arg("name", dotted(&e.path))
                        .arg("count", if failure { "1" } else { "0" })
                        .build(),
                );
            }
        }
    }
    pub(super) fn type_scope(&mut self, t: &NamedType, id: BindingId) {
        let kind = self.out.bindings.get(id).and_then(|b| {
            if let BindingKind::BuiltinType(ty) = b.kind {
                ty.value_kind()
            } else {
                None
            }
        });
        if let Some(kind) = kind
            && !t.args.is_empty()
        {
            self.scope_error(
                &dotted(&t.path),
                kind,
                true,
                t.span,
                InvalidScope::PathPattern,
            );
            return;
        }
        let Some(scope) = &t.scope else {
            return;
        };
        if let Some(kind) = kind {
            match normalize(scope, kind) {
                Ok(range) => {
                    self.out.scopes.insert(t.id, range);
                }
                Err(error) => self.scope_error(&dotted(&t.path), kind, true, scope.span, error),
            }
        } else {
            self.out.diagnostics.push(
                DiagBuilder::new(DiagCode::E0520)
                    .primary(scope.span)
                    .arg("name", dotted(&t.path))
                    .arg(
                        "expectedScopeKind",
                        if self.has_type_parameters(id) {
                            super::text::TYPE_ARGUMENTS
                        } else {
                            super::text::NO_SCOPE_ARGUMENTS
                        },
                    )
                    .arg("found", self.scope_source(scope.span))
                    .note("found")
                    .build(),
            );
        }
    }
    // 型の綴りでなく、解決済みの組み込み表または宣言を参照する。
    fn has_type_parameters(&self, id: BindingId) -> bool {
        let Some(binding) = self.out.bindings.get(id) else {
            return false;
        };
        if let BindingKind::BuiltinType(ty) = binding.kind {
            return ty.def().is_some_and(|def| def.arity > 0);
        }
        let DeclSite::Node(node) = binding.decl else {
            return false;
        };
        let Some(decl) = self
            .ast(binding.module)
            .and_then(|m| m.decls.iter().find(|d| d.item.id() == node))
        else {
            return false;
        };
        let params = if let Item::Data(d) = &decl.item {
            &d.type_params
        } else if let Item::Record(d) = &decl.item {
            &d.type_params
        } else if let Item::Alias(d) = &decl.item {
            &d.type_params
        } else if let Item::ExternalType(d) = &decl.item {
            &d.type_params
        } else {
            return false;
        };
        params
            .iter()
            .any(|p| !matches!(p.kind, TypeParamKind::Effect))
    }
    fn scope_source(&self, span: Span) -> String {
        self.sources
            .get(span.file)
            .and_then(|source| {
                let start = usize::try_from(span.start.0).ok()?;
                let end = usize::try_from(span.end.0).ok()?;
                let bytes = source.text().get(start..end)?;
                std::str::from_utf8(bytes).ok().map(str::to_owned)
            })
            .unwrap_or_else(|| super::text::SCOPE_ARGUMENTS.into())
    }
    fn scope_error(
        &mut self,
        name: &str,
        kind: Kind,
        single_range: bool,
        span: Span,
        error: InvalidScope,
    ) {
        if error == InvalidScope::Internal {
            self.internal("scope normalization invariant failed".into());
            return;
        }
        self.out.diagnostics.push(
            DiagBuilder::new(DiagCode::E0520)
                .primary(span)
                .arg("name", name)
                .arg(
                    "expectedScopeKind",
                    match (kind, single_range) {
                        (Kind::Path, true) => super::text::SINGLE_PATH_SCOPE,
                        (Kind::Endpoint, true) => super::text::SINGLE_ENDPOINT_SCOPE,
                        (Kind::Host, true) => super::text::SINGLE_HOST_SCOPE,
                        (Kind::Path, false) => super::text::PATH_SCOPE,
                        (Kind::Endpoint, false) => super::text::ENDPOINT_SCOPE,
                        (Kind::Host, false) => super::text::HOST_SCOPE,
                    },
                )
                .arg("found", self.scope_source(span))
                .note("found")
                .build(),
        );
    }
}
fn normalize(scope: &ScopeArgs, kind: Kind) -> Result<Range, InvalidScope> {
    match (kind, scope.selected()) {
        (
            Kind::Path,
            [
                ScopeArg {
                    kind: ScopeArgKind::String(s),
                    ..
                },
            ],
        ) => PathPattern::parse(s).map(Range::Path),
        (
            Kind::Endpoint,
            [
                ScopeArg {
                    kind: ScopeArgKind::String(host),
                    ..
                },
                ScopeArg {
                    kind: ScopeArgKind::Port(lo, hi),
                    ..
                },
            ],
        ) => {
            let host = HostPattern::parse(host)?;
            let lo = lo.parse::<i64>().map_err(|_| InvalidScope::PortBounds)?;
            let hi = hi
                .as_deref()
                .map_or(Ok(lo), str::parse::<i64>)
                .map_err(|_| InvalidScope::PortBounds)?;
            let ports = PortRange::new(
                Port::from_int(lo).ok_or(InvalidScope::PortBounds)?,
                Port::from_int(hi).ok_or(InvalidScope::PortBounds)?,
            )?;
            Ok(Range::Endpoint(EndpointPattern { host, ports }))
        }
        _ => Err(InvalidScope::PathPattern),
    }
}
