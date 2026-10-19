//! Property の公開関数を型検査から実行までつなぎ、生成・縮小・停止の契約を守る
//! （設計書 06-04「プロパティベーステスト」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::{InterruptSource, RunInput};
use benitoite::runtime::run::{
    self, EndKind, NoInterrupt, OutputTarget, RunEnd, RunEnv, StdinSource,
};
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

// 作成時の四問は g4/results.md に記録する。既存 Random の検査と分け、
// Property が公開する候補の順・予算・反例を本物のソースから観測する。
fn execute(source: &str) -> RunEnd {
    execute_with_interrupt(source, Box::new(NoInterrupt), None)
}

fn execute_with_interrupt(
    source: &str,
    interrupt: Box<dyn InterruptSource>,
    parts: Option<benitoite::runtime::sched::parts::RuntimeParts>,
) -> RunEnd {
    let checked = pipeline::check_text(
        "property.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = pipeline::compile(&core, checked.sources).unwrap();
    run::run_program(
        &program,
        RunEnv {
            input: RunInput {
                arguments: vec![],
                working_directory: "/".into(),
                script_directory: "/".into(),
            },
            stdin: StdinSource::Empty,
            stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            interrupt,
            parts,
            mode: ExecMode::Direct,
            vm: VmConfig::default(),
            heap: HeapConfig::default(),
            dev_panic_after_first_write: false,
        },
    )
}

fn script(body: &str) -> String {
    format!(
        r#"
import Benitoite.Unofficial.Test.Property
import Benitoite.Unofficial.IO.Random
function expect(condition: Boolean, message: String) -> Result[Unit, String]
  return if condition then Result.Ok(()) else Result.Error(message) end if
end function
function draw[T](gen: Property.Gen[T], seed: Integer, size: Integer) -> T
  bind run <- Property.Gen.run(gen)
  return Pair.first(run(generator: Random.fromSeed(seed), size: size))
end function
function samples[T](gen: Property.Gen[T], size: Integer) -> List[T]
  return List.map(xs: List.range(start: 0, stop: 80), f: lambda(value) return draw(gen: gen, seed: value, size: size) end lambda)
end function
function nonASCII(value: String) -> Boolean
  return hasNonASCII(cs: String.characters(value))
end function
function hasNonASCII(cs: List[Character]) -> Boolean
  return List.any(xs: cs, p: lambda(value) return Character.toInteger(value) > 127 end lambda)
end function
function allFour(xs: List[Integer]) -> Boolean
  return List.all(xs: xs, p: lambda(value) return value = 4 end lambda)
end function
function collect[T](steps: Property.ShrinkStep[T], acc: List[T]) -> List[T]
  return match steps with
    case Property.ShrinkStep.Done -> acc
    case Property.ShrinkStep.Skip(next) -> collect(steps: next(), acc: acc)
    case Property.ShrinkStep.Yield(value, next) -> collect(steps: next(), acc: List.append(xs: acc, x: value))
  end match
end function
function main() -> Result[Unit, String]
{body}
end function
"#
    )
}

fn succeeds(body: &str) {
    succeeds_source(&script(body));
}

fn succeeds_source(source: &str) {
    let result = execute(source);
    assert_eq!(result.end, EndKind::Returned, "{result:?}");
    assert_eq!(result.exit_code, 0, "{result:?}");
    assert!(result.main_error.is_none(), "{result:?}");
    assert!(result.reports.is_empty(), "{result:?}");
}

#[test]
fn inclusive_integers_finite_floats_unicode_and_empty_containers() {
    succeeds(
        r#"
  bind full <- try Property.integer(low: -9223372036854775808, high: 9223372036854775807)
  bind values <- samples(gen: full, size: 0)
  try expect(condition: List.contains(xs: values, x: -9223372036854775808) and List.contains(xs: values, x: 9223372036854775807) and List.contains(xs: values, x: 0), message: "full integer endpoints")
  bind positive <- try Property.integer(low: 3, high: 7)
  bind positives <- samples(gen: positive, size: 0)
  try expect(condition: List.contains(xs: positives, x: 3) and List.contains(xs: positives, x: 7) and List.all(xs: positives, p: lambda(value) return value >= 3 and value <= 7 end lambda), message: "inclusive nonzero bounds")
  try expect(condition: match Property.integer(low: 1, high: 0) with
    case Result.Error(_) -> true
    case _ -> false
  end match, message: "reversed bounds")
  bind fixed <- try Property.integer(low: -9223372036854775808, high: -9223372036854775808)
  bind runFixed <- Property.Gen.run(fixed)
  bind initial <- Random.fromSeed(-9223372036854775808)
  bind fixedPair <- runFixed(generator: initial, size: 0)
  try expect(condition: Pair.first(fixedPair) = -9223372036854775808 and Pair.first(Random.nextInteger(generator: Pair.second(fixedPair), low: 0, high: 1000)) = Pair.first(Random.nextInteger(generator: initial, low: 0, high: 1000)), message: "fixed does not advance state")
  bind floats <- samples(gen: Property.float(), size: 0)
  try expect(condition: List.all(xs: floats, p: lambda(value) return not Float.isNaN(value - value) and value >= -1.0 and value <= 1.0 end lambda) and List.contains(xs: floats, x: 0.0) and List.contains(xs: floats, x: 1.0) and List.contains(xs: floats, x: -1.0), message: "finite float branches")
  bind bools <- samples(gen: Property.boolean(), size: 0)
  try expect(condition: List.contains(xs: bools, x: true) and List.contains(xs: bools, x: false), message: "boolean branches")
  try expect(condition: List.all(xs: samples(gen: Property.string(), size: 0), p: lambda(value) return value = "" end lambda), message: "empty strings")
  try expect(condition: List.all(xs: samples(gen: Property.list(positive), size: 0), p: lambda(value) return List.isEmpty(value) end lambda), message: "empty lists")
  try expect(condition: List.all(xs: samples(gen: Property.stringMap(positive), size: 0), p: lambda(value) return Map.size(value) = 0 end lambda), message: "empty maps")
  bind strings <- samples(gen: Property.string(), size: 4)
  try expect(condition: List.all(xs: strings, p: lambda(value) return String.characterCount(value) <= 4 end lambda) and List.any(xs: strings, p: nonASCII), message: "Unicode scalars and size")
  bind options <- samples(gen: Property.option(positive), size: 0)
  try expect(condition: List.contains(xs: options, x: Option.None) and List.any(xs: options, p: lambda(value)
    return match value with
    case Option.Some(x) -> x >= 3 and x <= 7
    case _ -> false
    end match
  end lambda), message: "option branches")
  return Result.Ok(())
"#,
    );
}

#[test]
fn explicit_state_size_and_map_duplicate_contracts() {
    succeeds(
        r#"
  bind raw <- Property.Gen(run: lambda(generator, size)
    bind next <- Random.nextInteger(generator: generator, low: 0, high: 1000000)
    return Pair(Pair(Pair.first(next), size), Pair.second(next))
  end lambda)
  bind run <- Property.Gen.run(Property.both(left: raw, right: raw))
  bind initial <- Random.fromSeed(17)
  bind first <- Random.nextInteger(generator: initial, low: 0, high: 1000000)
  bind second <- Random.nextInteger(generator: Pair.second(first), low: 0, high: 1000000)
  bind pair <- run(generator: initial, size: 999)
  try expect(condition: Pair.first(pair) = Pair(Pair(Pair.first(first), 999), Pair(Pair.first(second), 999)), message: "both state and size")
  try expect(condition: Pair.first(Random.nextInteger(generator: Pair.second(pair), low: 0, high: 1000000)) = Pair.first(Random.nextInteger(generator: Pair.second(second), low: 0, high: 1000000)), message: "both final state")
  bind sizes <- Property.Gen(run: lambda(generator, size) return Pair(size, generator) end lambda)
  try expect(condition: draw(gen: Property.map(gen: sizes, f: lambda(value) return value + 1 end lambda), seed: 7, size: -5) = -4, message: "direct run does not clamp size")
  bind lists <- samples(gen: Property.list(sizes), size: 4)
  try expect(condition: List.all(xs: lists, p: lambda(value) return List.length(value) <= 4 and allFour(value) end lambda), message: "container size")
  bind pairGen <- Property.both(left: Property.string(), right: sizes)
  bind runPairs <- Property.Gen.run(Property.list(pairGen))
  bind runMap <- Property.Gen.run(Property.stringMap(sizes))
  bind pairs <- runPairs(generator: Random.fromSeed(21), size: 0)
  bind mapped <- runMap(generator: Random.fromSeed(21), size: 0)
  try expect(condition: List.isEmpty(Pair.first(pairs)) and Map.size(Pair.first(mapped)) = 0, message: "zero draws")
  return Result.Ok(())
"#,
    );
}

#[test]
fn builtin_shrinkers_have_ordered_distinct_candidates() {
    succeeds(
        r#"
  bind ints <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkInteger())(value), acc: []) end lambda
  try expect(condition: ints(8) = [0, 4, 2, 1] and ints(-8) = [0, -4, -2, -1] and ints(0) = [], message: "integer order")
  bind minimum <- ints(-9223372036854775808)
  try expect(condition: List.length(minimum) = 64 and List.head(minimum) = Option.Some(0) and List.get(xs: minimum, i: 63) = Option.Some(-1) and not List.contains(xs: minimum, x: -9223372036854775808), message: "minimum without abs overflow")
  bind floats <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkFloat())(value), acc: []) end lambda
  try expect(condition: floats(8.0) = [0.0, 4.0] and floats(-8.0) = [0.0, -4.0] and floats(0.0) = [] and floats(1e-323) = [0.0, 5e-324] and floats(5e-324) = [0.0], message: "finite float shrink")
  bind bools <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkBoolean())(value), acc: []) end lambda
  try expect(condition: bools(true) = [false] and bools(false) = [], message: "boolean shrink")
  bind options <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkOption(Property.shrinkInteger()))(value), acc: []) end lambda
  try expect(condition: options(Option.Some(2)) = [Option.None, Option.Some(0), Option.Some(1)] and options(Option.None) = [], message: "option order")
  bind noisy <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(value, lambda() return Property.ShrinkStep.Yield(0, lambda() return Property.ShrinkStep.Yield(0, lambda() return Property.ShrinkStep.Done end lambda) end lambda) end lambda) end lambda)
  bind lists <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkList(noisy))(value), acc: []) end lambda
  try expect(condition: lists([2, 2]) = [[], [2], [0, 2], [2, 0]] and lists([]) = [], message: "deletions then elements; unique and changed")
  bind noisyOptions <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkOption(noisy))(value), acc: []) end lambda
  try expect(condition: noisyOptions(Option.Some(2)) = [Option.None, Option.Some(0)], message: "option removes original and repeated element candidates")
  bind empty <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Done end lambda)
  bind deletions <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkList(empty))(value), acc: []) end lambda
  try expect(condition: deletions([1, 2, 3, 4]) = [[], [3, 4], [1, 4], [1, 2], [2, 3, 4], [1, 3, 4], [1, 2, 4], [1, 2, 3]], message: "halving widths and left-to-right deletion positions")
  bind strings <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkString())(value), acc: []) end lambda
  try expect(condition: strings("") = [] and List.take(xs: strings("é😀"), n: 3) = ["", "😀", "é"] and List.contains(xs: strings("é😀"), x: "\u{0}😀"), message: "scalar string shrink")
  try expect(condition: List.take(xs: strings("\u{1b000}"), n: 3) = ["", "\u{0}", "\u{6c00}"], message: "invalid surrogate half is skipped without losing the next scalar")
  bind maps <- lambda(value) return collect(steps: Property.Shrinker.candidates(Property.shrinkStringMap(noisy))(value), acc: []) end lambda
  bind original <- Map.fromList([Pair("b", 2), Pair("a", 2)])
  try expect(condition: maps(original) = [Map.fromList([Pair("b", 2)]), Map.fromList([Pair("a", 2)]), Map.fromList([Pair("a", 0), Pair("b", 2)]), Map.fromList([Pair("a", 2), Pair("b", 0)])] and maps(Map.empty()) = [], message: "map key order and unique values")
  return Result.Ok(())
