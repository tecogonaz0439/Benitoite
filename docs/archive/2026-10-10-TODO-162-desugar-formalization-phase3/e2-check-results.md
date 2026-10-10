# E2c-2 型検査の出力の全件検査

## 目的と範囲

処理系の型検査を通った、ゴールデンの 258 入力と `generate_formal` の 1,000 プログラムを、Lean の表層の検査の関数で検査した。入力は E1 の脱糖の差分検査と同じである。型検査などで除外されたゴールデンの 265 入力は検査の対象に含めない。

検査の単位は、利用者の通常の関数の定義と、利用者の実装である。実装はメソッドと上位の辞書をまとめて一単位とする。脱糖の差分検査がメソッドなどを別の単位に数えるため、脱糖の 487・69,218 単位とは件数が異なる。生成された取得関数は E2c-1 の宣言表との照合で検査し、通常の関数の件数には含めない。

トップレベルの定数は参照の位置に `constE` として、型と本体が埋め込まれている。定数の検査は、この埋め込みの検査で足りるとした。独立した定数の検査単位は作らず、参照されない定数の本体は検査しない。

## 実行と分類

新しい実行ファイル `surfaceCheckAll` は、corpus と二つの sidecar の JSON を一度ずつ読み、対象の各入力について E2c-1 の `prepare` を一度だけ呼ぶ。準備した表を、各定義の `checkDef` と各実装の `checkImpl` で再利用する。実装のメソッドと上位クラスの名前は、表から作った完全な一覧を渡す。宣言表・取得関数・構成子の照合に加え、利用者のエフェクト名と組み込みのエフェクト名の重なりも確認する。

```text
formal/.lake/build/bin/surfaceCheckAll \
  target/e2c2/export/corpus.json \
  target/e2c2/export/builtins.json \
  target/e2c2/export/stdlib-decls.json \
  target/e2c2/export/surface-check/report.json
```

全単位の分類と、失敗の理由・経路・祖先の構文を `outcomes` に保存する。不一致は `mismatchExamples` にも保存する。プレースホルダの非穴の引数の `return` を含む定義が失敗した場合は、不一致のまま `rustTypecheckerCandidate` と記録する。それ以外の新しい不一致は `requiresReview` とし、理由と経路を調べて処理系の型検査・Lean の偽の拒否・書き出しのどれに原因があるか判断する。今回の実入力では、不一致も要調査の結果も 0 件だった。

既知の差は、書き出しの `knownDifferences` に「ガードの中の resume（TODO-190）」があり、実際の失敗の理由が `continuation is missing or hidden` で、経路がガードの部分木の中にある場合だけである。実装の場合は、失敗したメソッド自身の印を使う。印があっても、経路や理由が異なる失敗は不一致になる。

対象外は、その単位で使う prim の `unconvertibleTypes` が空でない場合、または本体が `outOfScope` の場合である。prim の名前の一覧を実装に固定せず、各入力の `builtins.json` の実際の欄から判定する。演算子の prim と、ハンドラの節が扱う組み込みの操作も使用に数える。範囲外を成功に含めず、JSON や変換の失敗は準備の失敗として記録する。

`lazy` の制限は、型の包含の失敗で、失敗位置の最も近い式が `lazyE` であり、期待した型と実際の型の差が `Lazy` 内の関数のエフェクトだけである場合に限る。診断用の本体の再検査で引数型と戻り値型の一致、エフェクトの差を確認する。再検査で確認できない場合は、不一致に残す。今回の実入力にこの分類に当たる失敗はなかった。

## Q11 の注釈の置き換え

読み込んだ後の Lean の表層の項に対して、末尾位置の `match` で `armsExits` が真になり、注釈と R が異なる場合だけ、注釈を R に置き換えた。corpus の JSON は変更していない。

