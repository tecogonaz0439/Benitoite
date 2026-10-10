#!/usr/bin/env bash
# 完了条件の共通の検査（設計書 07-03「実装の規約と静的な検査」）。
#
#   scripts/check.sh                 基準の版からの変更に応じて、走らせる検査を選ぶ（選んだ検査）
#   scripts/check.sh --full          全部の検査と、長いテスト（#[ignore = "long: ..."]）を走らせる（全体の検査）
#   scripts/check.sh --base <版>     変更を比べる基準の版（既定は origin/san_benito）
#   scripts/check.sh --only <検査,...> 名前を挙げた検査だけを走らせる（名前は --dry-run の表示の [ ] の中）
#   scripts/check.sh --none          検査を走らせない（設計者が不要と判断したとき）
#   scripts/check.sh --dry-run       選んだ検査と理由を示すだけで、走らせない
#
# 検査を始める前に、選んだ検査と、それを選んだ理由（変更したファイルの種類）を示す。
# どの種類にも当たらないファイルを変えたときと、基準の版が見つからないときは、全体の検査を
# 始めずに止まり（終了状態 3）、設計者に --full・--only・--none のどれで続けるかを決めてもらう。
# nightly が要る Miri と到達可能性の比較の長い実行は check-heap.sh に置き、
# runtime::heap を変えたときに選ぶ（全体の検査には含めない）。
# 言語仕様と付録の例は、cargo test の tests/spec_examples.rs で検査する。
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$BASH_SOURCE")/.." && pwd)"
cd "$repo_root"

features=gc-mark-sweep,heap-verify
base=origin/san_benito
full=0
dry_run=0
only=""
none=0
check_names="rust long licenses heap spec_examples reference_examples skill spec_coverage skill_eval python formal"

usage() {
    printf '%s\n' 'usage: scripts/check.sh [--full | --only <check,...> | --none] [--base <rev>] [--dry-run]' >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --full) full=1 ;;
        --dry-run) dry_run=1 ;;
        --none) none=1 ;;
        --only)
            [ "$#" -ge 2 ] || usage
            only="$2"
            shift
            ;;
        --base)
            [ "$#" -ge 2 ] || usage
            base="$2"
            shift
            ;;
        *) usage ;;
    esac
    shift
done

run_check() {
    local check_name="$1"
    shift

    printf '== %s\n' "$check_name"
    if "$@"; then
        return 0
    fi

    printf 'FAILED: %s\n' "$check_name" >&2
    exit 1
}

check_licenses() {
    if ! cargo deny --version >/dev/null 2>&1; then
        printf '%s\n' 'cargo-deny is unavailable. Install it with: cargo install cargo-deny --locked' >&2
        return 1
    fi

    cargo deny check licenses
}

check_placeholder_allows() {
    local source_file
    local failed=0

    while IFS= read -r source_file; do
        if ! grep -Fq 'todo!(' "$source_file"; then
            printf 'leftover placeholder allow: %s\n' "$source_file" >&2
            failed=1
        fi
    done < <(grep -rlF --include='*.rs' '#![allow(clippy::todo, unused_variables)]' crates/benitoite/src/ || true)

    return "$failed"
}

# 生成物（Skill の references と bundle.rs）を作り直し、追跡しているファイルが変わらないことを確かめる。
check_skill_generated() {
    local before after
    before="$(git status --porcelain -- crates/benitoite/skill crates/benitoite/src/cli/tools/skill/bundle.rs)"
    cargo run -q -p benitoite --example gen_skill >/dev/null
    after="$(git status --porcelain -- crates/benitoite/skill crates/benitoite/src/cli/tools/skill/bundle.rs)"
    if [ "$before" != "$after" ]; then
        printf '%s\n' 'generated Skill files are stale; commit the output of: cargo run -p benitoite --example gen_skill' >&2
        return 1
    fi
}

# 構文木を読むだけにし、__pycache__ を作らない。
check_python_tools() {
    python3 -c 'import ast, sys
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as source:
        ast.parse(source.read(), path)' tools/bench/*.py tools/skill-eval/*.py tools/spec-coverage/*.py tools/syntax-measure/*.py tools/syntax-measure/bntmeasure/*.py
}