"#,
    );
}

#[test]
fn configuration_is_validated_before_any_callback() {
    succeeds(
        r#"
  bind badGen <- Property.Gen(run: lambda(generator, size) return Pair(1 div (size - size), generator) end lambda)
  bind badShrink <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1 div (value - value), lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  bind badProperty <- lambda(value: Integer) -> Result[Unit, String] return if 1 div (value - value) = 0 then Result.Ok(()) else Result.Error("called") end if end lambda
  bind configs <- [Property.Config(seed: 0, trials: 0, size: 0, maxShrinks: 0, maxShrinkWork: 10000), Property.Config(seed: 0, trials: 10001, size: 0, maxShrinks: 0, maxShrinkWork: 10000), Property.Config(seed: 0, trials: 1, size: -1, maxShrinks: 0, maxShrinkWork: 10000), Property.Config(seed: 0, trials: 1, size: 10001, maxShrinks: 0, maxShrinkWork: 10000), Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: -1, maxShrinkWork: 10000), Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 100001, maxShrinkWork: 10000), Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 0, maxShrinkWork: -1), Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 0, maxShrinkWork: 1000001)]
  try expect(condition: List.all(xs: configs, p: lambda(value)
    return match Property.check(config: value, gen: badGen, shrinker: badShrink, property: badProperty) with
      case Result.Error(Property.CheckFailure.InvalidConfig(message)) -> not String.isEmpty(message)
      case _ -> false
    end match
  end lambda), message: "invalid configurations must not execute callbacks")
  bind sizes <- Property.Gen(run: lambda(generator, size) return Pair(size, generator) end lambda)
  return expect(condition: Property.check(config: Property.Config(seed: 9223372036854775807, trials: 10000, size: 10000, maxShrinks: 100000, maxShrinkWork: 1000000), gen: sizes, shrinker: badShrink, property: lambda(value)
    return if value = 10000 then Result.Ok(()) else Result.Error("size changed") end if
  end lambda) = Result.Ok(()), message: "inclusive config upper bounds and unchanged size")
