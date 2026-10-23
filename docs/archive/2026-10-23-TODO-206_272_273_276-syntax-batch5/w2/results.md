# W2 の実装結果

2026-10-23、W2 実装担当。基準 B_WORK と開始時の HEAD は `a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a`、ブランチは `mod011/W2` であり、開始時に差分はなかった。git の変更操作と private の参照は行っていない。

## 実行した検査

| コマンド | 終了状態 | 外側の時間 |
|---|---:|---:|
| `cargo run -p benitoite --example gen_skill` | 0 | 2.687 秒 |
| `cargo fmt --all` | 0 | 2.170 秒 |
| `scripts/check.sh --level work --base a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden --dry-run` | 0 | 0.074 秒 |
| `scripts/check.sh --level work --base a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden` | 1 | 114.842 秒 |
| `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent` | 0 | 6.077 秒 |
| `scripts/check.sh --level work --base a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --only fmt,lint_default,lint_heap,lib_default,tests_related,doc_default,source_rules,skill_generated,spec_tally,heap_checks --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden --dry-run` | 0 | 0.015 秒 |
| `scripts/check.sh --level work --base a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --only fmt,lint_default,lint_heap,lib_default,tests_related,doc_default,source_rules,skill_generated,spec_tally,heap_checks --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden` | 0 | 809.024 秒 |
| `scripts/check.sh --level work --base a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --only heap_local,stress_local --test runtime_builtins --test golden` | 0 | 666.786 秒 |
| `scripts/check.sh --level work --base a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --only heap_local,stress_local --test runtime_builtins --test golden --dry-run`（本実行前に確認） | 0 | 未計時（1 秒未満） |

作業末の再検査と局所特殊構成はいずれも終了 0 で完了した。検査の打ち切り・省略はない。

再検査の結果は次のとおりである。

| 対象 | 成功件数と結果 |
|---|---|
| lib_default | 1,256 件成功・失敗 0・既存の ignore 21 件 |
| cli_process / golden / reference_examples | 31 / 2 / 1 件成功 |
| runtime_builtins / skill_docs / stdlib_doc_examples | 17 / 8 / 1 件成功 |
| doc_default | no_run の例 17 件成功・既存の ignore 1 件、compile_fail の例 17 件成功 |
| fmt / lint_default / lint_heap | すべて成功 |
| source_rules / skill_generated / spec_tally | すべて成功。生成物の再生成による差分なし |
| heap_checks: Miri | 通常確保 58 件成功・既存の ignore 1 件。個別確保 51 件成功・既存の ignore 1 件 |
| heap_checks: 到達可能性の比較 | BENITOITE_HEAP_RANDOM_CASES=20000。50 件成功・既存の ignore 2 件 |
| heap_local / stress_local | 各構成とも golden 2 件・runtime_builtins 17 件成功。失敗・ignore とも 0 |

## 初回の失敗と修正

局所確認の `rtk cargo check -p benitoite` は成功した。`rtk cargo test -p benitoite --test runtime_builtins display_width` は、追加したテストの診断コードの比較で二度コンパイルを止めた（Option と文字列の型の違い、DiagCode に Display がないこと）。型付きの `Some(DiagCode::R0902)` との比較へ直した。その後、既存の比較器を再利用したことで未使用になった Comparison の理由の欄を、明示した match で読み取るよう修正した。局所の再実行は 2 件とも成功した。これらの外側の時間は未計時である。

初回の work は登録表の `table_names_parts_capabilities_and_schemes_are_consistent` だけが失敗し、lib は 1,255 件成功・1 件失敗・21 件 ignore であった。六関数と表の部分一つの追加に対して、固定した件数を更新していなかった。部分の末尾へ 6 を加え、部分数 57、総数 496、純粋関数数 421 へ更新した。State 16 と IO 59、既存項目の順、名前・署名・権限・逆引きの検査は維持した。単独の確認は成功した。初回は lib で止まったので、統合テスト以降の選択は未実行であった。修正で古くなった fmt・clippy・lib と、それらの未実行単位を明示して再検査した。

## 計画からのずれと申し送り