位置・子番号・R の変更は `Check.lean` の経路に合わせた。ブロックの最後、括弧、`ite`・`elseIf`・`match` の分岐、`and`・`or` の右辺、`return` の内側は、検査の関数が渡す位置を使う。`with` の本体は同関数どおり `.other` である。ラムダの本体は `.tail` とラムダ自身の R、プレースホルダの非穴の引数は `.other` と展開後の R、ガードと遅延の本体は R なしで辿る。ハンドラの節は型パラメータ数に応じて R をずらす。実装のメソッドでは、クラスのシグネチャの戻り値型に実装の対象型を置き換えてから辿る。

| 項目 | 件数 |
|---|---:|
| 末尾位置の `match` の観測 | 6,057 |
| 注釈を R に置き換えた箇所 | 1 |
| 置き換える前の注釈が `Unit` 以外の箇所 | 0 |
| 置き換え後に検査を通った単位 | 1 |

corpus の `annotations.tailMatch` の `[6057, 1]` と一致した。置き換えたのは `testdata/syntax/f04_list_spread.bnt` の `insertByCount`（`fn:30`）、経路 `[0, 0]` である。元の検査は経路 `[0, 0, 1, 1]` の `type is not included in the expected type` で拒否した。補正後は検査を通った。この元の失敗も `q11OriginalError` に保存した。

検査の成功と健全性の結論は、**置き換えた後のプログラム**についてのものである。

## 全件の結果

| 入力群 | 対象の入力 | 通常の定義 | 実装 | 検査単位 |
|---|---:|---:|---:|---:|
| ゴールデン | 258 | 455 | 8 | 463 |
| 無作為 | 1,000 | 38,218 | 10,000 | 48,218 |
| 合計 | **1,258** | **38,673** | **10,008** | **48,681** |

| 入力群 | 一致 | Q11 の補正後に一致 | TODO-190 の既知の差 | 対象外 | `lazy` の制限 | 不一致 | 準備の失敗 |
|---|---:|---:|---:|---:|---:|---:|---:|
| ゴールデン | 448 | 1 | 0 | 14 | 0 | 0 | 0 |
| 無作為 | 47,218 | 0 | 1,000 | 0 | 0 | 0 | 0 |
| 合計 | **47,666** | **1** | **1,000** | **14** | **0** | **0** | **0** |

準備の失敗は入力単位で数える。それ以外の分類は定義・実装の単位で数える。対象外の 14 定義はゴールデンの 12 入力に属し、すべて変換できない型を持つ prim の使用による。本体が `outOfScope` のものはなかった。内訳は `Task.await` と `TaskGroup.spawn` の両方が 8 定義、`TaskGroup.spawn` だけが 5 定義、`Task.await` だけが 1 定義である。

既知の差の例は、生成した `random-0.bnt` の `formalGuardResume`（`fn:128`）である。失敗はガード内の `resume`、経路 `[0, 0, 0, 1, 0, 0, 1, 0]`、理由 `continuation is missing or hidden` だった。同じ条件を無作為の全 1,000 件で確認した。再現のソースは `target/e2c2/export/random-0.bnt` にある。

対象外の例は `testdata/concurrency/c12-cancelled-await.bnt` の `fn:32` である。`Task.await` と `TaskGroup.spawn` の `unconvertibleTypes` が空でなく、元の検査は経路 `[0, 1, 0, 0, 0, 1, 0, 0]` の `unknown primitive` で止まった。対象外にした根拠の prim 名も `unconvertiblePrims` に保存した。

入力内の全単位が検査を通ったものは 246 件である。残りは、既知の差を含む無作為の 1,000 入力と、対象外の prim を使うゴールデンの 12 入力である。既知の差や対象外を含む入力について、プログラム全体に型が付いたとは結論しない。

不一致の内訳は、処理系の型検査の誤りの候補・Lean の偽の拒否・書き出しの誤り・要調査のいずれも 0 件である。実入力の `partialReturnPaths` は全単位で空だった。書き出しを修正する必要はなく、Rust の書き出しのソースは変更していない。

## 型検査の誤りを見つける例

`CheckCounterexamples.lean` に、docs/todo の TODO-178 の三例を、JSON と Rust の書き出しを使わずに表層の項で書いた。公開の `checkDef` で、拒否の理由と経路を `decide` により確認した。`resume` は実際のハンドラの節に継続を束縛し、その節の中の `bind` の引数に置いた。