"#,
    );
}

#[test]
fn shrinking_preserves_messages_counts_all_candidates_and_replays() {
    succeeds(
        r#"
  bind config <- Property.Config(seed: -9223372036854775808, trials: 3, size: 7, maxShrinks: 20, maxShrinkWork: 10000)
  bind property <- lambda(value: Integer) -> Result[Unit, String]
    return if value >= 3 then Result.Error("bad:" + Integer.toString(value)) else Result.Ok(()) end if
  end lambda
  bind result <- Property.check(config: config, gen: Property.constant(8), shrinker: Property.shrinkInteger(), property: property)
  bind replay <- Property.check(config: config, gen: Property.constant(8), shrinker: Property.shrinkInteger(), property: property)
  try expect(condition: result = replay, message: "same seed and callbacks replay")
  try expect(condition: match result with
    case Result.Error(Property.CheckFailure.Falsified(failure)) ->
      Property.Counterexample.config(failure) = config and Property.Counterexample.trial(failure) = 1 and Property.Counterexample.original(failure) = 8 and Property.Counterexample.reduced(failure) = 4 and Property.Counterexample.originalMessage(failure) = "bad:8" and Property.Counterexample.message(failure) = "bad:4" and Property.Counterexample.shrinks(failure) = 5 and Property.Counterexample.shrinkWork(failure) = 11 and not Property.Counterexample.limitReached(failure) and Property.Counterexample.libraryVersion(failure) = "2.0.0"
    case _ -> false
  end match, message: "last failing value and message, count successful candidates")
  bind formatted <- match result with
    case Result.Error(failure) -> Property.formatFailure(failure: failure, show: lambda(value) return Integer.toString(value) end lambda)
    case _ -> ""
  end match
  try expect(condition: String.contains(s: formatted, part: "seed=-9223372036854775808 trials=3 size=7 maxShrinks=20 maxShrinkWork=10000 trial=1 shrinks=5 shrinkWork=11 limitReached=false") and String.contains(s: formatted, part: "original: 8\noriginal message: bad:8\nreduced: 4\nmessage: bad:4") and String.contains(s: formatted, part: "library 2.0.0"), message: "format replay and concrete inputs")
  bind never <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1 div (value - value), lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  try expect(condition: Property.check(config: config, gen: Property.constant(0), shrinker: never, property: property) = Result.Ok(()), message: "success never calls shrinker")
  bind random <- Property.Gen(run: lambda(generator, size) return Random.nextInteger(generator: generator, low: 0, high: 1000000) end lambda)
  bind first <- Random.nextInteger(generator: Random.fromSeed(17), low: 0, high: 1000000)
  bind second <- Random.nextInteger(generator: Pair.second(first), low: 0, high: 1000000)
  try expect(condition: Pair.first(first) <> Pair.first(second), message: "distinct replay inputs")
  bind afterFirst <- Property.check(config: Property.Config(..config, seed: 17, trials: 2, maxShrinks: 0), gen: random, shrinker: never, property: lambda(value)
    return if value = Pair.first(first) then Result.Ok(()) else Result.Error("second") end if
  end lambda)
  try expect(condition: match afterFirst with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.trial(example) = 2 and Property.Counterexample.original(example) = Pair.first(second) and Property.Counterexample.message(example) = "second"
    case _ -> false
  end match, message: "trial number and next state after a passing trial")
  return Result.Ok(())
"#,
    );
}

