//! 乱数の列・変換・純粋性と、IO の生成器の経路を確かめる（設計書 03-07「Random」、実装プラン L14）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::runtime_test_support::runtime;
use super::*;
use crate::builtins::iface::CallCtx;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::ExecMode;

// 関門: 版をまたぐ列を固定する契約は、共通の本体を使う差分テストでは守れない。
// L14 の指示に従い、参照の手順をテスト内に独立に書き下す。上端の判定は u128 で書く。
// 式の出典: https://prng.di.unimi.it/splitmix64.c
//           https://prng.di.unimi.it/xoshiro256starstar.c
// 作者の出力の値は取得していない。テストの参照実装で期待する列を求める。
struct Reference {
    state: [u64; 4],
    draws: usize,
}
impl Reference {
    fn new(seed: i64) -> Self {
        let mut x = u64::from_ne_bytes(seed.to_ne_bytes());
        let mut state = [0; 4];
        for word in &mut state {
            x = x.wrapping_add(0x9e3779b97f4a7c15);
            let z = (x ^ (x >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
            let z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
            *word = z ^ (z >> 31);
        }
        Self { state, draws: 0 }
    }
    fn next(&mut self) -> u64 {
        let result = self.state[1].wrapping_mul(5).rotate_left(7).wrapping_mul(9);
        let t = self.state[1] << 17;
        self.state[2] ^= self.state[0];
        self.state[3] ^= self.state[1];
        self.state[1] ^= self.state[2];
        self.state[0] ^= self.state[3];
        self.state[2] ^= t;
        self.state[3] = self.state[3].rotate_left(45);
        self.draws += 1;
        result
    }
    fn integer(&mut self, low: i64, high: i64) -> i64 {
        let n = u128::try_from(i128::from(high) - i128::from(low)).unwrap();
        let limit = (1_u128 << 64) - ((1_u128 << 64) % n);
        loop {
            let x = u128::from(self.next());
            if x < limit {
                return i64::try_from(i128::from(low) + i128::try_from(x % n).unwrap()).unwrap();
            }
        }
    }
    fn float(&mut self) -> f64 {
        (self.next() >> 11) as f64 * 2.0_f64.powi(-53)
    }
    fn shuffle<T>(&mut self, xs: &mut [T]) {
        for i in (1..xs.len()).rev() {
            let j = self.integer(0, i64::try_from(i + 1).unwrap());
            xs.swap(i, usize::try_from(j).unwrap());
        }
    }
}

fn split_pair<'e>(ctx: &ValueCtx<'e>, pair: Value<'e>) -> (Value<'e>, Value<'e>) {
    assert_eq!(
        ctx.fields_header(pair),
        Some((FieldsKind::Ctor, tags::PAIR))
    );
    assert_eq!(ctx.fields_len(pair), Some(2));
    (ctx.field(pair, 0).unwrap(), ctx.field(pair, 1).unwrap())
}
// 呼び出しの間だけ文脈を借り、結果の読み出しの前に借用を終える。
macro_rules! pure {
    ($ctx:expr, $function:ident, $($argument:expr),*) => {{
        let call = CallCtx::new($ctx, None, None, None);
        $function(call.pure_ctx(), $($argument),*)
    }};
}
macro_rules! unpack {
    ($ctx:expr, $result:expr) => {{
        let result = $result;
        split_pair($ctx, result)
    }};
}

fn ints<'e>(ctx: &ValueCtx<'e>, xs: Value<'e>) -> Vec<i64> {
    list::to_vec(ctx, xs)
        .unwrap()
        .into_iter()
        .map(|v| v.as_int().unwrap())
        .collect()
}
fn done(reply: IoReply<'_>) -> Value<'_> {
    let IoReply::Done(value) = reply else {
        panic!("random operation waited")
    };
    value
}

#[test]
fn fixed_seed_sequences_match_independent_reference_and_preserve_inputs() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for seed in [0, 1, -1, i64::MAX] {
            let mut reference = Reference::new(seed);
            let mut raw = Generator(seeded_state(u64::from_ne_bytes(seed.to_ne_bytes())));
            assert_eq!(raw.0, reference.state);
            for _ in 0..32 {
                assert_eq!(raw.next(), reference.next());
            }
            let mut reference = Reference::new(seed);
            let mut g = pure!(ctx, from_seed, seed).unwrap();
            for step in 0..32 {
                for (low, high) in [(17, 18), (-3, 3), (i64::MIN, 1), (i64::MIN, i64::MAX)] {
                    let p = pure!(ctx, next_integer, g, low, high).unwrap();
                    let (value, next) = unpack!(ctx, p);
                    let repeated = pure!(ctx, next_integer, g, low, high).unwrap();
                    assert_eq!(unpack!(ctx, repeated).0.as_int(), value.as_int());
                    assert_eq!(value.as_int(), Some(reference.integer(low, high)));
                    assert!(value.as_int().unwrap() >= low && value.as_int().unwrap() < high);
                    g = next;
                }
                let (value, next) = unpack!(ctx, pure!(ctx, next_float, g).unwrap());
                assert_eq!(value.as_float(), Some(reference.float()));
                assert!((0.0..1.0).contains(&value.as_float().unwrap()));
                g = next;
                let mut expected: Vec<i64> = (0..[0, 1, 6, 70][step % 4]).collect();
                let original = expected.clone();
                let xs = list::from_values(
                    ctx,
                    &expected.iter().copied().map(Value::Int).collect::<Vec<_>>(),
                    "test",
                )
                .unwrap();
                reference.shuffle(&mut expected);
                let (value, next) = unpack!(ctx, pure!(ctx, shuffle_with, g, xs).unwrap());
                assert_eq!(ints(ctx, value), expected);
                assert_eq!(ints(ctx, xs), original);
                // 次の出力で状態の進め方も確かめる。空と一要素では進めない。
                g = next;
            }
        }
    });
}

