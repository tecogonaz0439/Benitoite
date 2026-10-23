# F3 型別の数の整形と内部組み込みの結果

2026-10-23、F3実装担当。[plan.md の作業F3](../plan.md#作業-f3-型別の数の整形と内部組み込み) を対象とする。

## 基準と変更

- B_WORKと開始時のHEAD: `96d03304062009b0fd64e394e3021d5bad8d4dcc`。ブランチは `mod011/F3`。開始時の差分なしを読み取りで確認した。
- `base/format.rs` に、固定定数を検査する `FormatSpec::decode`、型との適合・数字列・符号・接頭辞・埋める個数・全バイト数を求める `prepare`、確保へ渡す `Formatted::byte_len` と `parts` を追加した。生の書式文字列を受け取らず、VM・Wasmtime・言語の値に依存しない。
- 整数の最小値は符号なしの大きさにし、負号と絶対値の基数表記を作る。FloatとFloat32は各binary64・binary32の値を直接固定小数へ最近接偶数丸めし、最短表記を再丸めしない。Decimalは係数とscaleから数字列を作り、減らす桁を偶数丸めし、増やす桁は表示の零として補う。有界Decimalを作り直さない。
- `base/prim.rs` に上限付きの数値用スタック領域と最短表記の書き込みを置き、従来の `toString` と新しい整形本体で表記を共有した。最大の有限Floatの整数部309桁と精度28桁も収まる384バイトの領域を使う。埋め文字は空白と0の不変ASCII領域（各65535バイト）を借り、幅に比例する一時文字列を作らない。
- `%Format.<基本型名>` の14頭を登録表の末尾へ追加し、既存の番号を保った。名前付き引数の契約名は `value/kind/align/sign/alternate/zero/width/precision`、純粋、結果String、非多相である。組み込みは値の取り出しと全長の論理上限を検査し、既存の `alloc_str_parts` に予算の検査と一度だけの確保・コピーを委ねる。不正な内部引数は `Stop::Internal` にする。
- `builtin!` に、Rustの本体だけで型付き引数をタプルにまとめる形式を追加した。言語側の引数は8個のままであり、各引数の型・個数・順は宣言マクロで検査する。既存の宣言形式は変更していない。
- 内部頭の分類 `EntryKind::Format` を追加し、脱糖の既存の分類と、交換用の組み込み宣言表を作る読者を更新した。02-06と03-06へ実装済みの契約を反映した。
- `private/` とそこを指すリンク、docs/todo、過去の文書は読んでいない。gitは状態・差分・HEAD・ブランチ名・基準の本文の読み取りだけに使った。add・commit・branchの作成や切替・merge・stash・reset・checkout・公開操作は行っていない。

## 検査の指定と結果

コマンドはリポジトリの根から実行した。rtkのラッパーは以下では省略した。Wは当初のworkを読者に合わせて拡張した指定、Rは失敗後に古くなったfmt・lintと未到達の項目を名指しした指定、Hは計画の局所特殊構成である。

```sh
# W: lib全件、関係する統合、clippy、fmt、規約、生成物、仕様集計
scripts/check.sh --level work --base 96d03304062009b0fd64e394e3021d5bad8d4dcc --test runtime_builtins --test declarations --test desugar_export

# R: 修正後の項目と、失敗で未到達だった項目
scripts/check.sh --level work --base 96d03304062009b0fd64e394e3021d5bad8d4dcc --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test runtime_builtins --test declarations --test desugar_export

# H: compile_failを含む文書テスト、heap-verifyとgc-stressでの関連統合・ゴールデン
scripts/check.sh --level work --base 96d03304062009b0fd64e394e3021d5bad8d4dcc --only heap_local,stress_local,doc_default --test runtime_builtins --test golden
```

各指定には実行前に同じ基準・対象へ `--dry-run` を付けて選択と理由を確認した。Wはfmt、lint_default、lib_default、tests_related、source_rules、skill_generated、spec_tallyを選び、RとHは名指しした項目だけを選んだ。dry-runはいずれも終了0、外側の時間は各1秒未満であった。分類不能による停止はなかった。

| 実行 | 終了 | 外側の時間 | 結果・失敗の原因と修正 |
|---|---:|---:|---|
| `cargo check -p benitoite --lib` | 初回101、修正後0 | 未計測 | Decimalは既存のFromArgを持たないため、既存の型付きValue引数とDecimalの取り出し関数を使う形へ修正した |
| `cargo test -p benitoite --test runtime_builtins format_` | 初回101、修正後0 | 未計測 | 応答の列挙名を `Reply::Done` へ訂正。5件成功、17件はフィルタ外。後のRで全件を確認した |
| `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent` | 初回101、修正後0 | 未計測 | 新しい内部頭の分類を交換用の読者にも追加。1件成功。後のRでlib全件と交換の読者を確認した |
| W | 1 | 11.344秒 | fmt成功後、Rust側の9引数に対するclippyの `too_many_arguments` で停止。言語側の固定契約を保ち、宣言マクロへ型付きタプルの形式を追加した。lintの許可は加えていない |
| R・初回 | 1 | 7.416秒 | 新しいテストの応答のmatchに残った全域パターンをclippyが拒否。残る三つの列挙を明記した |
| R・修正後 | 0 | 145.308秒 | 選択した全項目成功。clippyの警告なし。libは1267件成功・既存の21件ignored、declarationsは23件成功・1件ignored、desugar_exportは29件成功・1件ignored、runtime_builtinsは22件成功。Skill生成物は差分なし、仕様集計の自己検査と集計も成功 |
| H | 0 | 673.563秒 | 文書テスト34件成功・既存の1件ignored。heap-verifyとgc-stressは、各構成ともgolden 2件とruntime_builtins 22件が成功。失敗なし。gc-stressのgolden本体は554.61秒であった |

`cargo fmt --all` は編集の整形に使った。検査としてのfmt・clippy・lib全件はcheck.shから実行した。短い局所コマンドの外側の時間は独立に計測していない。W・R・Hの外側の時間は、Pythonの `time.monotonic()` で `subprocess.run` の前後を計った。別の状態の検査結果の引用は行っていない。

変更した文書3件（02-06、03-06、plan.md）について、読み取り専用のPythonで相対リンク156件の行き先、追加見出しの参照、コードフェンス、末尾空白、F3の検査指定を確認し、終了0、0.004秒であった。最初のリンク抽出はコード内の `List[T](...)` 等をリンクと誤認したため、フェンスとインラインコードを除いて抽出し直した。文書の誤りはなかった。結果記録を含めた最終の4文書でも相対リンク157件・フェンス・末尾空白を確認し、終了0、0.003秒であった。`git diff --check` も終了0である。

## テストの作成時の関門

新規の5テストは、本番の登録表から純粋な組み込みの包みを呼び、結果の文字列と不正な内部引数の停止を確かめる。独立した期待値により、14頭の欠落・誤登録、符号付き最小値の反転、負の基数表記の2の補数化、符号・接頭辞と零の順、Float系の二重丸め、Decimalの係数の値域超過、負の零・特殊値の誤表示、表示の幅とバイト数の混同を検出する。既存のテストは新しい整形頭を呼ばないため、これらの失敗には届かない。テスト用の公開範囲・フラグ・注入の引数は加えていない。

RV-IのL4は `format_all_fourteen_heads_have_fixed_contracts_and_execute` で対応した。14型と期待出力をD29・study 5.2から独立に列挙し、登録表から作らない。各頭の存在、8引数・契約名・型・純粋さ・Stringの結果・非多相を確認したうえで実行する。型付きタプルの形式については、7個・9個の引数と定数引数の型違いも検査した。最大幅65535は一度だけ確かめ、反復や深い入力と組み合わせていない。

既存テストの入力の大きさ・期待結果・ignore・時間制限は緩めていない。既存の登録表のテストは、新しい14頭とその命名・署名の契約に合わせて更新した。Rustの本体は追加753行・削除39行、テストは追加544行・削除8行である。新規2ファイルを本体に含め、既存ファイルの `cfg(test)` のテストモジュールと `tests/` をテストに分け、基準と現在の本文を比較した。

## 計画からの変更と申し送り

- 内部頭の分類を受け取る読者をそろえるため、`ir/desugar.rs` と `tests/desugar_export/builtins.rs` に分類の追加を行い、work F3へ `desugar_export` を追加した。Rustの引数数の警告を解消する型付きタプルの宣言形式もF3の対象へ追記した。言語の規則とD29のシグネチャは変更していない。
- F4bは `base::format::FormatSpec::decode` と `prepare` を定数評価にも使う。`Formatted::byte_len()` の全長で定数評価側の論理上限・予算・検査付きの整数変換を済ませてから、`parts()` の6片を順に連結する。既存の128バイトの見込みは流用しない。実行時の14頭の名前と型は `builtins::table::FORMAT` と `builtin_scheme` で引ける。
- F4a・F4bの表層の型検査・脱糖・定数評価の接続は行っていない。F2の一時防御と書式なしの経路を保った。F4bは全経路を接続した後に防御を外し、02-06と03-06の未接続の説明も更新する。
- F5のRustとLeanの全接続・独立交換入力の照合はF5担当へ残す。Leanの定義・主な定理・公理は変更していない。言語の規則の追加判断を要する点も見つかっていない。
- ヒープ内部と安全点を越える値の保持方式は変更していない。新しい組み込みも既存のNoGc区間内で文字列の各片を借り、既存の共通確保へ渡す。このため独立した `check-heap.sh` は追加せず、計画のheap-verify・gc-stress・文書テストで新しい経路を確認した。
- 取り込み後のshort測定・独立レビュー・受け入れは、計画どおり取りまとめが担当する。段・改造全体・公開候補の検査は先取りしていない。

F3の範囲を完了した。本作業が受け持つ失敗と未実施の検査は残っていない。書式付き補間の機能全体の完了はF4b以降へ引き継ぐ。

## 取りまとめの性能の比較 short（F3 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=f4dda59f35807b7555992ea7c8ac74ab0e31aa8f --name batch5-f3`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 109 秒（ビルドを含む）。
- 判定: 60 点が「判定不能」、残りが「達成」（しきい値の内側）。W1 比で higher-0-300 +4.0%、classes-300 +2.6%、existing-string +1.9%。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-f4dda59f-batch5-f3/`（手元の絶対パスは `<repo>` に伏せた）。