#[test]
fn cyclic_equal_and_zero_budget_shrinkers_stop_without_equality_on_inputs() {
    succeeds(
        r#"
  bind failure <- lambda(value: Integer) -> Result[Unit, String] return Result.Error(Integer.toString(value)) end lambda
  bind cycle <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1 - value, lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  bind config <- Property.Config(seed: 9223372036854775807, trials: 1, size: 0, maxShrinks: 7, maxShrinkWork: 10000)
  try expect(condition: match Property.check(config: config, gen: Property.constant(0), shrinker: cycle, property: failure) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinks(example) = 7 and Property.Counterexample.reduced(example) = 1 and Property.Counterexample.message(example) = "1" and Property.Counterexample.limitReached(example)
    case _ -> false
  end match, message: "cycle consumes total budget")
  bind noCalls <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1 div (value - value), lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  try expect(condition: match Property.check(config: Property.Config(..config, maxShrinks: 0), gen: Property.constant(8), shrinker: noCalls, property: failure) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.original(example) = 8 and Property.Counterexample.reduced(example) = 8 and Property.Counterexample.shrinks(example) = 0 and Property.Counterexample.message(example) = "8" and Property.Counterexample.limitReached(example)
    case _ -> false
  end match, message: "zero budget never calls shrinker")
  bind callable <- lambda(value: Integer) return value end lambda
  bind callableShrink <- Property.Shrinker(candidates: lambda(value: function(value: Integer) -> Integer) return Property.ShrinkStep.Yield(value, lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  return expect(condition: match Property.check(config: Property.Config(..config, maxShrinks: 2), gen: Property.constant(callable), shrinker: callableShrink, property: lambda(value) return Result.Error(Integer.toString(value(9))) end lambda) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinks(example) = 2 and Property.Counterexample.message(example) = "9" and Property.Counterexample.limitReached(example)
    case _ -> false
  end match, message: "no equality constraint and equal candidates consume budget")
"#,
    );
}

#[test]
fn runtime_failures_from_each_callback_propagate() {
    for body in [
        r#"
  bind gen <- Property.Gen(run: lambda(generator, size) return Pair(1 div size, generator) end lambda)
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 3, maxShrinkWork: 10000), gen: gen, shrinker: Property.shrinkInteger(), property: lambda(value) return Result.Error("property") end lambda)
  return Result.Ok(())
"#,
        r#"
  bind shrinker <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1 div value, lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 3, maxShrinkWork: 10000), gen: Property.constant(0), shrinker: shrinker, property: lambda(value) return Result.Error("property") end lambda)
  return Result.Ok(())
"#,
        r#"
  bind shrinker <- Property.Shrinker(candidates: lambda(value: Integer)
    return Property.ShrinkStep.Skip(lambda() return Property.ShrinkStep.Yield(1 div value, lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  end lambda)
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 3, maxShrinkWork: 10000), gen: Property.constant(0), shrinker: shrinker, property: lambda(value) return Result.Error("property") end lambda)
  return Result.Ok(())
"#,
        r#"
  bind shrinker <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1, lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 3, maxShrinkWork: 10000), gen: Property.constant(0), shrinker: shrinker, property: lambda(value)
    if value = 0 then
      return Result.Error("original")
    end if
    return if 1 div (value - 1) = 0 then Result.Ok(()) else Result.Error("candidate") end if
  end lambda)
  return Result.Ok(())
"#,
        r#"
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 3, maxShrinkWork: 10000), gen: Property.constant(0), shrinker: Property.shrinkInteger(), property: lambda(value) return if 1 div value = 0 then Result.Ok(()) else Result.Error("property") end if end lambda)
  return Result.Ok(())
"#,
    ] {
        let result = execute(&script(body));
        assert_eq!(result.end, EndKind::Stopped, "{result:?}");
        assert_eq!(result.reports.len(), 1, "{result:?}");
        assert_eq!(
            result.reports.first().unwrap().code,
            Some(benitoite::diag::codes::DiagCode::R0101)
        );
    }
}