// 関門: 上端での棄却と負の端を含む幅の計算、診断の引数位置を守る。
// 小さい範囲の列だけでは、棄却や i64 の差の溢れを捕まえられない。
#[test]
fn rejected_draw_is_skipped_and_invalid_ranges_report_high_argument() {
    let seed = (0..1000)
        .find(|&seed| {
            let mut reference = Reference::new(seed);
            u128::from(reference.next()) > (1_u128 << 63)
        })
        .unwrap();
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let g = pure!(ctx, from_seed, seed).unwrap();
        let mut reference = Reference::new(seed);
        let expected = reference.integer(i64::MIN, 1);
        assert!(reference.draws > 1);
        let (value, next) = unpack!(ctx, pure!(ctx, next_integer, g, i64::MIN, 1).unwrap());
        assert_eq!(value.as_int(), Some(expected));
        let (value, _) = unpack!(ctx, pure!(ctx, next_float, next).unwrap());
        assert_eq!(value.as_float(), Some(reference.float()));
        for (low, high) in [(7, 7), (7, 6), (i64::MAX, i64::MIN)] {
            assert!(matches!(pure!(ctx, next_integer, g, low, high),
                Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {function, argument: 2}))
                if function == next_integer::DECL.name));
        }
    });
}

// 関門: 本物の IoView と組み込みの本体をつなぎ、IO が純粋な生成器と同じ手順を使うことを守る。
// スクリプトのハンドラで値を固定するテストは、IoServices の乱数の口を通さない。
#[test]
fn hidden_generator_matches_pure_operations_and_empty_choose_does_not_draw() {
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(std::path::Path::new("/"), ExecMode::Direct, &script);
    let mut resources = crate::runtime::io::resources::ResourceTable::default();
    rt.random_state = Reference::new(-1).state;
    let mut services = crate::runtime::io::services::IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let mut g = pure!(ctx, from_seed, -1).unwrap();
        for (low, high) in [(7, 8), (-3, 3), (i64::MIN, 1), (i64::MIN, i64::MAX)] {
            let (value, next) = unpack!(ctx, pure!(ctx, next_integer, g, low, high).unwrap());
            let hidden = done(integer(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), low, high).unwrap());
            assert_eq!(hidden.as_int(), value.as_int());
            g = next;
        }
        let (value, next) = unpack!(ctx, pure!(ctx, next_float, g).unwrap());
        assert_eq!(done(float(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap()).unwrap()).as_float(), value.as_float());
        g = next;
        let xs = list::from_values(ctx, &(0..70).map(Value::Int).collect::<Vec<_>>(), "test").unwrap();
        for xs in [Value::EmptyList, list::from_values(ctx, &[Value::Int(42)], "test").unwrap(), xs] {
            let (value, next) = unpack!(ctx, pure!(ctx, shuffle_with, g, xs).unwrap());
            let hidden = done(shuffle(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), xs).unwrap());
            assert_eq!(ints(ctx, hidden), ints(ctx, value));
            g = next;
        }
        let mut reference = Reference {state: generator(ctx, g).unwrap().0, draws: 0};
        for _ in 0..16 {
            let expected = reference.next() >> 63 != 0;
            let value = done(boolean(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap()).unwrap());
            assert_eq!(value.as_bool(), Some(expected));
        }
        let before = services.rt.random_state;
        let value = done(choose(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), Value::EmptyList).unwrap());
        assert!(matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))));
        assert_eq!(services.rt.random_state, before);
        for _ in 0..16 {
            let expected = reference.integer(0, 70);
            let value = done(choose(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), xs).unwrap());
            assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, tags::OPTION_SOME)));
            assert_eq!(ctx.field(value, 0).unwrap().as_int(), Some(expected));
        }
        for (low, high) in [(3, 3), (3, 2)] {
            let before = services.rt.random_state;
            assert!(matches!(integer(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), low, high),
                Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {function, argument: 1}))
                if function == integer::DECL.name));
            assert_eq!(services.rt.random_state, before);
        }
    });
}

