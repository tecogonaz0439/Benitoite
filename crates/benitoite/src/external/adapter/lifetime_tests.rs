//! 補助の本番の内部接続で、後処理・文字列の符号化・深い値の寿命を確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::limit_tests::{fixture, invoke};
use crate::external::{ExternalFailure, ExternalRuntime, Limits, WitPlan as P};
use crate::runtime::heap::{Heap, HeapConfig, Value};
use crate::runtime::{RuntimeError, Stop, list};

const POST_RETURN: &str =
    include_str!("../../../testdata/external/adapter-lifetime/post-return.wat");
const UTF16: &str = include_str!("../../../testdata/external/adapter-lifetime/utf16.wat");

#[test]
fn post_return_poisoning_preserves_results_and_pure_calls_start_fresh() {
    // 関門: ゲストの後処理が参照先と記述子を壊しても、コピー済みの結果を保持する。
    // 二度目の後処理はトラップし、Store の再利用は呼び出し数を変える。
    // 既存の配置の往復は後処理も実行内のコンパイル共有も通らない。
    let fixture = fixture(POST_RETURN, vec![], Some(P::String));
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let mut values = vec![];
        for _ in 0..3 {
            values.push(
                invoke(
                    &fixture,
                    &mut runtime,
                    ctx,
                    &[],
                    Limits::default(),
                    &mut None,
                )
                .unwrap(),
            );
        }
        // Store が捨てられ、次の呼び出しも終わった後に全結果を読み直す。
        for value in values {
            assert_eq!(ctx.str(value), Some("1!"));
        }
    });
    // 後処理を省く実装も成功してしまわないよう、後処理だけが失敗するゲストを通す。
    let trapping = POST_RETURN.replace("i32.const 1 global.set $posts", "unreachable");
    let fixture = super::limit_tests::fixture(&trapping, vec![], Some(P::String));
    heap.epoch(|ctx| {
        let result = invoke(
            &fixture,
            &mut runtime,
            ctx,
            &[],
            Limits::default(),
            &mut None,
        );
        assert!(
            matches!(
                result,
                Err(ExternalFailure::Stop(Stop::Runtime(
                    RuntimeError::ExternalTrap { .. }
                )))
            ),
            "{result:?}"
        );
    });
}

#[test]
fn utf16_guest_converts_surrogate_pairs_and_empty_strings() {
    // 関門: 元のゲストの正準オプションを保ち、引数と結果の両方で UTF-16 を変換する。
    // UTF-8 同士の試験では符号化の取り違えとサロゲートの長さの誤りを捕まえない。
    let fixture = fixture(UTF16, vec![P::String], Some(P::String));
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (text, expected) in [("A日😀", "日😀!"), ("", "")] {
            let argument = ctx.alloc_str(text, "test").unwrap();
            let value = invoke(
                &fixture,
                &mut runtime,
                ctx,
                &[argument],
                Limits::default(),
                &mut None,
            )
            .unwrap();
            assert_eq!(ctx.str(value), Some(expected));
        }
    });
}

#[test]
fn malformed_guest_strings_and_tags_remain_external_failures() {
    // 関門: 元のゲストの不正な UTF と判別子は、補助形式の不一致と区別する。
    // lower/lift だけの試験と違い、呼び出しの入口での停止の分類まで検査する。
    let utf8 = POST_RETURN.replace("global.get $calls i32.const 48 i32.add", "i32.const 255");
    let utf16 = UTF16.replace(r"\00\de", r"\41\00");
    let tag = r#"(component
        (core module $m (memory (export "memory") 1)
            (func (export "run") (result i32)
                i32.const 16 i32.const 2 i32.store8 i32.const 16))
        (core instance $i (instantiate $m)) (type $t (option u32))
        (func (export "run") (result $t)
            (canon lift (core func $i "run") (memory (core memory $i "memory")))))"#;
    for (guest, params, result, message) in [
        (utf8.as_str(), vec![], P::String, "utf8"),
        (utf16.as_str(), vec![P::String], P::String, "utf16"),
        (tag, vec![], P::Option(Box::new(P::U32)), "discriminant"),
    ] {
        let fixture = fixture(guest, params, Some(result));
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let arguments = if message == "utf16" {
                vec![ctx.alloc_str("A日😀", "test").unwrap()]
            } else {
                vec![]
            };
            let result = invoke(
                &fixture,
                &mut runtime,
                ctx,
                &arguments,
                Limits::default(),
                &mut None,
            );
            let Err(ExternalFailure::Stop(Stop::Runtime(RuntimeError::ExternalTrap {
                trap: detail,
                ..
            }))) = result
            else {
                panic!("{result:?}");
            };
            assert!(detail.to_lowercase().contains(message), "{detail}");
        });
    }
}

#[test]
fn deeply_nested_singletons_copy_changed_leaf_through_internal_call() {
    // 関門: 深い型の生成と両方向の走査を本番の接続で確認する。
    // 手書きのループが葉を変えるので、浅い固定部だけのコピーでは通らない。
    const DEPTH: usize = 32;
    let types = (0..DEPTH)
        .map(|i| {
            let child = if i == 0 {
                "u32".into()
            } else {
                format!("$t{}", i - 1)
            };
            format!("(type $t{i} (list {child}))")
        })
        .collect::<String>();
    let guest = format!(
        r#"(component
        (core module $m {}
            (func (export "run") (param $ptr i32) (param $len i32) (result i32)
                (local $p i32) (local $n i32)
                local.get $len i32.const 1 i32.ne if unreachable end
                local.get $ptr local.set $p i32.const {} local.set $n
                block $done loop $next
                    local.get $n i32.eqz br_if $done
                    local.get $p i32.load offset=4 i32.const 1 i32.ne if unreachable end
                    local.get $p i32.load local.set $p
                    local.get $n i32.const 1 i32.sub local.set $n br $next
                end end
                local.get $p local.get $p i32.load i32.const 7 i32.add i32.store
                i32.const 16 local.get $ptr i32.store
                i32.const 20 local.get $len i32.store i32.const 16))
        (core instance $i (instantiate $m)) {types}
        (func (export "run") (param "xs" $t{}) (result $t{})
            (canon lift (core func $i "run") (memory (core memory $i "memory"))
                (realloc (core func $i "realloc")))))"#,
        super::fixed_tests::MEMORY,
        DEPTH - 1,
        DEPTH - 1,
        DEPTH - 1
    );
    let plan = (0..DEPTH).fold(P::U32, |p, _| P::List(Box::new(p)));
    let fixture = fixture(&guest, vec![plan.clone()], Some(plan));
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let mut argument = Value::UInt32(19);
        for _ in 0..DEPTH {
            argument = list::from_iter_exact(ctx, 1, [argument].into_iter(), "test").unwrap();
        }
        let mut value = invoke(
            &fixture,
            &mut runtime,
            ctx,
            &[argument],
            Limits::default(),
            &mut None,
        )
        .unwrap();
        for _ in 0..DEPTH {
            let children = list::to_vec(ctx, value).unwrap();
            assert_eq!(children.len(), 1);
            value = children[0];
        }
        assert_eq!(value.as_uint32(), Some(26));
        // ゲスト内の書き換えを言語の入力の書き換えとして残さない。
        for _ in 0..DEPTH {
            argument = list::to_vec(ctx, argument).unwrap()[0];
        }
        assert_eq!(argument.as_uint32(), Some(19));
    });
}