#[test]
fn duplicate_map_keys_keep_first_and_consume_each_draw() {
    let source = format!(
        "{}\n{}",
        script("  return checkMaps(seed: 0, sawDuplicate: false)"),
        r#"
function checkMaps(seed: Integer, sawDuplicate: Boolean) -> Result[Unit, String]
  if seed = 200 then
    return expect(condition: sawDuplicate, message: "exercised duplicate key draws")
  end if
  bind numbers <- Property.Gen(run: lambda(generator, size) return Random.nextInteger(generator: generator, low: 0, high: 1000000) end lambda)
  bind runPairs <- Property.Gen.run(Property.list(Property.both(left: Property.string(), right: numbers)))
  bind runMap <- Property.Gen.run(Property.stringMap(numbers))
  bind pairs <- runPairs(generator: Random.fromSeed(seed), size: 2)
  bind mapped <- runMap(generator: Random.fromSeed(seed), size: 2)
  try expect(condition: Pair.first(Random.nextInteger(generator: Pair.second(pairs), low: 0, high: 1000000)) = Pair.first(Random.nextInteger(generator: Pair.second(mapped), low: 0, high: 1000000)), message: "map consumes exactly the attempted draws")
  return match Pair(List.get(xs: Pair.first(pairs), i: 0), List.get(xs: Pair.first(pairs), i: 1)) with
    case Pair(Option.Some(first), Option.Some(second)) ->
      if Pair.first(first) = Pair.first(second) then
        try expect(condition: Map.size(Pair.first(mapped)) = 1 and Map.get(m: Pair.first(mapped), k: Pair.first(first)) = Option.Some(Pair.second(first)), message: "first duplicate value survives")
        checkMaps(seed: seed + 1, sawDuplicate: true)
      else
        checkMaps(seed: seed + 1, sawDuplicate: sawDuplicate)
      end if
    case _ -> checkMaps(seed: seed + 1, sawDuplicate: sawDuplicate)
  end match
end function
"#
    );
    succeeds_source(&source);
}

#[test]
fn effectful_callbacks_are_rejected_at_the_public_contract() {
    for call in [
        r#"Property.check(config: config, gen: Property.constant(0), shrinker: Property.shrinkInteger(), property: lambda(value)
    Process.exit(0)
    return Result.Ok(())
  end lambda)"#,
        r#"Property.check(config: config, gen: Property.constant(0), shrinker: Property.shrinkInteger(), property: lambda(value)
    Console.writeLine("effect")
    return Result.Ok(())
  end lambda)"#,
        r#"Property.Gen(run: lambda(generator, size)
    Process.exit(0)
    return Pair(0, generator)
  end lambda)"#,
        r#"Property.Shrinker(candidates: lambda(value: Integer)
    Assert.isTrue(condition: false, message: "effect")
    return Property.ShrinkStep.Yield(value, lambda() return Property.ShrinkStep.Done end lambda)
  end lambda)"#,
        r#"Property.mapSteps(steps: Property.ShrinkStep.Yield(0, lambda() return Property.ShrinkStep.Done end lambda), f: lambda(value)
    Process.exit(0)
    return value
  end lambda)"#,
        r#"Property.appendSteps(left: Property.ShrinkStep.Done, right: lambda()
    Console.writeLine("effect")
    return Property.ShrinkStep.Yield(0, lambda() return Property.ShrinkStep.Done end lambda)
  end lambda)"#,
    ] {
        let source = format!(
            r#"
import Benitoite.Unofficial.Test.Property
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Unit
  bind config <- Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 1, maxShrinkWork: 10000)
  bind result <- {call}
  return ()
end function
"#
        );
        let checked = pipeline::check_text(
            "property-effects.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 1, "{:?}", checked.diagnostics);
        assert!(
            checked.diagnostics.iter().any(|diagnostic| {
                diagnostic.code == Some(benitoite::diag::codes::DiagCode::E0401)
            }),
            "{:?}",
            checked.diagnostics
        );
    }
}

#[test]
fn interruption_remains_a_runtime_stop_during_property_trials() {
    use std::sync::atomic::{AtomicBool, Ordering};
    #[derive(Debug)]
    struct Flag(Arc<AtomicBool>);
    impl InterruptSource for Flag {
        fn requested(&self) -> bool {
            self.0.load(Ordering::Relaxed)
        }
        fn flag(&self) -> Option<&AtomicBool> {
            Some(&self.0)
        }
    }
    #[derive(Debug)]
    struct InterruptPicker(Arc<AtomicBool>);
    impl benitoite::runtime::sched::parts::TaskPicker for InterruptPicker {
        fn pick(
            &mut self,
            ready: &std::collections::VecDeque<benitoite::vm::TaskId>,
        ) -> Option<usize> {
            if ready.is_empty() {
                return None;
            }
            self.0.store(true, Ordering::Relaxed);
            Some(0)
        }
    }
    let source = script(
        r#"
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 10000, size: 0, maxShrinks: 100000, maxShrinkWork: 10000), gen: Property.constant(1), shrinker: Property.shrinkInteger(), property: lambda(value) return Result.Ok(()) end lambda)
  return Result.Ok(())
"#,
    );
    let flag = Arc::new(AtomicBool::new(false));
    let mut parts = benitoite::runtime::sched::testing::ScheduleHandle::new([], false).parts();
    parts.picker = Box::new(InterruptPicker(Arc::clone(&flag)));
    let result = execute_with_interrupt(&source, Box::new(Flag(flag)), Some(parts));
    assert_eq!(result.end, EndKind::Interrupted, "{result:?}");
    assert_eq!(result.exit_code, 130, "{result:?}");
    assert!(result.main_error.is_none(), "{result:?}");
}

