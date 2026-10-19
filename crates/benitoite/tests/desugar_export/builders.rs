//! 型付きの専用参照を corpus 12 へ保持する（設計書 07-04「01-12 との対応」）。
use super::*;
use benitoite::typeck::{BuilderKind, BuilderRefs};

impl Surface<'_> {
    fn builder_prim(&mut self, id: BindingId, types: Vec<Value>) -> Value {
        let BindingKind::BuiltinFn(b) = self.p.resolved.bindings.get(id).unwrap().kind else {
            panic!("builder cell reference is not a primitive");
        };
        json!({"name":builtins::builtin_decl(b).unwrap().name,"types":types})
    }

    fn builder_pure(&mut self, id: BindingId, types: Vec<Value>) -> Value {
        if matches!(
            self.p.resolved.bindings.get(id).unwrap().kind,
            BindingKind::BuiltinFn(_)
        ) {
            tagged("prim", json!({"ref":self.builder_prim(id, types)}))
        } else {
            assert_eq!(
                self.p.resolved.bindings.get(id).unwrap().kind,
                BindingKind::Fn
            );
            tagged("funRef", json!({"name":fun_name(id),"types":types}))
        }
    }

    pub(super) fn builder_refs(&mut self, kind: &BuilderKind, refs: &BuilderRefs) -> Value {
        let contents = match kind {
            BuilderKind::String => json!({"base":{"name":"String"}}),
            BuilderKind::List(t) => tagged("list", json!({"elem":self.ty(t)})),
            BuilderKind::Bytes => json!("bytes"),
        };
        let cell = json!({
            "newRef":self.builder_prim(refs.new, vec![contents.clone()]),
            "getRef":self.builder_prim(refs.get, vec![contents.clone()]),
            "setRef":self.builder_prim(refs.set, vec![contents]),
        });
        let types = match kind {
            BuilderKind::List(t) => vec![self.ty(t)],
            BuilderKind::String | BuilderKind::Bytes => vec![],
        };
        let join = self.builder_pure(refs.join, types.clone());
        let length = self.builder_pure(refs.length, types.clone());
        match kind {
            BuilderKind::String => {
                let add =
                    table::operator_builtin(c::OperatorKind::Add, BuiltinTypeId::STRING).unwrap();
                let add = tagged(
                    "prim",
                    json!({"ref":{"name":builtins::builtin_decl(add).unwrap().name,"types":[]}}),
                );
                tagged(
                    "string",
                    json!({"cell":cell,"add":add,"join":join,"length":length}),
                )
            }
            BuilderKind::List(t) => {
                let append = self.builder_pure(refs.single.unwrap(), types);
                tagged(
                    "list",
                    json!({"element":self.ty(t),"cell":cell,"append":append,"concatenate":join,"length":length}),
                )
            }
            BuilderKind::Bytes => {
                let empty = self.builder_pure(refs.empty.unwrap(), vec![]);
                let from_list = self.builder_pure(refs.single.unwrap(), vec![]);
                tagged(
                    "bytes",
                    json!({"cell":cell,"empty":empty,"fromList":from_list,"concatenate":join,"length":length}),
                )
            }
        }
    }
}
