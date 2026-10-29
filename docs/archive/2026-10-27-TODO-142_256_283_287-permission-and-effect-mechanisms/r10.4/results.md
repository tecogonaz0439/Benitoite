# R10.4: 構造等号と被覆の制約

## 作業と状態

B_WORK は `3d7219a2038105baa912b2743541f0d7bdff4849`。作業開始は 2026-10-28 11:03 UTC ごろ。実装前に次の位置表を作成した。R10.4 の実装・設計書・生成物・work 検査・Top 互換の確認を完了した。未完の実装はない。独立レビューと受け入れは取りまとめが行う。git の状態を変える操作は行っていない。

## 効果の包含の位置表

パスは `crates/benitoite/src/` を起点とする。制約の生成位置と、確定した効果を検査する入口を区別する。Fail の型と宣言済みの行はすべて構造で比較する。

| 区分 | Rust の位置 | 対象 | Lean の対応と扱い |
|---|---|---|---|
| 被覆 | `typeck/generate.rs::check_function` | 関数と実装メソッドの本体 → 宣言の uses | `B_Sub`、`checkFn`・`checkMethods` の `acceptEffCover` |
| 被覆 | `typeck/generate.rs::lambda_result` | ラムダ本体 → uses | `E_Lam` の本体の `B_Sub`、`acceptEffCover` |
| 被覆 | `typeck/effects/mod.rs::resume_expr` | resume の引数 → 節の効果 | `E_Resume` の引数の `E_Sub`、`acceptEffCover`。従来は周囲へ直接生成していた効果を独立に推論して接続する |
| 被覆 | `typeck/calls.rs::generate` | 通常の呼び出しの頭 → 周囲 | `E_Sub`・`B_Sub`。部分適用は次の構造の行へ分ける |
| 被覆 | `typeck/calls.rs::builder` | 構築器の呼び出しの頭 → 周囲 | `E_Sub`・`B_Sub` |
| 被覆 | `typeck/generate.rs::apply` | 演算・パイプ等の呼び出しの頭 → 周囲 | `E_Sub`・`B_Sub` |
| 被覆 | `typeck/effects/mod.rs::try_expr` | die が呼ぶ Process.Exit → 周囲 | `E_TryResultDie`・`E_TryOptionDie` の呼び出しの `E_Sub` |
| 被覆 | `typeck/solve.rs::flow_inner` | 最外側の関数型の潜在効果 | `Ty.Le`。引数・戻り型・非関数の型引数は等号 |
| 構造 | `typeck/solve.rs::equal_function_effects` | 単一化の関数型の潜在効果の双方向制約 | `Ty.Le` と別の型の構造等号。不変な位置を相互被覆で等しいことにしない |
| 構造 | `typeck/effects/handle.rs::check`（通常） | 保護本体 → 周囲 ∪ handled | `E_Handle`、`C_Handle`・`K_Handle` の保護本体 |
| 構造 | 同上（Fail） | 保護本体 → Rest ∪ Fail | `E_HandleFail`、`C_Handle_Fail` |
| 構造 | 同上（Fail の Rest） | Rest → 周囲 | 検査器の `checkHandleFail` の `acceptEff`。Release の継続の被覆化とは分ける |
| 構造 | 同上（通常・Fail の節） | 節の本体 → 周囲 | 検査器 `checkClausesR` の `acceptEff`。Release の `K_Handle` の節の被覆化とは分ける |
| 構造 | `typeck/effects/mod.rs::lazy_expr` | lazy の純粋要求 | `E_Lazy`、空の上限の `acceptEff` |
| 構造 | `typeck/effects/mod.rs::try_expr`（説明） | die の説明の純粋要求 | `E_TryResultDie`・`E_TryOptionDie` の説明の空の上限 |
| 構造 | `typeck/pattern_ext.rs::guard` | match の guard の純粋要求 | `E_Match` の guard、`K_Guard`、空の上限 |
| 構造 | `typeck/calls.rs::generate`（部分適用） | 呼び出しの効果 → 生成ラムダの潜在効果 | `E_PartialCall` の `acceptEff`。通常呼び出しの頭と分ける |
| 構造 | `typeck/effects/mod.rs::with` | 解放の State → 周囲 | `E_With` の `State` の和。対象を持たない Top の State だけであり構造の挿入を保つ |
| 構造 | `typeck/context.rs`・`solve.rs` | 推論した集合・行・Fail の和、最小解、NoFail | `Eff.union` と行の構造所属。被覆による狭い原子の削除は行わない |
| 構造 | `typeck/effects/declarations.rs` | ファイル宣言の上限、main/test のエフェクト制限 | `HasMain` の構造包含。名前だけの CLI 上限も保つ |
| 構造 | `typeck/traits/impls.rs` | 実装メソッドの宣言と型クラスの契約の照合 | `D-Impl` へ渡す宣言の契約の照合。構造包含は `Eff.Sub.covers` で被覆を満たす。メソッド本体の `B_Sub` と分け、既存の宣言の許容を広げない |
| 被覆 | `ir/check.rs::accepts` | コアの関数型の最外側の潜在効果 | `Ty.Le` |
| 被覆 | `ir/check.rs::effects` の計算の拡大、定義・lambda・呼び出し・resume・分岐・let・use の結果 | 計算に記録した上限への包含 | `C_Sub`・`C_Eff`。純粋要求とハンドラ保護本体は構造の入口を別に使う |
| 構造 | `ir/check.rs` の純粋要求とハンドラ保護本体、メソッド宣言の契約 | 空の上限、保護本体 → 周囲 ∪ handled、Fail の保護本体、宣言照合 | `C_Handle`・`C_Handle_Fail`。節と Fail の Rest の計算の拡大は `C_Sub` として被覆 |