// 続きを呼ばないとDoneが分からない場合と、Doneを取得済みの場合を区別する。
#[test]
fn unknown_continuation_at_exact_budget_reports_limit() {
    succeeds(
        r#"
  bind shrinker <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(0, lambda() return Property.ShrinkStep.Yield(1, lambda() return Property.ShrinkStep.Done end lambda) end lambda) end lambda)
  bind property <- lambda(value: Integer) -> Result[Unit, String]
    return if value = 8 then Result.Error("original failure") else Result.Ok(()) end if
  end lambda
  return expect(condition: List.all(xs: [1, 2, 3], p: lambda(value)
    bind budget <- value
    return match Property.check(config: Property.Config(seed: 17, trials: 1, size: 0, maxShrinks: budget, maxShrinkWork: 10000), gen: Property.constant(8), shrinker: shrinker, property: property) with
      case Result.Error(Property.CheckFailure.Falsified(failure)) ->
        Property.Counterexample.shrinks(failure) = (if budget = 1 then 1 else 2 end if)
          and Property.Counterexample.limitReached(failure) = (budget <= 2)
          and Property.Counterexample.original(failure) = 8
          and Property.Counterexample.reduced(failure) = 8
          and Property.Counterexample.message(failure) = "original failure"
      case _ -> false
    end match
  end lambda), message: "limit when the remaining continuation is unknown")
"#,
    );
}

#[test]
fn shrink_steps_preserve_single_transitions_and_defer_callbacks() {
    succeeds_source(&format!(
        "{}\n{}",
        script(
            r#"
  bind crash <- lambda() -> Property.ShrinkStep[Integer]
    return Property.ShrinkStep.Yield(1 div 0, lambda() return Property.ShrinkStep.Done end lambda)
  end lambda
  try expect(condition: match Property.mapSteps(steps: Property.ShrinkStep.Done, f: lambda(value: Integer) return 1 div value end lambda) with
    case Property.ShrinkStep.Done -> true
    case _ -> false
  end match, message: "Done does not map or advance")
  try expect(condition: match Property.appendSteps(left: Property.ShrinkStep.Done, right: crash) with
    case Property.ShrinkStep.Skip(_) -> true
    case _ -> false
  end match, message: "Done defers right to a separate step")
  try expect(condition: match Property.mapSteps(steps: Property.ShrinkStep.Skip(crash), f: lambda(value) return 1 div value end lambda) with
    case Property.ShrinkStep.Skip(_) -> true
    case _ -> false
  end match, message: "Skip calls neither its continuation nor the mapper")
  bind head <- Property.mapSteps(steps: Property.ShrinkStep.Yield(3, crash), f: lambda(value) return value + 1 end lambda)
  try expect(condition: match Property.appendSteps(left: head, right: crash) with
    case Property.ShrinkStep.Yield(value, _) -> value = 4
    case _ -> false
  end match, message: "Yield maps just its value without advancing either side")
  bind left <- Property.ShrinkStep.Yield(1, lambda()
    return Property.ShrinkStep.Skip(lambda() return Property.ShrinkStep.Done end lambda)
  end lambda)
  bind joined <- Property.appendSteps(left: left, right: lambda()
    return Property.ShrinkStep.Yield(9, lambda() return Property.ShrinkStep.Done end lambda)
  end lambda)
  try expect(condition: stepTrace(joined) = "Y1;S;S;Y9;D", message: "left Skip survives and right starts only after left Done")
  bind mapped <- Property.mapSteps(steps: joined, f: lambda(value) return Integer.toString(value * 2) end lambda)
  try expect(condition: textTrace(mapped) = "Y2;S;S;Y18;D", message: "mapping keeps every continuation boundary and changes the type")
  bind callable <- Property.ShrinkStep.Yield(lambda(value: Integer) return value + 5 end lambda, lambda() return Property.ShrinkStep.Done end lambda)
  return expect(condition: stepTrace(Property.mapSteps(steps: callable, f: lambda(value) return value(2) end lambda)) = "Y7;D", message: "composition requires no equality on input values")
"#,
        ),
        r#"
function stepTrace(steps: Property.ShrinkStep[Integer]) -> String
  return match steps with
    case Property.ShrinkStep.Done -> "D"
    case Property.ShrinkStep.Skip(next) -> "S;" + stepTrace(next())
    case Property.ShrinkStep.Yield(value, next) -> "Y" + Integer.toString(value) + ";" + stepTrace(next())
  end match
end function
function textTrace(steps: Property.ShrinkStep[String]) -> String
  return match steps with
    case Property.ShrinkStep.Done -> "D"
    case Property.ShrinkStep.Skip(next) -> "S;" + textTrace(next())
    case Property.ShrinkStep.Yield(value, next) -> "Y" + value + ";" + textTrace(next())
  end match
end function
"#
    ));
}