check_formal() {
    local output
    output="$(cd formal && lake build 2>&1)" || {
        printf '%s\n' "$output" >&2
        return 1
    }
    if printf '%s\n' "$output" | grep -q 'declaration uses .sorry.'; then
        printf '%s\n' "$output" >&2
        printf '%s\n' 'formal/ has sorry' >&2
        return 1
    fi
}

# 選ぶ検査の印を、変数 sel_<検査> に置く。値は、その検査を選んだ理由（最初に当たったファイル）。
# macOS の bash 3.2 は連想配列を持たないので、間接参照で読み書きする。
any_selected=0
select_check() {
    local variable="sel_$1"
    if [ -z "${!variable:-}" ]; then
        printf -v "$variable" '%s' "$2"
        any_selected=1
    fi
}
has() {
    local variable="sel_$1"
    [ -n "${!variable:-}" ]
}
reason() {
    local variable="sel_$1"
    printf '%s' "${!variable:-}"
}

classify() {
    local file="$1"
    case "$file" in
        scripts/check-formal.sh) select_check formal "$file" ;;
        scripts/*|.cargo/*|rust-toolchain.toml|clippy.toml|rustfmt.toml|.gitignore)
            select_check full "$file"
            unclassified="$unclassified $file" ;;
        Cargo.toml|Cargo.lock|deny.toml|about.toml|about.hbs|crates/*/Cargo.toml)
            select_check rust "$file"
            select_check licenses "$file" ;;
        crates/benitoite/src/runtime/heap/*)
            select_check rust "$file"
            select_check long "$file"
            select_check heap "$file" ;;
        crates/benitoite/src/runtime/*|crates/benitoite/src/vm/*|crates/benitoite/src/refinterp/*)
            select_check rust "$file"
            select_check long "$file" ;;
        crates/*|fuzz/*)
            select_check rust "$file" ;;
        docs/design/01-spec/01-02-syntax.md)
            select_check spec_examples "$file"
            select_check spec_coverage "$file"
            select_check skill "$file" ;;
        docs/design/01-spec/*|docs/design/08-appendix/08-04-*)
            select_check spec_examples "$file"
            select_check spec_coverage "$file" ;;
        docs/design/00-overview/00-03-roadmap.md)
            select_check spec_coverage "$file" ;;
        docs/reference/benitoite.md)
            select_check reference_examples "$file" ;;
        tools/spec-coverage/*)
            select_check spec_coverage "$file"
            select_check python "$file" ;;
        tools/skill-eval/*)
            select_check skill_eval "$file"
            select_check python "$file" ;;
        tools/*)
            select_check python "$file" ;;
        formal/reviews/*)
            ;;
        formal/*)
            select_check formal "$file" ;;
        docs/*|*.md|assets/*|.claude/*|.agents/*|LICENSE*|NOTICE*)
            ;;
        *)
            select_check full "$file"
            unclassified="$unclassified $file" ;;
    esac
}

changed_files() {
    git diff --name-only "$base" --
    git ls-files --others --exclude-standard
}

if [ "$none" -eq 1 ]; then
    printf '%s\n' '== plan: no checks (--none)'
    exit 0
fi

unclassified=""
needs_decision=""
if [ -n "$only" ]; then
    for check in $(printf '%s' "$only" | tr ',' ' '); do
        case " $check_names " in
            *" $check "*) select_check "$check" "--only" ;;
            *)
                printf 'unknown check name: %s (known: %s)\n' "$check" "$check_names" >&2
                exit 2
                ;;
        esac
    done
    # 長いテストは処理系のテストの一部として走らせる。
    if has long; then
        select_check rust "--only long"
    fi
elif [ "$full" -eq 0 ]; then
    if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
        needs_decision="base $base is not a commit"
    else
        files="$(changed_files | sort -u)"
        count=0
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            count=$((count + 1))
            classify "$file"
        done <<<"$files"
        if has full; then
            needs_decision="files outside every kind:$unclassified"
        fi
    fi
fi

if [ "$full" -eq 1 ]; then
    for check in rust long licenses spec_examples spec_coverage reference_examples skill skill_eval python; do
        select_check "$check" "full check"
    done
fi

# 検査を始める前に、選んだ検査と理由を示す。
if [ "$full" -eq 1 ]; then
    printf '%s\n' '== plan: full check (requested with --full)'
elif [ -n "$only" ]; then
    printf '== plan: only %s\n' "$only"
else
    printf '== plan: selected checks against %s (%s changed file(s))\n' "$base" "$count"
fi
if [ "$any_selected" -eq 0 ]; then
    printf '   nothing to check: only documents changed\n'
fi
describe() {
    if has "$1"; then
        printf '   %-62s because of %s\n' "[$1] $2" "$(reason "$1")"
    fi
}
describe rust "format, lint, tests, gc-stress, placeholder allows, Skill"
describe long "long tests (#[ignore = \"long: ...\"], ~15 min more)"
describe licenses "licenses"
describe heap "scripts/check-heap.sh (nightly Miri, ~10 min)"
describe spec_examples "spec examples"
describe reference_examples "reference examples"
describe skill "generated Skill files"
describe spec_coverage "spec coverage (self-test and tally)"
describe skill_eval "skill-eval self-test"
describe python "Python tools compile"
describe formal "lake build in formal/"
# どの種類にも当たらないファイルがあるときは、始めずに止まり、続け方を設計者に決めてもらう。
if [ -n "$needs_decision" ]; then
    printf '== stop: %s\n' "$needs_decision"
    printf '%s\n' \
        '   Ask the designer, then rerun with one of:' \
        '     scripts/check.sh --full                 all checks and long tests' \
        "     scripts/check.sh --only <check,...>     some checks (names: $check_names)" \
        '     scripts/check.sh --none                 no checks'
    if [ "$dry_run" -eq 1 ]; then
        exit 0
    fi
    exit 3
fi
if [ "$dry_run" -eq 1 ]; then
    exit 0
fi

# 長いテストは #[ignore = "long: ..."] で印を付けてあり、--include-ignored で走らせる。
test_args=""
if has long; then
    test_args="--include-ignored"
fi

if has rust; then
    run_check "format" cargo fmt --all --check
    run_check "lint (mark-sweep)" cargo clippy --workspace --all-targets --no-default-features --features "$features",alloc-stats
    run_check "test (mark-sweep)" cargo test --workspace --no-default-features --features "$features" -- $test_args
    run_check "gc-stress (mark-sweep)" cargo test --workspace --no-default-features --features "$features",gc-stress --lib --tests -- $test_args
    run_check "leftover placeholder allows" check_placeholder_allows
    select_check skill "$(reason rust)"
else
    # 処理系のテストの全体を走らせないときは、文書を読むテストだけを走らせる。
    if has spec_examples; then
        run_check "spec examples" cargo test -q -p benitoite --test spec_examples
    fi
    if has reference_examples; then
        run_check "reference examples" cargo test -q -p benitoite --test reference_examples
    fi
    if has skill; then
        run_check "skill docs" cargo test -q -p benitoite --test skill_docs
    fi
fi
if has skill; then
    run_check "generated Skill files" check_skill_generated
fi
if has spec_coverage || has rust; then
    run_check "spec coverage tool" python3 tools/spec-coverage/spec_coverage.py --self-test
    run_check "spec coverage" python3 tools/spec-coverage/spec_coverage.py
fi
if has skill_eval; then
    run_check "skill-eval self-test" python3 tools/skill-eval/skill_eval.py --self-test
fi
if has python; then
    run_check "Python tools compile" check_python_tools
fi
if has licenses; then
    run_check "licenses" check_licenses
fi
if has formal; then
    run_check "formal (lake build)" check_formal
fi
if has heap; then
    run_check "heap checks" scripts/check-heap.sh
fi

printf 'all checks passed\n'