被覆 10 行、構造 14 行。上のうち State の和、guard、メソッド宣言の契約、コア IR は L50.4 の検査器の一覧に個別の Rust 名がないため対応を補った。いずれも既存の規則に対応し、新しい規則を要しない。全 `EffSub` の生成位置と、`is_subset`・集合の直接照合の読者を再検索し、被覆化の漏れを点検した。

## 変更と接続

`Constraint::EffSub` に被覆／構造の区別を加えた。名前を確かめて `Range::covers` を呼ぶ `EffectName::covers` と、各原子に一つの証人を求める `EffectSet::covers` を置いた。効果の和・等号・hash・整列・重複除去・型と行の代入は構造のままである。制約の重複の鍵も構造を使い、被覆か構造かの区別を含める。

被覆の伝播では右辺の確定した原子との照合だけに被覆を用い、行へは元の原子を構造で挿入する。すでに行に広い原子があることを理由に狭い原子を除かない。Fail の型の単一化は従来どおり不変である。推論した保護本体から節の添字を選ぶ規則を変えておらず、上限を入力に加えていない。

`ir/check.rs` は C-Sub・C-Eff と `Ty.Le` を被覆にそろえ、保護本体と純粋要求には構造の入口を残した。resume の継続の効果から計算の記録した上限への拡大も C-Eff で調べる。表層の節の構造上の推論と、コアの節の計算を上限へ広げる被覆は区別する。

| 変更したファイル | 内容 |
|---|---|
| `src/types/mod.rs` | 原子と効果集合の被覆。既存の構造等号・hash・集合の検査に独立した被覆の期待値表を追加 |
| `src/typeck/infer.rs` | `EffectRelation` と EffSub の関係の欄 |
| `src/typeck/generate.rs`・`calls.rs`・`effects/mod.rs` | 本体・呼び出し頭・resume の被覆制約。部分適用は構造 |
| `src/typeck/effects/handle.rs`・`pattern_ext.rs` | 保護本体・節・guard の構造制約を明記 |
| `src/typeck/solve.rs`・`solve/effect_key.rs` | 伝播・最終照合・関数型の潜在効果・構造キーの接続 |
| `src/typeck/text.rs`・`src/diag/codes.rs` | E0519 と最低限の理由・必要な原子・周囲の原子・一原子の制限の注記 |
| `src/ir/check.rs` | C-Sub・C-Eff・Ty.Le の被覆と保護本体・純粋要求の構造包含の分離 |
| `src/typeck/interval/identity/tests.rs` | 既存の準備が作る EffSub の構造の指定。区間解析の意味は変更なし |
| `tests/scope_annotations.rs` | 通常ソースで被覆の15例、関数・メソッド・ラムダ・部分適用・resume、入れ子の関数型とFailの不変性を確認。範囲の不一致の旧 E0401 の期待を E0519 へ更新 |
| `skill/references/diagnostics.md` | `cargo run -p benitoite --example gen_skill` が生成した E0519 の項目 |
| 設計書 01-06・01-07 | 一原子の被覆・Top・異族・和の拒否、不変な位置、各適用位置と構造上に残す位置 |
| 設計書 02-05・02-06 | 制約の区別・構造キー・伝播・コア IR の検査の対応 |
| 設計書 02-10 | 診断表の E0519 の意味・文言と理由の置き場所 |

