#!/usr/bin/env bash
# 完了条件の共通の検査（設計書 07-03「実装の規約と静的な検査」）。
#
#   scripts/check.sh                 work として変更に関係する作業末の検査を選ぶ
#   scripts/check.sh --level work|stage|change|release  作業・段・改造・公開候補の検査
#   scripts/check.sh --test <名前>    関係する統合ターゲット（work/stage。繰り返せる）
#   scripts/check.sh --full          互換の旧集合（長いテストと release のスタック対象を含む）
#   scripts/check.sh --base <版>     変更を比べる基準の版（既定は origin/san_benito）
#   scripts/check.sh --only <検査,...> 名前を挙げた検査だけを走らせる（名前は --dry-run の表示の [ ] の中）
#   scripts/check.sh --none          検査を走らせない（設計者が不要と判断したとき）
#   scripts/check.sh --dry-run       選んだ検査と理由を示すだけで、走らせない
#
# 検査を始める前に、選んだ検査と、それを選んだ理由（変更したファイルの種類）を示す。
# どの種類にも当たらないファイルを変えたときと、基準の版が見つからないときは、全体の検査を
# 始めずに止まり（終了状態 3）、設計者に当該水準の --level … --only、互換の --full・--only、--none の続け方を決めてもらう。
# nightly が要る Miri と到達可能性の比較の長い実行は check-heap.sh に置き、
# work/change は heap/ の変更で heap_checks を選ぶ。局所の特殊構成と必要な本体の検査は
# 次の作業の前提にする前に通し、最後の関係状態への成功は引用できる。
# Rust の work は lib_default、change は test_default_all に既定の lib を含める。
# 水準なしの旧 only/full は従来の集合を保つ。default_lib は旧名のまま名指しできる。
# 旧 full は heap/formal や二構成 all-targets を追加せず、change/release の別名ではない。
# stage は名指しの接続のみ。release は release_stack と、別途行う候補・証拠の手動照合。
# 指定の誤りは 2、分類不能・基準不明は dry-run も 3、検査失敗・道具不在は 1、選択の成功は 0。
# level と only の併用は分類しない部分選択で、base は表示にだけ使う。
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
level=""
tests=()
seen_options=" "
check_names="rust default_lib long release_stack licenses heap spec_examples reference_examples skill spec_coverage skill_eval python formal policy_selftest"
work_names="fmt lint_default lint_heap doc_default lib_default tests_related source_rules skill_generated spec_tally spec_examples reference_examples skill_docs python_syntax migrate_selftests skill_eval_selftest licenses policy_selftest heap_local stress_local heap_checks formal_build release_stack"
stage_names="tests_related heap_local stress_local policy_selftest"
change_names="fmt lint_default lint_heap test_default_all test_heap_all test_stress doc_default source_rules skill_generated spec_tally spec_examples reference_examples skill_docs python_syntax migrate_selftests skill_eval_selftest licenses policy_selftest long_only heap_checks formal_build release_stack"
release_names="release_stack"
# work の既存の実行順を保ち、change 固有の全件検査を lib の位置へ並べる。
unit_names="fmt lint_default lint_heap lib_default tests_related test_default_all test_heap_all test_stress doc_default source_rules skill_generated spec_tally spec_examples reference_examples skill_docs python_syntax migrate_selftests skill_eval_selftest licenses policy_selftest heap_local stress_local long_only heap_checks formal_build release_stack"