// 関門: 本体への接続以外に、ハンドラの優先と二つの実行入口での OS の種の設定を守る。
// RunEnv::parts がある経路も本物の run_entry を通し、種を固定する差し込み口を作らない。
#[test]
fn scripts_handle_random_operations_and_both_run_entries_seed_the_generator() {
    use crate::bytecode::program::MainKind;
    use crate::runtime::assert::tests::{environment, prepare};
    use crate::runtime::run::{EndKind, run_program};
    let handled = super::super::runtime_test_support::compile(
        r#"
import Benitoite.Unofficial.IO.Random
function main() -> Result[Unit, String] uses Random.Generate
  bind values <- handle
    Pair(Random.integer(0, 1000000), Pair(Random.float(), Random.boolean()))
  with
    case Random.integer(_, _) -> resume(7)
    case Random.float() -> resume(0.5)
    case Random.boolean() -> resume(true)
    case Random.shuffle(xs) -> resume(xs)
    case Random.choose(_) -> resume(Option.None)
  end handle
  bind lists <- handle
    Pair(Random.shuffle([1, 2, 3]), Random.choose([1, 2, 3]))
  with
    case Random.integer(_, _) -> resume(7)
    case Random.float() -> resume(0.5)
    case Random.boolean() -> resume(true)
    case Random.shuffle(xs) -> resume(xs)
    case Random.choose(_) -> resume(Option.None)
  end handle
  return if values = Pair(7, Pair(0.5, true)) and lists = Pair([1, 2, 3], Option.None)
    then Result.Ok(()) else Result.Error("random handler") end if
end function
"#,
    );
    let samples = prepare(
        r#"
import Benitoite.Unofficial.IO.Random
import Benitoite.Unofficial.IO.Console
function main() -> Unit uses Random.Generate, Console.Write
  List.forEach([1, 2, 3, 4, 5, 6, 7, 8], lambda(_unused)
    Console.writeLine(Integer.toString(Random.integer(0, 1000000)))
  end lambda)
end function
@test
function randomIsSeeded() -> Unit uses Random.Generate, Assert.Check
  bind xs <- List.map([1, 2, 3, 4, 5, 6, 7, 8], lambda(_unused) return Random.integer(0, 1000000) end lambda)
  Assert.isTrue(xs <> [0, 0, 0, 0, 0, 0, 0, 0], "hidden generator was not seeded")
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        assert_eq!(
            run_program(&handled, environment(mode).0).end,
            EndKind::Returned
        );
        for supplied_parts in [false, true] {
            let mut outputs = Vec::new();
            for _ in 0..2 {
                let (mut env, capture) = environment(mode);
                if supplied_parts {
                    env.parts = Some(ScheduleHandle::new([], false).parts());
                }
                let end = run_program(&samples.program, env);
                assert_eq!(end.end, EndKind::Returned, "{:?}", end.reports);
                outputs.push(capture.stdout.lock().unwrap().clone());
            }
            assert_ne!(outputs[0], outputs[1]);
            let (mut env, _) = environment(mode);
            if supplied_parts {
                env.parts = Some(ScheduleHandle::new([], false).parts());
            }
            let end = samples.run("randomIsSeeded", MainKind::Unit, env);
            assert_eq!(
                end.run.end,
                EndKind::Returned,
                "{:?} {:?}",
                end.run.reports,
                end.check_failure
            );
        }
    }
}