ファイルはリポジトリ起点では `crates/benitoite/` の下である。設計書は `docs/design/` の下である。診断の表の生成元は `src/diag/codes.rs`、生成物は `skill/references/diagnostics.md` であり、生成物は手で直していない。構文の章と text の例は変更していない。メソッド宣言の契約が構造上の部分集合である従来の条件を 01-06 に明記し、メソッド本体の被覆と区別した。

## 受理と拒否の例

範囲付きの原子は標準宣言からまだ生成されないため、通常の関数の uses で原子を作り、その関数を呼ぶソースで照合した。標準宣言の意味や試験用の公開入口を追加していない。最終の CLI の実行は [examples.log](examples.log) に JSON の診断と終了を残した。

| 例 | 必要な原子 → 周囲の原子 | 結果 |
|---|---|---|
| [accepted.bnt](accepted.bnt) | `File.Read["/data/a"]` → `File.Read["/data/**"]` | 受理、CLI 終了0 |
| [top-rejected.bnt](top-rejected.bnt) | `File.Read`（Top）→ `File.Read["/**"]` | E0519、`unknownSource`、CLI 終了2 |
| [union-rejected.bnt](union-rejected.bnt) | `Http.Connect["a.example", 0..9]` → 同名の `0..4` と `5..9` | E0519、`notCovered` と一原子の制限の注記、CLI 終了2 |
| [family-rejected.bnt](family-rejected.bnt) | IPv4 の `192.0.2.1` → IPv6 の `::/0` | E0519、`notCovered`、CLI 終了2 |

通常入口のテストは上記に加え、木の幹自身、Top による閉じた範囲の被覆、File.Read と File.Write の区別、host の one/many の幹と深さ、endpoint の積、CIDR、IPv4 射影の IPv6 と IPv4 の区別、名前と IP の区別を確認する。関数値の外側の潜在効果を広げられる一方、List 内の関数型、相互被覆しても原子の列が異なる関数型、Fail のエラー型内の関数型は構造の不一致で拒否する。

作成時の関門は公開の test-audit に従った。既存の型・集合のテストへ期待値の表を追加し、通常の check のテストへ三つの振る舞いを追加した。代数の既存テストでは届かない制約の選択、通常のソースからの接続、コア IR へ渡した後の受理、入れ子の不変性を確かめる。内部の呼び出しを置き換えるテストダブルや、テスト専用の公開範囲は追加していない。

E0519 は今回必要な最低限の報告として、必要な原子・周囲の原子・一原子で覆えない理由と注記を備える。今回の包含の不成立は `notCovered`、必要な原子の Top は `unknownSource` とする。和だけで覆えることの別の意味論的な探索は行わない。R20 の局所解析の予算と出現の番号を扱う診断の実装は今回の対象ではない。

## Top の互換

開始版をビルドしてから、前の枝と同じ [capture_top.py](capture_top.py) で effects・handlers の83入力を、テキスト診断・JSON診断・JSON報告で採取した。計249通りの入力のSHA-256、終了、stdout、stderr と実行ファイルのSHA-256を [変更前](cli-before.json.gz)・[変更後](cli-after.json.gz) に保存した。[比較](cli-comparison.json) は249通りすべて一致、差0で、実行ファイルのハッシュは前後で異なる。成功81・拒否168である。局所のテストの期待値を変えてこの比較を通したものではない。

通常の `desugar_export` は開始版側で34成功・既存の無視1、終了0（[ログ](export-before.log)）。同じテストの実行ファイルを使い、書き出し先だけを r10.4 に変えて採取した [206ファイルの大きさとSHA-256](top-before-manifest.json) と、作業末の同じ統合テストの [206ファイル](top-after-manifest.json) を照合した。[比較](export-comparison.json) は大きさ・SHA-256とも差0であり、合計34,971,227 bytesである。大きい生の出力は一覧を保存して除いた。