usage() {
    printf 'error: %s\n' "$1" >&2
    printf '%s\n' 'usage: scripts/check.sh [--level work|stage|change|release] [--only <check,...>] [--test <target> ...] [--base <rev>] [--dry-run]' \
        '       scripts/check.sh [--full | --only <legacy-check,...> | --none] [--base <rev>] [--dry-run]' >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    if [ "$1" != --test ]; then
        case "$seen_options" in *" $1 "*) usage "duplicate option: $1" ;; esac
        seen_options="$seen_options$1 "
    fi
    case "$1" in
        --full) full=1 ;;
        --dry-run) dry_run=1 ;;
        --none) none=1 ;;
        --only|--base|--level|--test)
            [ "$#" -ge 2 ] || usage "$1 requires a value"
            [ -n "$2" ] || usage "$1 requires a nonempty value"
            case "$2" in --*) usage "$1 requires a value before $2" ;; esac
            case "$1" in
                --only) only="$2" ;;
                --base) base="$2" ;;
                --level) level="$2" ;;
                --test)
                    # bash 3.2 の set -u は空配列の展開にも反応するため、要素数で分ける。
                    if [ "${#tests[@]}" -gt 0 ]; then
                        for target in "${tests[@]}"; do
                            [ "$target" != "$2" ] || usage "duplicate --test target: $2"
                        done
                    fi
                    tests+=("$2")
                    ;;
            esac
            shift
            ;;
        *) usage "unknown option: $1" ;;
    esac
    shift
done

[ "$full" -eq 0 ] || { [ -z "$level$only" ] && [ "$none" -eq 0 ]; } || usage "--full cannot be combined with --level, --only or --none"
[ "$none" -eq 0 ] || { [ -z "$level$only" ] && [ "${#tests[@]}" -eq 0 ]; } || usage "--none cannot be combined with --level, --only or --test"
case "$level" in ""|work|stage|change|release) ;; *) usage "unknown level: $level" ;; esac
if [ "${#tests[@]}" -gt 0 ]; then
    [ "$full" -eq 0 ] && { [ -z "$only" ] || [ -n "$level" ]; } || usage "--test cannot be combined with legacy --only or --full"
    case "$level" in change|release) usage "--test is only available for work/stage" ;; esac
fi
# 水準なしの only/full だけは旧実行部を使う。自動選択は直ちに work に切り替える。
if [ -z "$level$only" ] && [ "$full" -eq 0 ] && [ "$none" -eq 0 ]; then
    level=work
fi
[ "$level" != stage ] || [ -n "$only" ] || usage "--level stage requires --only"

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
    # cargo-about は並びを優先の順に使うので、集合だけでなく順も一致させる。
    python3 - deny.toml scripts/release/about.toml <<'PYLICENSE' || return 1
import ast
import re
import sys

def read_license_list(content, key, section=None):
    # 必要な表だけを読み、配列の中のコメントと、後に続く表の値を除く。
    lines = []
    active = section is None
    for raw_line in content.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if line.startswith("["):
            if active:
                break
            active = line == f"[{section}]"
        elif active and line:
            lines.append(line)
    if not active:
        raise ValueError(f"missing [{section}] table")
    body = "\n".join(lines)
    # 完全な TOML の読み取りではなく、文字列の配列だけに対象を限る。
    assignments = re.findall(rf"(?m)^{re.escape(key)}\s*=", body)
    arrays = re.findall(rf"(?m)^{re.escape(key)}\s*=\s*(\[[^\]]*\])\s*(?=\n|$)", body)
    if len(assignments) != 1 or len(arrays) != 1:
        raise ValueError(f"expected exactly one {key} list")
    values = ast.literal_eval(arrays[0])
    if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
        raise ValueError(f"{key} must be a list of license strings")
    return values

def self_test():
    # コメントを含む配列と、別の allow を持つ例外の表を独立に確かめる。
    cases = [
        ('[licenses]\nallow = [\n"MIT", # 優先する使用許諾\n"Apache-2.0",\n]\n',
         "allow", "licenses", ["MIT", "Apache-2.0"]),
        ('[licenses]\nallow = ["MIT"]\n[[licenses.exceptions]]\nname = "example"\nallow = ["Zlib"]\n',
         "allow", "licenses", ["MIT"]),
        ('accepted = ["MIT", # 優先する使用許諾\n"Apache-2.0"]\n[other]\naccepted = ["Zlib"]\n',
         "accepted", None, ["MIT", "Apache-2.0"]),
    ]
    for content, key, section, expected in cases:
        if read_license_list(content, key, section) != expected:
            sys.exit("license list self-test failed")