| 手書きの例 | 拒否の経路 | 理由 |
|---|---|---|
| `make() -> String` の `bind g <- add(return "escaped", _)` | `[0, 0, 1, 0, 0]` | `type is not included in the expected type` |
| `probe() -> Option[Integer]` の `bind f <- add(try Option.None, _)` | `[0, 0, 1, 0]` | `Option return type mismatch` |
| ハンドラの節の `bind f <- add(resume(10), _)` | `[0, 0, 0, 1, 0, 0, 1, 0]` | `continuation is missing or hidden` |

`return` と `try` は展開後のラムダの R が `Integer` であるため拒否され、`resume` はそのラムダの中で継続を隠すため拒否される。宣言と引数の個数は満たしている。同じプレースホルダの引数に通常の `Integer` を置く対照は成功した。

`test-audit` の作成時の関門では、公開の検査の関数がラムダの R と継続の境界を守ることを契約とした。外側の R や継続を引き継ぐ退行があれば、期待した拒否が失われる。既存の構成子のプレースホルダの例は、この通常の関数の呼び出しの三つの境界をまとめて確認していない。本番の差し込み口は加えていない。

## 比較器の失敗扱いの確認

`SurfaceCheck/Validation.lean` の `#guard` で、既知の差の経路・理由・印、prim の範囲判定、`lazy` の型の差、Q11 の位置と R の境界を確認した。ラムダ自身の R と、実装の対象型を置き換えたメソッドの R も、補正した注釈の型まで確認した。

さらに `target/e2c2/validation/` の一時入力 16 件で、CLI の入口から報告と終了状態まで通した。正常・正しい既知の差・Q11 の補正・確認できる `lazy` の制限・対象外は 0、不一致と対象が空の除外入力は 1、sidecar の入力の不一致と不正な表層 JSON は 2 になった。ガード外の `resume`、印のない失敗、ガード内でも理由が違う失敗は不一致になった。`lazy` の戻り値型の違いも不一致に残した。

一時入力の `partialReturn` は、プレースホルダの引数の `return "escaped"` を実際の組み込みの整数加算の宣言と合わせたものである。経路 `[0, 0, 1, 0, 0]` の包含の失敗となり、不一致と型検査の誤りの候補に分類された。これらの入力は本 corpus に追加していない。記録は `target/e2c2/validation/results.json` にある。

## 信頼する前提と結論

健全性の言明の結論は、E2c-1 の `CheckProgramSound.lean` の `CheckedUnder` である。これは、検査した利用者の定義と実装が宣言表の下で型付けされ、その表がプログラムの宣言を拡張し、エフェクト名が組み込みと重ならない、という結論である。標準ライブラリの本体は検査せず、その宣言を信頼する。

標準ライブラリの宣言に加え、Rust の書き出しと JSON から表層の項への変換の対応、および宣言・本体・組み込みのエフェクトの全原子が収集した有限集合に入ることを信頼する。これらの原子の前提と、宣言表を接続する E2c-1 の補題の前提の下で、全単位が通った入力には `CheckedUnder` を適用する。補正した入力では、補正後の項を使う。検査の関数の健全性側には既存の未証明の 20 箇所が残っている。

## 既存の出力と定義の保持

開始時の指定された JSON 79 ファイルと、`formal/Benitoite/` の既存の Lean 86 ファイル、計 165 ファイルの SHA-256 が作業後も一致した。記録は `target/e2c2/protected-before.json` と `sha256-comparison.json` にある。検査の関数・道具・健全性の言明・`Input.Sound`・E2c-1 の表と補題は変更していない。

今回の Rust の再書き出しも、E2c-1 の `target/e2c1/export/` の出力と一致した。