作業末の出力先を相対指定したため、batch3・batch5 の45ファイルだけが `crates/benitoite` 起点に保存された。残り [161ファイル](top-after-main-manifest.json) と、その [45ファイル](top-after-relative-manifest.json) はいずれも同じ work の生成物であり、重なる相対名がないことを確かめて一つの一覧へ合わせた。最初の [採取先が不足した照合](export-comparison-initial.json) も残した。コードや検査結果の差ではなく、保存先の解釈の違いである。45ファイルの生の出力と、それを置いた作業用のディレクトリだけを除いた。

## 検査

[run_logged.py](run_logged.py) はコマンドの全出力・終了・外側の時間を保存する。作業末は `/usr/bin/time -p` の内側の sh が check.sh 直後の `$?` を別ファイルへ直接保存し、その終了で time へ返す。RSS はこの Python が待った子プロセスの `getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値であり、並行した全プロセスの合計ではない。

作業末の指定は次のとおりである。出力先の環境変数は交換の証拠の保存先だけを変え、検査対象と構成を変えない。

```sh
scripts/check.sh --level work --base 3d7219a2038105baa912b2743541f0d7bdff4849 --dry-run
BENITOITE_DESUGAR_DIFF_DIR=docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.4/top-after \
  python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.4/run_logged.py work-retry --work \
  scripts/check.sh --level work --base 3d7219a2038105baa912b2743541f0d7bdff4849