#[test]
fn deeply_composed_skip_sequences_advance_without_stack_growth() {
    // gc-stress は確保のたびに回収するので、深さ 1024 の合成では 1 件が数時間かかる。大きさだけを下げ、
    // 元の大きさは既定と heap-verify の構成で確かめる。
    let (skips, wraps) = if cfg!(feature = "gc-stress") {
        (8, 32)
    } else {
        (64, 1024)
    };
    succeeds_source(&format!(
        "{}\n{}",
        script(&format!(
            r#"
  bind steps <- wrapSteps(steps: skipSteps({skips}), remaining: {wraps})
  return expect(condition: countSteps(steps: steps, skips: 0, yielded: []) = Pair({total}, [{value}]), message: "deep map/append composition retains all Skips and values")
"#,
            total = skips + wraps,
            value = 7 + wraps,
        )),
        r#"
function skipSteps(remaining: Integer) -> Property.ShrinkStep[Integer]
  if remaining = 0 then
    return Property.ShrinkStep.Yield(7, lambda() return Property.ShrinkStep.Done end lambda)
  end if
  return Property.ShrinkStep.Skip(lambda() return skipSteps(remaining - 1) end lambda)
end function
function wrapSteps(steps: Property.ShrinkStep[Integer], remaining: Integer) -> Property.ShrinkStep[Integer]
  if remaining = 0 then
    return steps
  end if
  return wrapSteps(steps: Property.mapSteps(steps: Property.appendSteps(left: steps, right: lambda() return Property.ShrinkStep.Done end lambda), f: lambda(value) return value + 1 end lambda), remaining: remaining - 1)
end function
function countSteps(steps: Property.ShrinkStep[Integer], skips: Integer, yielded: List[Integer]) -> Pair[Integer, List[Integer]]
  return match steps with
    case Property.ShrinkStep.Done -> Pair(skips, yielded)
    case Property.ShrinkStep.Skip(next) -> countSteps(steps: next(), skips: skips + 1, yielded: yielded)
    case Property.ShrinkStep.Yield(value, next) -> countSteps(steps: next(), skips: skips, yielded: List.append(xs: yielded, x: value))
  end match
end function
"#
    ));
}

#[test]
fn work_budget_counts_generation_continuations_and_trials_without_peeking() {
    succeeds_source(&format!(
        "{}\n{}",
        script(
            r#"
  bind config <- Property.Config(seed: 1, trials: 1, size: 0, maxShrinks: 20, maxShrinkWork: 10000)
  bind noCalls <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(1 div 0, crash) end lambda)
  bind property <- lambda(value: Integer) -> Result[Unit, String]
    return if value = 8 then Result.Error("original") else Result.Ok(()) end if
  end lambda
  try expect(condition: List.all(xs: [Property.Config(..config, maxShrinks: 0), Property.Config(..config, maxShrinkWork: 0)], p: lambda(value)
    return match Property.check(config: value, gen: Property.constant(8), shrinker: noCalls, property: property) with
      case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinks(example) = 0 and Property.Counterexample.shrinkWork(example) = 0 and Property.Counterexample.limitReached(example) and Property.Counterexample.reduced(example) = 8
      case _ -> false
    end match
  end lambda), message: "either zero budget skips candidates entirely")
  bind steps <- Property.Shrinker(candidates: lambda(value: Integer)
    return Property.ShrinkStep.Skip(lambda() return Property.ShrinkStep.Yield(0, lambda() return Property.ShrinkStep.Done end lambda) end lambda)
  end lambda)
  try expect(condition: List.all(xs: [1, 2, 3, 4], p: lambda(value)
    return match Property.check(config: Property.Config(..config, maxShrinkWork: value), gen: Property.constant(8), shrinker: steps, property: property) with
      case Result.Error(Property.CheckFailure.Falsified(example)) ->
        Property.Counterexample.shrinkWork(example) = value
          and Property.Counterexample.shrinks(example) = (if value < 3 then 0 else 1 end if)
          and Property.Counterexample.limitReached(example) = (value < 4)
          and Property.Counterexample.reduced(example) = 8 and Property.Counterexample.message(example) = "original"
      case _ -> false
    end match
  end lambda), message: "Skip, Yield, property and Done each use exactly one work unit")
  bind done <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Done end lambda)
  try expect(condition: match Property.check(config: Property.Config(..config, maxShrinkWork: 1), gen: Property.constant(8), shrinker: done, property: property) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinkWork(example) = 1 and Property.Counterexample.shrinks(example) = 0 and not Property.Counterexample.limitReached(example)
    case _ -> false
  end match, message: "Done known at the exact work limit is complete")
  bind guarded <- Property.Shrinker(candidates: lambda(value: Integer) return Property.ShrinkStep.Yield(0, crash) end lambda)
  try expect(condition: match Property.check(config: Property.Config(..config, maxShrinkWork: 2), gen: Property.constant(8), shrinker: guarded, property: property) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinks(example) = 1 and Property.Counterexample.shrinkWork(example) = 2 and Property.Counterexample.limitReached(example)
    case _ -> false
  end match, message: "no continuation is called just to peek at Done")
  bind restarts <- Property.Shrinker(candidates: lambda(value: Integer)
    return if value <= 2 then Property.ShrinkStep.Done else Property.ShrinkStep.Yield(value div 2, crash) end if
  end lambda)
  try expect(condition: List.all(xs: [4, 5], p: lambda(value)
    bind budget <- value
    return match Property.check(config: Property.Config(..config, maxShrinkWork: budget), gen: Property.constant(8), shrinker: restarts, property: alwaysFailure) with
      case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinks(example) = 2 and Property.Counterexample.shrinkWork(example) = budget and Property.Counterexample.reduced(example) = 2 and Property.Counterexample.message(example) = "2" and Property.Counterexample.limitReached(example) = (budget = 4)
      case _ -> false
    end match
  end lambda), message: "restart discards old continuation and retains cumulative budgets")
  bind duplicate <- Property.Shrinker.candidates(Property.shrinkOption(Property.shrinkInteger()))
  return expect(condition: match duplicate(Option.Some(2)) with
    case Property.ShrinkStep.Skip(next) -> match next() with
      case Property.ShrinkStep.Yield(Option.None, _) -> true
      case _ -> false
    end match
    case _ -> false
  end match, message: "candidate generation and original comparison are distinct steps")
"#,
        ),
        r#"
function alwaysFailure(value: Integer) -> Result[Unit, String]
  return Result.Error(Integer.toString(value))
end function
function crash() -> Property.ShrinkStep[Integer]
  return Property.ShrinkStep.Yield(1 div 0, crash)
end function
"#
    ));
}

