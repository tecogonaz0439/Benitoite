"""Compile each revision's own private conversion code against its public runtime.

Only call adapters differ for the old free functions and the new session methods.
No implementation is copied between states, and production visibility is untouched.
"""
import json
from pathlib import Path
from build import sha

OBSERVER = r'''
pub(super) fn compare_observe(shape: &str, n: usize) -> Result<String, Stop> {
    use std::time::Instant;
    let count = match shape { "empty" => 0, "shared" => n + 1, "nodes" => n, _ => return Err(invalid_conversion()) };
    let mut nodes: Vec<Value> = Vec::new();
    for i in 0..count {
        let args = if i == 0 { vec![Value::Int(7)] } else {
            let left = nodes.get(i-1).ok_or_else(invalid_conversion)?.clone();
            let right = nodes.get(if shape == "shared" { i-1 } else { i.saturating_sub(2) }).ok_or_else(invalid_conversion)?.clone();
            vec![left, right]
        };
        nodes.push(Value::ctor(1, args));
    }
    let value = nodes.last().cloned().unwrap_or(Value::Unit);
    let mut heap = Heap::new(HeapConfig::default());
    let roots = RootStack::new();
    let (to, from, heap_nodes, observation) = heap.epoch(|ctx| {
        let mut references = Vec::new();
        let start = Instant::now();
        let converted = COMPARE_TO?;
        let to = start.elapsed().as_secs_f64();
        let mut opaque = |_| Err(invalid_conversion());
        let start = Instant::now();
        let restored = COMPARE_FROM?;
        let from = start.elapsed().as_secs_f64();
        // 対象数の走査と小さい結果の確認は両方の計時区間の外に置く。
        let mut seen = std::collections::HashSet::new();
        let mut pending = vec![converted];
        while let Some(v) = pending.pop() {
            if let Some(id) = ctx.object_id(v) {
                if seen.insert(id) {
                    let len = ctx.fields_len(v).ok_or_else(invalid_conversion)?;
                    for i in 0..len { pending.push(ctx.field(v, i).ok_or_else(invalid_conversion)?); }
                }
            }
        }
        let mut at = &restored;
        let observation = loop {
            match at {
                Value::Ctor { args, .. } => at = args.items.first().ok_or_else(invalid_conversion)?,
                Value::Int(7) => break 7,
                Value::Unit if count == 0 => break 0,
                _ => return Err(invalid_conversion()),
            }
        };
        Ok::<_, Stop>((to, from, seen.len(), observation))
    })?;
    let stats = heap.stats();
    let edges = count.saturating_sub(1)*2;
    let allocation = if cfg!(feature = "alloc-stats") { format!(",\"allocated_bytes\":{},\"peak_heap_bytes\":{}", stats.allocated_bytes, stats.peak_heap_bytes) } else { String::new() };
    Ok(format!("{{\"bridge_to_heap\":{to},\"bridge_from_heap\":{from},\"bridge_time\":{},\"unique_nodes\":{count},\"edges\":{edges},\"heap_nodes\":{heap_nodes},\"observation\":{observation}{allocation}}}", to+from))
}
'''


def prepare(archive, target):
    directory = target/'probe-source'
    directory.mkdir(exist_ok=True)
    root = archive/'crates/benitoite/src/refinterp'
    path = directory/'bridge.rs'
    if not (root/'convert.rs').exists():
        # ビルドの自己検査の最小archiveにはRustのソースを含めない。
        path.write_text('')
        return path, {}
    sources = {name: (root/f'{name}.rs').read_text() for name in ('convert', 'value')}
    if 'struct ToHeapSession' in sources['convert']:
        to = 'ToHeapSession::default().convert(ctx, &value, "compare bridge", &roots, &mut references, 0)'
        fr = 'FromHeapSession::default().convert(ctx, converted, &mut opaque)'
    else:
        to = 'to_heap_with(ctx, &value, "compare bridge", &roots, &mut references, 0)'
        fr = 'from_heap_with(ctx, converted, &mut opaque)'
    observer = OBSERVER.replace('COMPARE_TO', to).replace('COMPARE_FROM', fr)
    source = sources['convert']
    start = source.index('#[derive(Clone, Copy, PartialEq, Eq, Hash)]\nenum RefKey') if 'enum RefKey' in source else source.index("enum ToHeap<'a>")
    conversion_code = source[start:source.index('#[cfg(test)]\nmod tests')]
    ref_value = source[source.index('#[derive(Debug)]\nstruct RefValue'):source.index('impl BuiltinBridge')]
    # 変換関数だけを同じ公開ヒープへ接続する。呼び出し器の非公開入口は不要である。
    imports = '''use std::{rc::Rc, collections::HashMap};
use super::value::{Value, Values};
use crate::runtime::Stop;
use crate::runtime::heap::{CheckedLen, CtorTag, FieldsKind, Heap, HeapConfig, NoGcCtx, ObjId, ObjKind, OpaqueData, RootIdx, RootStack, Trace, Tracer, Value as HeapValue, ValueCtx};
'''
    list_source = (archive/'crates/benitoite/src/runtime/list.rs').read_text()
    start = list_source.index('pub(crate) fn is_list')
    predicate = list_source[start:list_source.index('\n}', start)+2].replace('pub(crate)', 'pub(super)')
    rrb = (archive/'crates/benitoite/src/runtime/list/rrb.rs').read_text()
    import re
    head = re.search(r'const HEAD: u32 = ([^;]+);', rrb).group(1)
    imports += 'mod list { pub use crate::runtime::list::*; use crate::runtime::heap::{Value, ValueCtx, FieldsKind}; mod rrb { pub const HEAD: u32 = '+head+'; }\n'+predicate+'\n}\n'
    conversion = directory/'convert.rs'
    conversion.write_text(imports+ref_value+conversion_code+observer)
    text = ''.join(f'#[path = {json.dumps(str((conversion if name == "convert" else root/f"{name}.rs").resolve()))}] mod {name};\n' for name in sources)
    text += 'pub fn observe(shape: &str, n: usize) -> Result<String, crate::runtime::Stop> { convert::compare_observe(shape, n) }\n'
    path.write_text(text)
    hashes = {f'original_{name}': sha(text.encode()) for name, text in sources.items()}
    hashes.update(observer=sha(observer.encode()), wrapper=sha(text.encode()))
    hashes['conversion_unit'] = sha(conversion.read_bytes())
    return path, hashes