def license_list(path, key, section=None):
    try:
        with open(path, encoding="utf-8") as source:
            return read_license_list(source.read(), key, section)
    except (OSError, UnicodeError, ValueError, SyntaxError) as error:
        sys.exit(f"{path}: cannot read {key} list: {error}")

self_test()
if license_list(sys.argv[1], "allow", "licenses") != license_list(sys.argv[2], "accepted"):
    sys.exit("scripts/release/about.toml: accepted must match deny.toml [licenses].allow in the same order")
PYLICENSE
    if ! cargo deny --version >/dev/null 2>&1; then
        printf '%s\n' 'cargo-deny is unavailable. Install it with: cargo install cargo-deny --locked' >&2
        return 1
    fi

    cargo deny check licenses
}

check_placeholder_allows() {
    local source_file source_files grep_status
    local failed=0

    source_files="$(grep -rlF --include='*.rs' '#![allow(clippy::todo, unused_variables)]' crates/benitoite/src/)" || {
        grep_status=$?
        [ "$grep_status" -eq 1 ] || return 1
    }
    while IFS= read -r source_file; do
        [ -n "$source_file" ] || continue
        if grep -Fq 'todo!(' "$source_file"; then
            continue
        else
            grep_status=$?
            [ "$grep_status" -eq 1 ] || return 1
            printf 'leftover placeholder allow: %s\n' "$source_file" >&2
            failed=1
        fi
    done <<< "$source_files"

    return "$failed"
}

