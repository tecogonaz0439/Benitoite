# L4a の実装結果

L4aを完了した。表層のState・refs・BuilderRefs.Okとcheckerを保ったまま、脱糖先を専用コアへ替えた。既定のlake buildと公開の性質1・surface_effect_soundness・検査器の健全性がsorryなしで通る。コミットとdocs/todo/の変更は行っていない。

## 基準

B_WORKと開始時HEADは `09d086d71fd51521eb4515c67688a01abb645198`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。Leanは `leanprover/lean4:v4.34.1`。Rustのソース・formalの既定import・Releaseの規則と実行・Builtins.Assumptionsは変更していない。

## 変更した内容

- Surface.BuilderLower/Desugar: builderBindをbuilderLetへ、通常引数の計算列msの後をbuilderOp kind op (bound (i + ms.length)) vsへ替えた。Referenceのnew/get/set・純粋合成への展開とfillBuildersを削除した。六つの脱糖関数へ環境引数を加えていない。
- Surface.Buildersと型保存の全読者: 同じΓとΔ.toLocalを使う。toLocalはコアの空の表の表現にそろえるだけで、任意のiでkindAtが一致し、番号を変えない。通常束縛と専用束縛、計算列・呼び出し・パターン・ガード・die・通常節/Fail節・捕捉境界を接続した。専用操作の空の効果はC_Effで表層のState付き効果まで広げる。
- Scoped/Program: 入力の局所深さnvを出力にも渡し、生成するlet・穴・照合対象の共有番号の移動を証明した。公開の整形式と型保存の言明は保った。
- BuilderCapture/All/Compose/NoCapture: Readsで専用boundも調べる。LocalCtxReadsの通常/専用束縛の保存と、空Δの捕捉境界を接続した。通常計算のCapturesと公開の捕捉禁止の結論は保った。
- BuilderExamples: 既存31件のexampleをすべて残し、実行の準備を専用セルとσ/ρの置換へ替えた。通常引数のletとdiscardが増やす番号を、手書きの専用コアと比較するdedicated_loweringを追加した。
- 01-12・07-04・formal/README: 実装した規則、内部の表現、保証の範囲、公理一覧を更新した。Exchange.Convertは専用コアを表せない版12の既存unsupportedを保ち、説明を現在の脱糖へ合わせた。生成Skillの入力である01-02・標準ソース・診断表は変更していない。

## 検査

作業途中は、変更箇所のLeanターゲットだけを `rtk proxy lake build <target>` でビルドした。主な対象はSurface.Lemmas.Sequence/Calls/Extensions/Builders/BuilderLower/Scoped/Typing、Surface.Theorems/BuilderExamples、Exchange.Convertである。途中の失敗は、局所環境の添字、extendの加算と空表、Scopedの局所深さ、捕捉の自由番号の不足を修正して閉じた。各試行の外側の時間と全ログは保存していない。最終の既定ビルドがすべての読者を含む。

作業末に次の同じ指定へdry-runを付けて選択を確認し、その後の実検査を一度だけ実行した。

```sh
scripts/check.sh --level work --base 09d086d71fd51521eb4515c67688a01abb645198 --only formal_build,spec_examples,spec_tally
```

| 検査 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| 上記の `--dry-run` | 0。formal_build・spec_examples・spec_tallyだけを選択 | 0.010秒 |
| 上記の実検査 | 0。既定lake build成功・sorry拒否、仕様例7件成功/失敗0/ignore0、仕様集計の自己検査と集計成功 | 68.379秒 |
| 公理一覧（下表） | 全件0。既存202件の出力はL3bc2と完全一致、追加29件も標準の三公理の範囲 | 下表 |
| 主定理・公開checker・仮定・既定import等20ファイルの基準との比較 | すべてファイル全体が同一 | 未計測 |
| formalの全ソースの穴・追加公理の検索、`git diff --check` | 該当なし、差分検査0 | 未計測 |

公理確認はformal/を作業ディレクトリとし、各入力に対して `lake env lean <このディレクトリの絶対パス>/<入力名>` を実行した。正確なimport・名前は各Lean入力、出力は同名の.log、実コマンド・作業ディレクトリ・終了状態・外側時間は各-timing.jsonに保存した。