- 一時文字列を確保せず空白を補うため、既存のヒープの文字列片の入口を反復子へ拡張し、crate 内だけで使う `ValueCtx::alloc_str_space_padded` を追加した。すべての部分は `&str` であり、H12 の UTF-8 の条件、既存の確保器、安全点と根の保持の方式を保つ。W2 の work 行へ golden を追加し、自動選択された heap_checks（Miri と到達可能性の比較）も実行対象にした。
- doc_default はヒープの変更によって自動選択された work で成功した。同じ状態で重ねないため、後の局所特殊構成の --only は heap_local,stress_local の二つとし、W2 の work 行にも理由を記した。
- 確保前に必要な UTF-8 バイト数を u64 で求め、既存の 2^30 バイトの論理上限、検査付きの usize 変換、共通のヒープの容量・計上の検査を通す。native ヒープは既存設計どおり独立した可変のメモリ予算を持たないため、新しい上限や予算の設定は加えていない。極端な Integer を usize へ切り詰めない。空白が不要なら元の Value を返す。
- test-audit の作成時の関門を通し、実行境界に 2 件を追加した。守る契約は標準宣言・名前付き引数・純粋性、独立期待値に対する幅と内容、VM と参照評価の一致、動的な幅の確保前の拒否と R0902 の関数名・サイズである。W1 の単体検査だけでは宣言と実行器の接続を通らない。既存の差分比較器を再利用し、テスト専用の本番 API は作らず、既存テストの削除・ignore・時間制限・大きさの緩和は行っていない。標準ソースの既存の説明例も六関数の利用を含む形へ広げた。
- Rust の差分は本番 126 行追加・5 行削除、テスト 131 行追加・4 行削除である（table.rs の変更はすべてテストに分類）。ほかに標準ソース 29 行、生成 Skill 41 行を追加した。
- CLI の JSON は任意欄 displayWidthUnicodeVersion を常に 17.0.0 として追加し、schemaVersion 1 と人間向けの二行を維持した。標準宣言のコメント、英語リファレンス、03-06・06-01・00-04・07-04、生成 Skill を同じ状態へそろえた。幅の算法を形式化の対象外として明記し、Lean と言語の規則の追加判断は行っていない。
- S-W の引用照合、取り込み後の short、独立レビューと受け入れは取りまとめ担当である。第三者表示と日本語訳は計画どおり Z1 が担当する。W2 ではコミット・取り込み・docs/todo の更新・公開操作を行わない。

取りまとめへ渡す残りの手順は次のとおりである。

| 手順 | 担当 | 見込み時間 |
|---|---|---:|
| S-W の引用条件と関係状態の照合 | 取りまとめ | 5〜10分 |
| 取り込み後の short（W1 と W2 を合わせた一回） | 取りまとめ | 15分以内＋ビルド時間は不明 |
| 独立レビューと受け入れ | 取りまとめ | 15〜25分 |
| 第三者表示と日本語訳の更新・照合 | Z1 担当 | W2 単独分は不明。Z1 の計画に含む |

通常の結果記録であり、別の状態の結果の引用ではない。時間を測ったコマンドは Python の time.monotonic() で subprocess.run 全体を計時した。実行ログと終了状態・時間の JSON は `/private/tmp/benitoite-w2-*.log`・`/private/tmp/benitoite-w2-*.json` にある。S-W で引用する際は取りまとめが引用条件の全欄を保存する。

## 文書の静的確認

次の読み取り専用のコマンドは終了 0、検査処理 0.019 秒（初回の外側は未計時）であった。文書 6 件の相対リンク・アンカー 452 件、フェンス、末尾空白、最終改行を確認した。初回の簡易スクリプトではインラインコードの `function f[T](...)` をリンクと誤判定したので、コードの範囲を除いてからリンクを検査するよう直した。文書の変更は要らなかった。`rtk git diff --check` も終了 0（外側 1 秒未満）であった。

```sh
python3 - <<'PY'
from pathlib import Path
import re, time
start = time.monotonic()
checked = 0
paths = [Path(p) for p in [
    'docs/design/00-overview/00-04-glossary.md',
    'docs/design/03-interop/03-06-stdlib.md',
    'docs/design/06-tooling/06-01-cli.md',
    'docs/design/07-quality/07-04-formal-semantics.md',
    'docs/reference/benitoite.md',
    'docs/2026-10-23-TODO-206_272_273_276-syntax-batch5/plan.md',
]]
for p in paths:
    s = p.read_text()
    assert s.endswith('\n'), p
    assert not any(x.rstrip() != x for x in s.splitlines()), p
    assert s.count('```') % 2 == 0, p
    prose = re.sub(r'^```.*?^```[^\n]*', '', s, flags=re.M | re.S)
    prose = re.sub(r'`[^`\n]+`', '', prose)
    for target in re.findall(r'\]\(([^\s)]+)\)', prose):
        if '://' in target or target.startswith('#'):
            continue
        path, _, anchor = target.partition('#')
        q = p.parent / path
        assert q.exists(), (p, target)
        if anchor and q.suffix == '.md':
            heads = re.findall(r'^#{1,6} (.+)$', q.read_text(), re.M)
            slugs = [re.sub(r'[^\w\s\-]', '', h.replace('`', '').lower()).replace(' ', '-') for h in heads]
            assert anchor in slugs, (p, target)
        checked += 1
print(f'文書{len(paths)}件、相対リンク・アンカー{checked}件: 成功（{time.monotonic() - start:.3f}秒）')
PY
```

最終の確認では、上の文書確認ブロックと results.md の末尾空白・最終改行・途中状態の文言の検査を、別の `python3 -c` のプロセスで実行した。終了 0、外側 0.039 秒であった。続く `git diff --check` は終了 0、外側 0.024 秒であった。

## 取りまとめの性能の比較 short（W1・W2 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=849079b69c7ca28653e5071488c91efee8f7f574 --name batch5-w2`。比べる元は decisions.md の D41 による（開始版 B0 は依存の記録が違うため道具が比較を拒む）。
- 終了 0、外側の時間 3 分 3 秒（ビルドを含む）。出力の照合は全節で成功した。
- 判定: 65 点すべてが「判定不能」（差し引きが計時のぶれ以下）。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-849079b6-batch5-w2/`。