# 複数行の属性と追跡していないファイルも調べるため、属性の形によらず単語で探す。
check_unsafe_allows() {
    local source_file source_files grep_status
    local failed=0

    source_files="$(grep -rlw --include='*.rs' unsafe_code crates/)" || {
        grep_status=$?
        [ "$grep_status" -eq 1 ] || return 1
    }
    while IFS= read -r source_file; do
        [ -n "$source_file" ] || continue
        case "$source_file" in
            crates/benitoite/src/runtime/heap/core.rs|crates/benitoite/tests/call_allocations.rs)
                continue ;;
            crates/benitoite/src/runtime/heap/core/*/*)
                ;;
            crates/benitoite/src/runtime/heap/core/*.rs)
                continue ;;
        esac
        printf 'unsafe_code outside the allowed files: %s\n' "$source_file" >&2
        grep -Hnw -- unsafe_code "$source_file" >&2 || failed=1
        failed=1
    done <<< "$source_files"

    return "$failed"
}

# 生成物（Skill の references と bundle.rs）を作り直し、追跡しているファイルが変わらないことを確かめる。
check_skill_generated() {
    local before after
    before="$(git status --porcelain -- crates/benitoite/skill crates/benitoite/src/cli/tools/skill/bundle.rs)"
    cargo run -q -p benitoite --example gen_skill >/dev/null || return 1
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
        ast.parse(source.read(), path)' tools/bench/*.py tools/skill-eval/*.py tools/spec-coverage/*.py tools/syntax-measure/*.py tools/syntax-measure/bntmeasure/*.py tools/named-arguments-migrate/*.py tools/source-migrate/*.py tools/try-actions-migrate/*.py tools/derive/*.py
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
        scripts/check.sh|scripts/check/*)
            select_check policy_selftest "$file" ;;
        scripts/check-formal.sh) select_check formal "$file" ;;
        scripts/release/about.toml|scripts/release/about.hbs) select_check licenses "$file" ;;
        scripts/*|.cargo/*|rust-toolchain.toml|clippy.toml|rustfmt.toml)
            select_check full "$file"
            unclassified="$unclassified $file" ;;
        Cargo.toml|Cargo.lock|deny.toml|crates/*/Cargo.toml)
            select_check rust "$file"
            select_check licenses "$file" ;;
        crates/benitoite/src/runtime/heap/*)
            select_check rust "$file"
            select_check long "$file"
            # ヒープの変更でだけ追加する。--only heap は別の検査を選ばない。
            select_check default_lib "$file"
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
        tools/source-migrate/*|tools/named-arguments-migrate/*|tools/try-actions-migrate/*)
            select_check python "$file" ;;
        tools/*)
            select_check python "$file" ;;
        formal/reviews/*)
            ;;
        formal/*)
            select_check formal "$file" ;;
        docs/*|*.md|assets/*|.claude/*|.agents/*|LICENSE*|NOTICE*)
            ;;
        # 検査に響かないファイル。.gitignore は追跡するファイルを変えず、変えても処理系と道具の
        # 振る舞いは変わらない（設計書 07-03「実装の規約と静的な検査」）。
        .gitignore)
            ;;
        *)
            select_check full "$file"
            unclassified="$unclassified $file" ;;
    esac
}

changed_files() {
    git diff --name-only --no-renames "$base" --
    git ls-files --others --exclude-standard
}

if [ "$none" -eq 1 ]; then
    printf '%s\n' '== plan: no checks (--none)'
    exit 0
fi

unclassified=""
needs_decision=""
count=unclassified
if [ -n "$only" ]; then
    allowed_names="$check_names"
    case "$level" in
        work) allowed_names="$work_names" ;;
        stage) allowed_names="$stage_names" ;;
        change) allowed_names="$change_names" ;;
        release) allowed_names="$release_names" ;;
    esac
    remaining="$only"
    while :; do
        check="${remaining%%,*}"
        [ -n "$check" ] || usage "--only contains an empty check name"
        case "$check" in *[!a-z_]*) usage "invalid check name: $check" ;; esac
        case " $allowed_names " in
            *" $check "*) select_check "$check" "--only" ;;
            *)
                printf 'unknown check name: %s (known: %s)\n' "$check" "$allowed_names" >&2
                exit 2
                ;;
        esac
        [ "$remaining" != "${remaining#*,}" ] || break
        remaining="${remaining#*,}"
    done
    # 長いテストは処理系のテストの一部として走らせる。
    if [ -z "$level" ] && has long; then
        select_check rust "--only long"
    fi
elif [ "$level" = release ]; then
    select_check release_stack "release candidate (regardless of changed files)"
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
    for check in rust default_lib long release_stack licenses spec_examples spec_coverage reference_examples skill skill_eval python; do
        select_check "$check" "full check"
    done
fi

# ファイルの分類は従来のままにし、種類の和集合だけを水準の実行単位へ対応させる。
if { [ "$level" = work ] || [ "$level" = change ]; } && [ -z "$only" ]; then
    kinds=()
    for check in $check_names; do
        if has "$check"; then kinds+=("$check" "$(reason "$check")"); fi
        unset "sel_$check"
    done
    any_selected=0
    index=0
    while [ "$index" -lt "${#kinds[@]}" ]; do
        kind="${kinds[$index]}"
        index=$((index + 1))
        cause="${kinds[$index]}"
        index=$((index + 1))
        units=""
        case "$kind" in
            rust) units="fmt lint_default lib_default tests_related source_rules skill_generated spec_tally" ;;
            default_lib) units=lib_default ;;
            heap) units="lint_heap doc_default heap_checks" ;;
            formal) units=formal_build ;;
            python) units="python_syntax migrate_selftests" ;;
            skill_eval) units=skill_eval_selftest ;;
            skill) units="skill_generated skill_docs" ;;
            spec_coverage) units=spec_tally ;;
            licenses|spec_examples|reference_examples|policy_selftest) units="$kind" ;;
        esac
        if [ "$level" = change ]; then
            case "$kind" in
                rust) units="fmt lint_default lint_heap test_default_all test_heap_all test_stress doc_default source_rules skill_generated spec_tally long_only" ;;
                default_lib) units=test_default_all ;;
                long) units=long_only ;;
                heap) units=heap_checks ;;
            esac
        fi
        for unit in $units; do select_check "$unit" "$cause"; done
    done
fi

if [ -n "$level" ] && [ -z "$needs_decision" ]; then
    if has heap_local || has stress_local || { [ -n "$only" ] && has tests_related; }; then
        [ "${#tests[@]}" -gt 0 ] || usage "tests_related (when explicit), heap_local and stress_local require --test"
    fi
    if [ "${#tests[@]}" -gt 0 ]; then
        has tests_related || has heap_local || has stress_local || usage "--test is unused by the selected checks"
    fi
fi

# 同じ構成で全統合ターゲットか名指しの文書例を実行する場合だけ包含する。
omitted=""
included_by=""
if [ -n "$level" ] && has test_default_all; then
    included_by=test_default_all
    for check in lib_default spec_examples reference_examples skill_docs; do
        if has "$check"; then
            unset "sel_$check"
            omitted="$omitted $check"
        fi
    done
elif [ -n "$level" ] && has tests_related; then
    included_by=tests_related
    for check in spec_examples reference_examples skill_docs; do
        covered=0
        if [ "${#tests[@]}" -eq 0 ]; then
            covered=1
        else
            for target in "${tests[@]}"; do
                if [ "$target" = "$check" ] || [ "$target" = '*' ]; then covered=1; fi
            done
        fi
        if [ "$covered" -eq 1 ] && has "$check"; then
            unset "sel_$check"
            omitted="$omitted $check"
        fi
    done
fi

# コマンドを配列のまま表示・実行し、dry-run と実行で同じ選択を使う。
unit_command() {
    local action="$1" unit="$2"
    shift 2
    if [ "$action" = plan ]; then
        # 複合の検査も、外部へ渡すコマンドと照合の範囲が計画から読めるようにする。
        case "$1" in
            check_skill_generated)
                printf '%s\n' '      command: cargo run -q -p benitoite --example gen_skill (compare git status --porcelain before/after for crates/benitoite/skill and crates/benitoite/src/cli/tools/skill/bundle.rs)'
                return ;;
            check_formal)
                printf '%s\n' '      command: (cd formal && lake build); reject declarations using sorry'
                return ;;
            check_licenses)
                printf '%s\n' '      command: check_licenses (Python compares deny.toml and scripts/release/about.toml; cargo deny --version; cargo deny check licenses)'
                return ;;
            check_python_tools)
                printf '%s\n' '      command: check_python_tools (python3 -c ast.parse for tools/{bench,skill-eval,spec-coverage,syntax-measure,syntax-measure/bntmeasure,named-arguments-migrate,source-migrate,try-actions-migrate,derive}/*.py)'
                return ;;
        esac
        printf '      command:'
        printf ' %q' "$@"
        printf '\n'
    else
        run_check "$unit" "$@"
    fi
}

run_units() {
    local action="$1" unit target estimate
    local targets=()
    if [ "${#tests[@]}" -eq 0 ]; then
        targets=(--test '*')
    else
        for target in "${tests[@]}"; do targets+=(--test "$target"); done
    fi
    for unit in $unit_names; do
        has "$unit" || continue
        if [ "$action" = plan ]; then
            case "$unit" in
                fmt|source_rules|python_syntax) estimate='seconds' ;;
                lint_default|lint_heap) estimate='~1-3 min (cache dependent)' ;;
                lib_default) estimate='~1 min' ;;
                tests_related|spec_examples|reference_examples|skill_docs|heap_local|stress_local) estimate='target dependent' ;;
                test_default_all|test_heap_all) estimate='several min (cache dependent)' ;;
                test_stress) estimate='long: several min' ;;
                doc_default|skill_generated|spec_tally|skill_eval_selftest|licenses) estimate='seconds to a few min' ;;
                migrate_selftests|formal_build) estimate='several min (cache dependent)' ;;
                long_only) estimate='long: ~15 min plus builds' ;;
                heap_checks) estimate='long: nightly Miri, ~10 min' ;;
                release_stack) estimate='long: ~5 min plus builds' ;;
                policy_selftest) estimate='seconds to 1 min' ;;
            esac
            printf '   [%s] because of %s (estimate: %s)\n' "$unit" "$(reason "$unit")" "$estimate"
        fi
        case "$unit" in
            fmt) unit_command "$action" "$unit" cargo fmt --all --check ;;
            lint_default) unit_command "$action" "$unit" cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep ;;
            lint_heap) unit_command "$action" "$unit" cargo clippy --workspace --all-targets --no-default-features --features "$features",alloc-stats ;;
            lib_default) unit_command "$action" "$unit" cargo test -p benitoite --lib ;;
            tests_related) unit_command "$action" "$unit" cargo test -p benitoite "${targets[@]}" ;;
            test_default_all) unit_command "$action" "$unit" cargo test --workspace --all-targets ;;
            test_heap_all) unit_command "$action" "$unit" cargo test --workspace --all-targets --no-default-features --features "$features" ;;
            test_stress) unit_command "$action" "$unit" cargo test --workspace --lib --tests --no-default-features --features "$features",gc-stress ;;
            doc_default) unit_command "$action" "$unit" cargo test --workspace --doc ;;
            heap_local) unit_command "$action" "$unit" cargo test -p benitoite --no-default-features --features "$features" "${targets[@]}" ;;
            stress_local) unit_command "$action" "$unit" cargo test -p benitoite --no-default-features --features "$features",gc-stress "${targets[@]}" ;;
            source_rules)
                unit_command "$action" "$unit" check_placeholder_allows
                unit_command "$action" "$unit" check_unsafe_allows ;;
            skill_generated) unit_command "$action" "$unit" check_skill_generated ;;
            spec_tally)
                unit_command "$action" "$unit" python3 tools/spec-coverage/spec_coverage.py --self-test
                unit_command "$action" "$unit" python3 tools/spec-coverage/spec_coverage.py ;;
            spec_examples|reference_examples|skill_docs) unit_command "$action" "$unit" cargo test -q -p benitoite --test "$unit" ;;
            python_syntax) unit_command "$action" "$unit" check_python_tools ;;
            migrate_selftests)
                unit_command "$action" "$unit" python3 -B tools/source-migrate/test_source_migrate.py
                unit_command "$action" "$unit" cargo build -p benitoite --example try_actions_inventory
                unit_command "$action" "$unit" python3 -B tools/try-actions-migrate/test_migrate.py ;;
            skill_eval_selftest) unit_command "$action" "$unit" python3 tools/skill-eval/skill_eval.py --self-test ;;
            licenses) unit_command "$action" "$unit" check_licenses ;;
            policy_selftest) unit_command "$action" "$unit" python3 -B scripts/check/test_policy.py ;;
            heap_checks) unit_command "$action" "$unit" scripts/check-heap.sh ;;
            formal_build) unit_command "$action" "$unit" check_formal ;;
            long_only)
                unit_command "$action" "$unit" python3 -B scripts/check/run_ignored.py --kind long --configuration heap
                unit_command "$action" "$unit" python3 -B scripts/check/run_ignored.py --kind long --configuration stress ;;
            release_stack) unit_command "$action" "$unit" python3 -B scripts/check/run_ignored.py --kind release-stack --configuration release ;;
        esac
    done
}

# 検査を始める前に、選んだ検査と理由を示す。
if [ -n "$level" ]; then
    printf '== plan: level %s against %s' "$level" "$base"
    if [ "$count" = unclassified ]; then
        printf ' (changed files not classified)'
    else
        printf ' (%s changed file(s))' "$count"
    fi
    if [ -n "$only" ]; then printf ' (partial selection: --only %s)' "$only"; fi
    printf '\n'
    run_units plan
    if [ -n "$omitted" ]; then printf '   omitted:%s (included by %s, default configuration)\n' "$omitted" "$included_by"; fi
    if [ "$level" = release ]; then
        printf '%s\n' '   manual verification required: identify the actual candidate (version, commit, dirty state, build configuration, bundled/generated files); match regression evidence, CLI examples, migration guidance and distribution steps.' \
            '   release_stack success alone does not complete release acceptance; record the manual verification separately.'
    fi
    printf '%s\n' '   later: stage checks named connections; change covers full regression; release checks the candidate'
elif [ "$full" -eq 1 ]; then
    printf '%s\n' '== plan: full check (requested with --full)'
elif [ -n "$only" ]; then
    printf '== plan: only %s\n' "$only"
else
    printf '== plan: selected checks against %s (%s changed file(s))\n' "$base" "$count"
fi
if [ "$any_selected" -eq 0 ]; then
    if [ "$count" = 0 ]; then
        printf '   nothing to check: no changed files\n'
    else
        printf '   nothing to check: only documents changed\n'
    fi
fi
describe() {
    if has "$1"; then
        printf '   %-62s because of %s\n' "[$1] $2" "$(reason "$1")"
    fi
}
if [ -z "$level" ]; then
describe rust "format, lint (heap-verify/default), tests, gc-stress, placeholder allows/unsafe_code locations, Skill"
describe default_lib "library tests with default configuration (~1 min: ~15 s rebuild after heap changes, ~40 s tests)"
describe long "long tests (#[ignore = \"long: ...\"], ~15 min more)"
describe release_stack "release measured-stack stage tests (~5 min more)"
describe licenses "licenses"
describe heap "scripts/check-heap.sh (nightly Miri, ~10 min)"
describe spec_examples "spec examples"
describe reference_examples "reference examples"
describe skill "generated Skill files"
describe spec_coverage "spec coverage (self-test and tally)"
describe skill_eval "skill-eval self-test"
describe python "Python tools compile, source-migrate and try-actions-migrate self-tests"
describe formal "lake build in formal/"
describe policy_selftest "check policy self-test (including shell syntax)"
fi
# どの種類にも当たらないファイルがあるときは、始めずに止まり、続け方を設計者に決めてもらう。
if [ -n "$needs_decision" ]; then
    printf '== stop: %s\n' "$needs_decision"
    printf '%s\n' '   Ask the designer to add checks for the unclassified files or correct the base, then rerun:'
    if [ -n "$level" ]; then
        selected=""
        for unit in $unit_names; do
            if has "$unit"; then selected="${selected:+$selected,}$unit"; fi
        done
        allowed_variable="${level}_names"
        printf '     scripts/check.sh --level %q --base %q --only %q' "$level" "$base" "${selected:-<check,...>}"
        if [ "${#tests[@]}" -gt 0 ]; then
            for target in "${tests[@]}"; do printf ' --test %q' "$target"; done
        fi
        printf '\n   Available checks for %s: %s\n' "$level" "${!allowed_variable}"
    fi
    printf '%s\n' \
        '   Other choices after the designer decides:' \
        '     scripts/check.sh --full                 legacy set (not the change/release set)' \
        "     scripts/check.sh --only <check,...>     legacy checks (names: $check_names)" \
        '     scripts/check.sh --none                 no checks'
    exit 3
fi
if [ "$dry_run" -eq 1 ]; then
    exit 0
fi

if [ -n "$level" ]; then
    run_units run
    printf 'selected checks passed\n'
    if [ "$level" = release ]; then
        printf '%s\n' 'Release acceptance remains pending until candidate and evidence are manually verified.'
    fi
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
    run_check "lint (default configuration)" cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
    run_check "test (mark-sweep)" cargo test --workspace --no-default-features --features "$features" -- $test_args
    run_check "gc-stress (mark-sweep)" cargo test --workspace --no-default-features --features "$features",gc-stress --lib --tests -- $test_args
    run_check "leftover placeholder allows" check_placeholder_allows
    run_check "unsafe_code locations" check_unsafe_allows
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
if has default_lib; then
    run_check "lib tests (default configuration)" cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep
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
    run_check "source-migrate self-test" python3 -B tools/source-migrate/test_source_migrate.py
    run_check "try-actions inventory helper" cargo build -p benitoite --example try_actions_inventory
    run_check "try-actions-migrate self-test" python3 -B tools/try-actions-migrate/test_migrate.py
fi
if has licenses; then
    run_check "licenses" check_licenses
fi
if has release_stack; then
    run_check "release measured-stack tests" cargo test --release -p benitoite --lib -- pipeline::tests::stages_fit_the_measured_stack_ --include-ignored
fi
if has formal; then
    run_check "formal (lake build)" check_formal
fi
if has heap; then
    run_check "heap checks" scripts/check-heap.sh
fi
if has policy_selftest; then
    run_check "check policy self-test" python3 -B scripts/check/test_policy.py
fi

printf 'all checks passed\n'