| ファイル | 一致した SHA-256 |
|---|---|
| `corpus.json` | `456d7eb90db253285f985386d7067c7b155573941263b26e8098fc97ff334a7a` |
| `builtins.json` | `3761faae434c753bfb843d60db12fb9c45f55aa23aa98879609d293084d24206` |
| `coverage-matches.json` | `23e29be5a81598927864ba60f9a5b2c0e674f7d53e8d08d555772d99f91a203e` |
| `stdlib-decls.json` | `1d010940c8e4346afee6ac06ad264a616256f278a185308c1445dfea63ebbbde` |

Release・Core と既存の Surface・Exchange の定義、処理系本体、`Cargo.toml`、指定された読み取り専用の文書は変更していない。コミットは作っていない。

## 所要時間の増分と検査

構築済みの状態で、追加した実行ファイルのビルドは 0.148 秒、全件検査は 13.709 秒、合計の増分は **13.858 秒**だった。先の測定の全件検査は 14.883 秒で、最終コードでも時間の欄を除いた全結果が一致した。時間は外部から測った実時間で、JSON の読み込み・準備・検査・報告の保存を含む。スクリプト全体の前後差は測っていない。記録は `target/e2c2/last-timing.json` と `surface-timing.json` にある。

`check-formal.sh` は、不一致があれば終了状態 1、準備の失敗があれば 2 にする方式を選んだ。Q11 の観測数・補正数が corpus の記録と一致しない場合も 1 になる。基準値との比較は使わない。新しい報告は書き出し先の `surface-check/report.json` に保存し、既存の脱糖と網羅性の報告を上書きしない。

| 検査 | 結果 |
|---|---|
| `formal/` の `lake build` | 成功。三つの手書き反例と対照を含む |
| `lake build surfaceCheck surfaceCheckAll desugarDiff builtinCheck coverageDiff coverageProgramDiff` | 全実行ファイルの構築に成功。分類・Q11 の `#guard` を含む |
| `cargo test --test desugar_export -- --include-ignored --nocapture` | 3 テスト成功、512.60 秒 |
| `cargo test --test coverage_export -- --include-ignored --nocapture` | 1 テスト成功、7.70 秒 |
| `desugarDiff` | 成功、20.375 秒。ゴールデン 258 入力・487 単位、無作為 1,000 入力・69,218 単位で一致 |
| `builtinCheck` | 成功、12.846 秒。1,258 入力・92,745 項目。欠けている prim と構成子は 0 |
| `coverageDiff` | 成功。10,020 件、一致 7,804、Q3 の既知の差 2,216、不一致・燃料切れ 0 |
| `coverageProgramDiff` | 成功、1.106 秒。22,339 件、一致 19,339、Q3 の既知の差 3,000、不一致・範囲外・燃料切れ 0 |
| `surfaceCheckAll` | 最終コードで成功。再実行の結果とも一致。全失敗を分類し、不一致・準備の失敗 0 |
| CLI の一時入力 16 件 | 最終コードで全件の分類と終了状態が期待どおり |
| `cargo clippy --all-targets` | 成功、警告なし |
| `cargo fmt --check` | 成功 |
| `scripts/check.sh --base HEAD --dry-run` | 成功、formal を選択。長いテスト・check-heap の選択なし |
| 未証明の箇所の検索 | 既存の 20 件のまま。新しい Lean のコードに仮置き・`native_decide`・`partial def` はない |
| `bash -n scripts/check-formal.sh`・`git diff --check` | 成功 |

`check-formal.sh` の一括実行は、既存の未証明の箇所の検査で止まるため、上表の書き出し・実行ファイルの各段を個別に実行した。共通検査の `check.sh` 本体は依頼どおりオーケストレータの検査に委ねた。

## docs/todo に記録すべき事項

新しく記録すべき処理系の型検査の誤りと、Lean の検査の関数の偽の拒否は発見しなかった。既存の TODO-190 の再現は `generate_formal(0)` の `formalGuardResume` と、保存した `random-0.bnt` である。既存の TODO-178 の三例は前節の手書きの項で拒否され、プレースホルダの `return` の分類は `target/e2c2/validation/partialReturn/corpus.json` でも再現できる。これらを新しい項目として重複して追加する必要はない。