```

初回 [dry-run](work-dry-run.log) と修正後の [dry-run](work-retry-dry-run.log) は、fmt、既定構成の lib/tests/examples の clippy、既定 lib 全件、全統合ターゲット、source_rules、skill_generated、spec_tally の7項目を選んだ。spec_examples は全統合に含まれる。初回は fmt 成功後に clippy が終了1となり、修正で古くなった fmt、失敗した clippy、未実行の残り5項目を同じ指定で続行した。

以下の表の時間と最大常駐量はログ隣の JSON の原値を用いる。

| 検査 | コマンド | 終了 | 外側の秒 | 補助RSS（MiB） | 記録 |
|---|---|---:|---:|---:|---|
| 開始版CLIのビルド | `cargo build -p benitoite --bin benitoite` | 0 | 20.246 | 4327.984 | [baseline-build.log](baseline-build.log)・[計時](baseline-build.json) |
| 開始版の通常交換 | `cargo test -p benitoite --test desugar_export` | 0 | 16.996 | 1348.594 | [export-before.log](export-before.log)・[計時](export-before.json) |
| 全ターゲットの試行ビルド | `cargo check -p benitoite --all-targets` | 0 | 14.214 | 2283.312 | [compile.log](compile.log)・[計時](compile.json) |
| 通常入口の初回ビルド | `cargo test -p benitoite --test scope_annotations` | 101 | 20.049 | 4219.844 | [scope-local.log](scope-local.log)・[計時](scope-local.json) |
| 通常入口の再試行 | `cargo test -p benitoite --test scope_annotations` | 101 | 3.011 | 565.875 | [scope-local-retry.log](scope-local-retry.log)・[計時](scope-local-retry.json) |
| 通常入口の再試行2 | `cargo test -p benitoite --test scope_annotations` | 101 | 2.907 | 564.375 | [scope-local-final.log](scope-local-final.log)・[計時](scope-local-final.json) |
| 通常入口と不変性 | `cargo test -p benitoite --test scope_annotations` | 0 | 5.489 | 1418.422 | [scope-invariants.log](scope-invariants.log)・[計時](scope-invariants.json) |
| メソッド・部分適用を加えた通常入口 | `cargo test -p benitoite --test scope_annotations` | 0 | 5.704 | 1478.109 | [targeted.log](targeted.log)・[計時](targeted.json) |
| 構造と被覆の集合の単体 | `cargo test -p benitoite --lib types::tests::scoped_effect_sets_preserve_structural_identity` | 0 | 32.241 | 5302.328 | [structure-unit.log](structure-unit.log)・[計時](structure-unit.json) |
| Skill生成 | `cargo run -p benitoite --example gen_skill` | 0 | 30.772 | 10.453 | [generation.log](generation.log)・[計時](generation.json) |
| 作業末の初回 | `scripts/check.sh --level work --base 3d7219a2038105baa912b2743541f0d7bdff4849` | 1 | 16.565 | 2309.422 | [work.log](work.log)・[計時](work.json) |
| 作業末の続行 | `scripts/check.sh --level work --base 3d7219a2038105baa912b2743541f0d7bdff4849` | 0 | 473.103 | 2577.109 | [work-retry.log](work-retry.log)・[計時](work-retry.json) |

作業末の続行は check.sh 自身が終了0（[直接の記録](work-retry-check-exit.txt)）、外側の time も終了0である。time の原値は real 473.09秒・user 1474.10秒・sys 53.30秒、Python の外側の時計は 473.103秒（7分53.103秒）である。lib は1,354成功・失敗0・既存の無視21、全統合は41ターゲット411成功・失敗0・既存の無視10。[ターゲットごとの件数](test-counts.json) を残した。fmt、既定構成のclippy、規約、Skill生成物の一致、仕様の自己検査・集計も成功した。

作業末の補助の最大常駐量は原値 2,702,295,040 bytes、2577.109375 MiB、2.516708 GiBである。`/usr/bin/time -p` はRSSを採らないため、同じ実行だけを待った `getrusage(RUSAGE_CHILDREN)` の値を用いた。同時の全プロセスの合計とはしない。局所の単体テストのビルドの補助値5,559,894,016 bytes（約5.178 GiB）は別の実行の値であり、作業末の値と合計しない。

検査後に変更したのは結果の記録・採取した証拠とその保存先の整理だけである。仕様の text のコード例が B_WORK と同じこと、編集が許された範囲内であること、差分の空白の誤りがないことを確認した。[実装の差分](implementation.patch)・[ファイルの大きさとSHA-256](changed-files.json)・[行数の差](line-counts.json) を保存する。

## 初回の失敗と修正

| 初回の失敗 | 原因と修正 |
|---|---|
| `scope-local` のビルドが終了101 | 新しいテストが desugar の modules 引数と Result の取り出しを落としていた。既存の公開入口の正しい呼び出しへ修正 |
| `scope-local-retry` のテストが終了101 | 新しいハンドラのソースに `with` がなかった。通常の構文へ修正 |
| `scope-local-final` のテストが終了101 | 効果名 Ask をモジュールとした `Ask.ask` を書いていた。宣言した操作の名前 `ask` へ修正 |
| `work` が終了1（外側16.565秒） | 既存の types のテストに加えた期待値表の添字参照2箇所が clippy の indexing_slicing に触れた。get で照合する形へ修正。lint 免除は追加していない |
| 交換の補助採取が終了101 | cargo を通さず直接テストの実行ファイルをリポジトリの根から動かし、相対パスを使う1件が失敗した。`crates/benitoite` を cwd として再採取し34成功・1無視。開始版の通常の cargo test は最初から終了0 |
| 交換出力の初回照合で45件不足 | 相対の保存先の解釈が一部のテストで異なった。同じworkの出力45ファイルを確認し、161件と合わせて206件すべて一致。再実行・コード修正は不要 |
| 補助の CLI のコマンドが終了2 | 存在しない `--require-main=false` を指定した。通常の main を持つ入力と引数なしの check で終了0。この補助ログの covered-before という名は開始版との比較を意味せず、Top 互換の証拠は上の249通りの記録である |

失敗のログと JSON は残し、成功のログで上書きしていない。検査の範囲・期待値・ignore・時間制限を実行時間短縮のために緩めていない。

## 計画との差と R10.5 への申し送り

被覆と構造等号の境界、不変の添字、署名の許容、非関数の共変、資源Topの条件を変える必要はなく、L へ戻す停止条件への該当はない。保護本体以外から節の添字を選ぶことや、上限を検査器の入力へ持たせる変更も行っていない。12時間の停止条件にも達していない。依存、Lean、scripts、標準宣言の意味は変えていない。

計画との差は、呼び出し先の保持と受理を閉じるために `ir/check.rs` の検査も同じ枝で接続したこと、診断表に対応して02-10も追随したこと、初回の検査の失敗後に必要な項目を続行したこと、交換出力の相対の保存先を二つの一覧から合わせたことである。いずれも依頼の編集範囲内である。ヒープの不変条件・根・障壁・安全点を越える保持は変えていないため、H の追加検査は対象外とした。新しい依存、ホストの幅に依存する整数変換、外部機能への中核からの依存は増えていない。32ビットや特殊構成の実ビルドを確認済みとはしない。

R10.5 は標準値型と署名の認定、原子側の署名内範囲変数を接続する。今回の `EffectName::covers` は閉じた Range の原子を扱う。範囲変数を加える際は、固定の範囲と変数の組は覆わず、同名・同番号の変数だけが覆う Lean の `Atom.Covers` にそろえる。型の添字と Fail の不変性、構造キーの関係の区別を保つ。範囲付きIOの呼び出しの範囲列は R20.3、節の添字の選択は R20.4、交換の新形式は R10.7/K10 の担当を保つ。非Topの整列順の先行の申し送りもそのままである。

R40 は追加の由来・出現の番号・上限の JSON の欄・文言の全体の統一を担当する。今回の被覆拒否のコードと最低限の説明は実装済みである。今回の work の成功を Lean との全比較や局所解析の診断の完成として扱わない。

`scripts/check-formal.sh`、Lean のビルド、short の性能比較は実行していない。独立レビュー・受け入れ・取り込み、段の stage と性能比較、形式化との全比較は計画の後続枝または取りまとめの担当である。コミットは行っていない。

## 時間

開始の時計は2026-10-28 11:03:20 UTCで、その直前に指定文書の読み込みを始めた。結果の確定は 2026-10-28 11:24:35 UTC、記録時刻間の外側の所要は約21.3分である。最初の読み込みを含む全体は約22分、能動時間は約15分という概算である。作業末検査は初回16.565秒・続行473.103秒、局所検査と生成の待ちは上表のとおりであり、一部は文書の整理と重なった。独立レビュー・性能測定・設計者の回答待ちは本枝では行っていない。検査中にも文書と結果の整理を進めたため、検査の経過時間を外側の時間から単純に引いて能動時間とはしない。


## R10.4b: RV-R10.4 の指摘への対応

2026-10-28。B_WORK は `3d7219a2038105baa912b2743541f0d7bdff4849` のままである。R10.4 の未コミット差分への修正として、中1・軽1・軽2・軽3を扱う。レビュー本文は変更しない。以下の記録は、上の R10.4 の記録のうち診断の条件・文言と再検査の状態を更新する。

### 指摘ごとの対応

| 指摘 | 対応 |
|---|---|
| 中1 | E0519 は上限に同名の原子があるが、そのどの一原子も必要な原子を覆えない場合だけにする。同名の原子がない場合は既存の E0501／E0401 の経路へ戻す。由来の位置を主位置、宣言の位置を副位置の `declared here` とし、expected は同名の原子だけに絞る。周囲の原子を広げるか呼び先の範囲を狭める help を `diag::codes` と `typeck::text` に置く。通常入口の既存の被覆の表と、設計書 01-07・02-05 の手順3・02-10 をそろえる |
| 軽1 | pair を持つ制約では既存の位置の記録を共有し、一度報告したら `break` する。一引数の二原子が覆えない入力を通常入口で検査する |
| 軽2 | `typeck/interval/identity/tests.rs` の FnUses の準備を、本番の `check_function` と同じ `Cover` にそろえる。テストの準備を構造上に残す例外は設けない |
| 軽3 | `ir/check.rs` の `structural_effects` の前のコメントから、02-06 の該当節を引く |
| 軽4（記録のみ） | K10 への既知の差として申し送る。型クラスの宣言が `File.Read["/data/**"]`、実装の宣言が `File.Read["/data/a"]` の場合、Rust の `traits/impls.rs` は構造上の部分集合を求めて E0711 とする。Lean の `checkMethods` は本体の効果を型クラスの宣言へ被覆で照合するため、Rust のほうが厳しい。01-06 に明記した選択を保ち、K10 の比較時に照合する。この枝では宣言の許容を変更しない |

被覆と構造の位置表の本番の分類（被覆10行・構造14行）は変わらない。軽2は本番の被覆の行へテストの準備を合わせる修正である。標準宣言、依存、Lean、scripts、型と範囲の意味は変更しない。停止条件への該当はない。形式化との全比較と性能測定はこの枝では実行せず、既存の担当と時期を保つ。

### 作成時の関門と再現

追加・拡張するテストは、公開の `pipeline::check_text` を通した診断の契約を守る。範囲付きの効果の宣言漏れに対する番号・呼び出し位置・宣言の副位置・help、同名の範囲不一致の由来と修正案、一引数に対する診断の件数を観測する。Top だけの既存例や原子ごとの被覆の単体テストでは、無関係な範囲が診断を変える退行と、pair の複数原子で重複する退行を捕まえられない。内部の差し込み口や公開範囲の追加はない。

通常入口の退行検査は `cargo test -p benitoite --test scope_annotations effect_coverage -- --nocapture` で行った。初回は追加した main の戻り値注釈 `-> Unit` が抜け、二例が E0201 になった。準備を直した修正前の再実行では、宣言漏れが E0519 になること、pair の二原子から E0519 が2件出ること、主位置が `caller` になることを確認した。本番の修正後は5件すべて成功した。失敗のログは上書きしていない。

`effect_coverage_preserves_missing_effect_diagnostics` の二入力は、`uses` のない main が `File.Read["/data/a"]` の関数を呼ぶ例と、`uses File.Read["/data/**"]` の main が `Console.Write` の関数を呼ぶ例である。いずれも E0501・呼び出し `target()` のバイト位置・主ラベル・main の `declared here`・`add uses ...` の help 全文を固定した期待値で検査する。B_WORK の `solve_effects` と `context::effect_diagnostic` を `git show` で照合し、既存の origin・related・add_uses を使う経路を保ったことも確認した。今回 B_WORK の実行ファイルを新たにビルドして比較したとはしない。

既存の `effect_coverage_uses_one_same_named_atom` は File.Read → File.Write を E0501 に改め、E0519 の主位置・宣言の副位置・help を検査する。無関係な File.Write が上限にある入力を一行加え、expected に File.Read だけが入るラベル全文を固定した。`effect_coverage_reports_one_failure_per_argument` は、一引数が持つ File.Read と File.Write の二原子をどちらも覆えない場合に、診断が E0519 一件であることを確認する。

### R10.4b の検査

作業末の dry-run と実行は、依頼どおり `scripts/check.sh --level work --base 3d7219a2038105baa912b2743541f0d7bdff4849` を用いた。dry-run は `--dry-run` を追加し、実行は既存の `run_logged.py` の `--work` で `/usr/bin/time -p` の内側へ置いた。内側の sh が check.sh 直後の終了状態を `r10.4b-work-check-exit.txt`、続行では `r10.4b-work-retry-check-exit.txt` に直接保存し、同じ終了状態を time へ返す。ログ・計時・直接の終了状態はすべて `r10.4b-` で始まる名前とした。

初回と続行前の dry-run は、fmt、既定構成の lib/tests/examples の clippy、既定 lib 全件、全統合ターゲット、source_rules、skill_generated、spec_tally の7項目を選んだ。spec_examples は全統合に含まれる。ログ作成に伴って未追跡ファイルの数は増えたが、選択する検査とコマンドは同じである。

初回の work は fmt 成功後、`solve.rs` に加えた `match` の `_ => Vec::new()` が `wildcard_enum_match_arm` に触れて終了1となった。`Elem` の定義を確認して `Elem::Name(_) | Elem::Var(_)` を明記し、lint 免除は加えなかった。修正で古くなった fmt、失敗した clippy、未実行の残り5項目を同じ指定で続行した。検査の範囲・期待値・ignore・時間制限は緩めていない。

| 検査 | 終了 | 外側の秒 | 記録 |
|---|---:|---:|---|
| 通常入口の初回（準備の誤り） | 101 | 5.686 | [ログ](r10.4b-regression-before.log)・[計時](r10.4b-regression-before.json) |
| 準備修正後、本番修正前の退行再現 | 101 | 1.644 | [ログ](r10.4b-regression-before-corrected.log)・[計時](r10.4b-regression-before-corrected.json) |
| 修正後の局所検査（5成功） | 0 | 10.640 | [ログ](r10.4b-regression-after.log)・[計時](r10.4b-regression-after.json) |
| gen_skill による再生成 | 0 | 5.333 | [ログ](r10.4b-generation.log)・[計時](r10.4b-generation.json) |
| 作業末の初回 | 1 | 6.781 | [ログ](r10.4b-work.log)・[計時](r10.4b-work.json) |
| 作業末の続行1（テストの lint） | 1 | 8.140 | [ログ](r10.4b-work-retry.log)・[計時](r10.4b-work-retry.json) |

続行1では本番コードの lint は通り、`scope_annotations.rs` の `rejection.is_none()` に続く else 内の `unwrap` が `unnecessary_unwrap` に触れた。`if let Some(code) = rejection` で値を取り出し、受理検査を else に置く形へ直した。期待値と検査内容を保ち、lint 免除は加えていない。続行2の dry-run でも同じ7項目を確認し、fmt・clippy と未実行の残り5項目を実行した。続行2の直接の終了状態の保存先は `r10.4b-work-retry2-check-exit.txt` である。

### R10.4b の差分と申し送り

R10.4 の最終状態は既存の `implementation.patch` と `changed-files.json` に残し、今回の追加修正だけを [r10.4b-implementation.patch](r10.4b-implementation.patch) と [r10.4b-changed-files.json](r10.4b-changed-files.json) に保存した。B_WORK の該当20ファイルに元の patch を一時ディレクトリで適用し、元の20件すべての SHA-256 が既存の一覧と一致することを確認してから、現在との差を採った。既存の証拠は置き換えていない。

追加修正は9ファイルである。本番は `diag/codes.rs`・`ir/check.rs`・`typeck/solve.rs` の54行追加・37行削除、テストは `typeck/interval/identity/tests.rs`・`tests/scope_annotations.rs` の118行追加・25行削除である。既存テストの削除はなく、既存の表の拡張と通常入口の2テストの追加を行った。生成元 `diag/codes.rs` と生成物 `skill/references/diagnostics.md` の両方を更新し、生成物は手で直していない。設計書は 01-07・02-05・02-10 の診断の条件と説明を更新した。構文と仕様の text の例は変更していない。

軽4の既知の差の照合はK10へ渡す。今回の診断の修正を、Rust と Lean の全比較の完了とは数えない。独立レビューの再確認・受け入れ・取り込みは取りまとめの担当である。git の状態を変える操作は行っていない。

### R10.4b の検査の確定値と所要時間

| 検査 | 終了 | 外側の秒 | 記録 |
|---|---:|---:|---|
| 作業末の続行2（全7項目の成功） | 0 | 453.808 | [ログ](r10.4b-work-retry2.log)・[計時](r10.4b-work-retry2.json)・[check.sh の直接の終了状態](r10.4b-work-retry2-check-exit.txt) |

check.sh 自身の終了状態は0、外側の time も終了0である。`/usr/bin/time -p` の原値は real 453.80秒・user 1445.57秒・sys 43.97秒、Python の外側の時計は 453.808秒（約7分34秒）である。既定 lib は1,354成功・失敗0・既存の無視21、全統合は41ターゲット413成功・失敗0・既存の無視10となった。[ターゲットごとの件数](r10.4b-test-counts.json)に保存した。fmt、既定構成の lib/tests/examples の clippy、ソース規約、Skill生成物の一致、仕様の自己検査・集計も成功した。

補助の最大常駐量は 3,400,663,040 bytes、3243.125 MiB、3.167114 GiBである。`/usr/bin/time -p` はRSSを採らないため、この実行だけを待つ Python の `getrusage(RUSAGE_CHILDREN).ru_maxrss` を用いた。並行した全プロセスの合計とはしない。

検査の確定後は結果記録だけを追記した。追加修正の9ファイルと、それ以外の R10.4 の11ファイルが保存したSHA-256に一致し、追跡済みの差分のファイルが元の20ファイルの範囲に収まること、ブランチが `m013/r10.4` のままであること、`git diff --check` が終了0となることを確認した。

最初の依頼文・規約の読み込み直後の時計は 2026-10-28 11:39:10 UTC、結果の確定は 2026-10-28 11:54:17 UTCである。この時計間の外側の所要は約15.1分、最初の読み込みを含む全体は約15分である。能動時間は主担当約7分・実装担当約4分という概算であり、一部は並行している。作業末の検査待ちは成功した続行2が約7分34秒、失敗した初回と続行1が計約15秒で、局所検査と生成の時間は上表のとおりである。検査中も文書と証拠を整理したため、待ち時間を外側の時間から単純に引いて能動時間とはしない。見込み30〜60分の上端の2倍には達していない。