| 入力 | 終了状態 | 件数 | 外側の時間 |
|---|---|---|---|
| `axioms.lean` | 0 | 40件 | 0.653秒 |
| `builder-axioms.lean` | 0 | 69件 | 0.659秒 |
| `connection-axioms.lean` | 0 | 25件 | 0.637秒 |
| `coverage-axioms.lean` | 0 | 10件 | 0.618秒 |
| `dedicated-axioms.lean` | 0 | 28件 | 0.627秒 |
| `integer-axioms.lean` | 0 | 3件 | 0.625秒 |
| `local-axioms.lean` | 0 | 27件 | 0.623秒 |
| `lowering-axioms.lean` | 0 | 29件 | 0.647秒 |

公理の比較は [axioms-comparison.json](axioms-comparison.json)、契約の比較は [public-contract-comparison.json](public-contract-comparison.json)、ソースの検査は [source-audit.json](source-audit.json)、workの結果は [work.log](work.log) と [work-timing.json](work-timing.json) にある。これは今回の関係状態で実行した結果であり、別の状態へ成功を引用していない。

Rust本体は変更していないため、全lib/clippy/fmtを追加していない。gc-stress・all-targets・check-formal.sh・stage/change/releaseも実行していない。

## 計画との差と判断

[decisions.md](../decisions.md) のR150に空の分類表の表現の対応、R151に範囲保存の局所深さ、R152に専用boundを含むReadsの補助の条件を、推す案として記録した。いずれも表現に伴う内部の補題の一般化であり、主定理の前提・結論、公理、Builtins.Assumptionsは変更していない。20ファイルの比較は、公開11件とprogramの健全性を含む。

R153には、計画の「Exchange/の期待コア」と現行の版12の構文の差を記録した。専用builderLet/builderOp/localRefの交換構文は存在せず、designは版13だけでの許可、planはその読者をL4bへ割り当てている。L4aでは独立期待コアをLeanのdedicated_loweringで検査し、版12へ新しい専用項を加えたり、旧JSONの期待値をunsupportedへ緩めたりしていない。

## テストの作成時の関門と入力の移行

専用コアへの脱糖の境界で、通常引数とdiscardによる共有番号のずれを独立期待値で検査する。片方の番号だけを移す退行、宣言を通常のReferenceへ戻す退行で失敗する。既存の有限実行は結果の文字列を検査するが、この生成するコアの契約自体を照合しないため追加した。テスト専用APIは加えていない。入力は最大でも数個の値・束縛であり、大きな値や長い再帰を追加していない。

既存のstoredAfterの失敗例は、廃止した純粋な結合のdeltaを失敗させていた。専用追記はその関数を呼ばないため、同じdeltaの失敗をappendの通常引数の呼び出しへ移した。期待する「失敗して元のoldを保持」はそのまま保った。専用操作自体の上限超過・内容不変は既存のRelease.BuilderExamples.overflow_atomicを含む既定ビルドと公理一覧で確認する。ほかの実行例の期待値と31件のexampleはすべて維持し、assert/例の削除・期待値の緩和・ignore化はしていない。捕捉の否定例はReadsの専用参照の条件を強めて通した。

Rust本体とRustテストの行数の増減は0。Leanの例のファイルは23行追加・12行削除で、既存のexampleの件数は31件のまま、独立期待コアの定理を1件追加した。

## 後の作業への申し送り

L4bは表層のE_BuilderOp/B_BuilderBindから専用操作に由来するStateを除き、refs・BuilderRefs.Okとcheckerの全読者を一緒に切り替える。通常Reference・通常リソースの解放・Fail/Log/IOは残す。toLocalは共有番号の恒等対応なので、Γを詰め直す射影を導入しない。

版12のfromCompは専用コアをunsupportedとする。L4b/L7で版13/5の専用コアの交換表現と独立JSON入力をそろえ、既存batch3の期待値の移行と版12の拒否を行う。dedicated_loweringと既存の引数順序・snapshot・分岐・複数セル・保存/再開・捕捉拒否の例を独立入力の根拠に使える。今回の成功をState除去、交換13/5、Rustとの全比較の完了とは扱わない。