#[test]
fn obsolete_list_shrinkers_and_incomplete_config_are_rejected() {
    for (body, code) in [
        (
            "  bind shrinker: Property.Shrinker[Integer] <- Property.Shrinker(candidates: lambda(value) return [0] end lambda)\n  return Result.Ok(())",
            benitoite::diag::codes::DiagCode::E0401,
        ),
        (
            "  bind config <- Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 1)\n  return Result.Ok(())",
            benitoite::diag::codes::DiagCode::E0428,
        ),
    ] {
        let checked = pipeline::check_text(
            "property-old.bnt",
            script(body).as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 1, "{:?}", checked.diagnostics);
        assert!(
            checked
                .diagnostics
                .iter()
                .any(|diagnostic| diagnostic.code == Some(code)),
            "{:?}",
            checked.diagnostics
        );
    }
}

#[test]
#[ignore = "long: drives the public maxShrinkWork upper bound of 1000000"]
fn maximum_work_budget_advances_skip_sequences_without_stack_growth() {
    // gc-stress は確保のたびに回収するので、公開の上限まで駆動すると数日かかる。gc-stress では予算だけを下げ、
    // 上限そのものは heap の構成の実行で確かめる。
    let work = if cfg!(feature = "gc-stress") {
        2000
    } else {
        1000000
    };
    succeeds_source(&format!(
        "{}\n{}",
        script(&format!(
            r#"
  bind shrinker <- Property.Shrinker(candidates: lambda(value: Integer)
    return Property.mapSteps(steps: Property.appendSteps(left: endless(), right: lambda() return Property.ShrinkStep.Done end lambda), f: identity)
  end lambda)
  return expect(condition: match Property.check(config: Property.Config(seed: 1, trials: 1, size: 0, maxShrinks: 100000, maxShrinkWork: {work}), gen: Property.constant(8), shrinker: shrinker, property: lambda(value) return Result.Error("original") end lambda) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.shrinkWork(example) = {work} and Property.Counterexample.shrinks(example) = 0 and Property.Counterexample.limitReached(example) and Property.Counterexample.reduced(example) = 8 and Property.Counterexample.message(example) = "original"
    case _ -> false
  end match, message: "upper work budget bounds an unending composed Skip stream")
"#
        )),
        r#"
function identity(value: Integer) -> Integer
  return value
end function
function endless() -> Property.ShrinkStep[Integer]
  return Property.ShrinkStep.Skip(endless)
end function
"#
    ));
}

// 関門: Yield後のOk継続とError後の候補の取り直しを上限まで駆動する。
// Skipだけの既存例はこの二分岐を通らない。反例と正確な予算を公開APIで観測する。
#[test]
#[ignore = "long: drives 100000 Yield candidates through Ok continuation and Error restart"]
fn maximum_shrinks_budget_drives_yield_continuations_without_stack_growth() {
    // gc-stress では上限だけを下げる（前のテストと同じ理由）。
    let shrinks: i64 = if cfg!(feature = "gc-stress") {
        200
    } else {
        100000
    };
    let last = 8 - shrinks;
    for (property, reduced, message) in [
        (
            "if value = 8 then Result.Error(\"original\") else Result.Ok(()) end if".to_string(),
            8,
            "original".to_string(),
        ),
        (
            "Result.Error(Integer.toString(value))".to_string(),
            last,
            last.to_string(),
        ),
    ] {
        succeeds_source(&format!(
            "{}\n{}",
            script(&format!(
                r#"
  bind shrinker <- Property.Shrinker(candidates: lambda(value: Integer) return yielding(value - 1) end lambda)
  return expect(condition: match Property.check(config: Property.Config(seed: 1, trials: 1, size: 0, maxShrinks: {shrinks}, maxShrinkWork: 1000000), gen: Property.constant(8), shrinker: shrinker, property: lambda(value) return {property} end lambda) with
    case Result.Error(Property.CheckFailure.Falsified(example)) -> Property.Counterexample.original(example) = 8 and Property.Counterexample.shrinks(example) = {shrinks} and Property.Counterexample.shrinkWork(example) = {work} and Property.Counterexample.limitReached(example) and Property.Counterexample.reduced(example) = {reduced} and Property.Counterexample.message(example) = "{message}"
    case _ -> false
  end match, message: "Yield continuation and restart at maxShrinks")
"#,
                work = 2 * shrinks,
            )),
            r#"
function yielding(value: Integer) -> Property.ShrinkStep[Integer]
  return Property.ShrinkStep.Yield(value, lambda() return yielding(value) end lambda)
end function
"#
        ));
    }
}
