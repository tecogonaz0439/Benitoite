# L16c の結果

状態: **L16c は完了。** 六幅の match を、具体的な腕選択・guard・slots・閉じた評価器、正常値と警告の健全性、番号・位置・構文的な到達可能性、独立入力の保存と本体入口まで接続した。全248モジュールの直列ビルドと、指定された work の三単位が成功した。正式な独立レビューと受け入れは取りまとめに残す。

## 基準と範囲

- 作業日: 2026-10-25。作業ブランチ: `mod012/L16c`。
- B_WORK・開始時と終了時の HEAD: `7d7b34c5fb73a06282956043d9f972fbcb3dea57`。開始時に未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提・内部契約・L13〜L16・L16c の分割と検査の指定、D2・D20、README の設計者の決定、preflight と study の対応箇所、L13〜L16・L16b・L16b2 の申し送りと取りまとめのレビューを確認した。
- `private/` と、それを指すスキルは読んでいない。公開の rtk・japanese-tech-writing・test-audit を適用した。AGENTS.md の分担に従い、具体評価・環境・予算付きの証明を別担当へ配り、Lean の実行は主担当に集めた。作業内の点検は [review-notes.md](review-notes.md) に記録した。
- git の状態を変える操作はしていない。ただし、開始時に読み取り照会として `git branch --show-current` を一度使った。禁止コマンドの名前を使った点を依頼からの逸脱として記録する。HEAD・ブランチ・index の変更はない。以後の確認は status・diff・show・rev-parse によった。
- Rust、依存・lock、検査設定、A11 の固定 TSV は変更していない。docs/todo の更新・コミット・取り込み・公開は行っていない。

## 実装した接続

| ファイル群 | 変更と保証する内容 |
|---|---|
| `Eval.lean`・`EvalClosed.lean` | `widthPatternMatch`・`WidthSelection`・`EvalWidthArms`・`matchWidth` と閉じた腕評価を追加した。選択した束縛を反転して局所位置へ置き、guard が偽なら元の環境で後続腕へ進む。照合値・guard・本体の失敗と return は実行済みの trace を保つ。六幅を `matchOtherNormal`・`matchOtherFailed` からも除外した |
| `Environment.lean`・`Flow.lean` | 種類付きのパターン位置、照合値の元位置の絞り込み、腕の共通環境、選択肢の合流と `models_matchKindArmEnv` を追加した。Integer64 は従来の定数・範囲パターンの入口へ分岐する。六幅の束縛位置は同じ幅と正常区間を保つ |
| `Sound.lean` | `nonIntegerOther` で六幅の整数とそれ以外の値を区別し、`onlyWidth`・`matchKind` で一種類の整数だけを含む近似を認定する。`baseMatchKind`・`analyzeBaseKindArms` を追加し、正常値・警告原因・位置・番号の証明へ接続した。旧 `baseMatch`・`baseArm` を残し、旧 `analyzeBaseArms` は Integer64 の特殊化として保った |
| `BudgetPatterns.lean`・`BudgetAnalyze.lean` | 種類付きの腕環境を予算付きで走査する `armKind` と `armListKind` を追加した。認定できない照合値の腕は番号だけを辿り、未知と未対応の印へ退く。Integer64 の腕入口と費用は旧経路へ分岐して保つ |
| 予算付きの証明群 | 任意の予算での正常値、警告原因、位置、番号、構文的な到達可能性、独立入力の保存を種類付きの腕へ接続した。旧公開定理の言明を残し、本体・独立入力の入口まで同じ保証を合成した |
| `Examples.lean` | 六幅共通の独立表を3本、計60入力分追加した。結果型が照合値と異なる場合、束縛位置と外側の位置、guard 偽の環境復元、各位置の失敗と return を、具体評価と予算付き解析の実際の入口で確認する |
| 01-12・07-04 | 今回閉じた定義・言明・対応と限界を写した。既存の見出しと text フェンスは変更していない |

六幅の定数・範囲パターンは、現行の 01-02「パターンマッチ」と 01-04「Integer」、`Surface/CheckPatterns.lean` で禁止されている。今回も束縛・ワイルドカードと guard だけを具体評価し、整数値による分岐は guard で扱う。Integer64 の既存の定数・範囲パターンは保持した。言語の規則を広げる変更は行っていない。

mayFail を診断や受け入れの根拠に使う変更、相関の推測、Byte の算術、符号なしの一般の負号、新しい公開型・構文・エフェクトの規則は加えていない。標準 API の div・absolute の定数警告の境界も変更していない。

## 検査と結果

作業末は、同じ基準と指定の dry-run の後に三単位を一度だけ実行した。Cargo は先行作業のキャッシュ `/private/tmp/benitoite-a01a-cargo` を使用した。検査本体は [run-work.sh](run-work.sh)、時間と終了状態の記録器は [run-work.py](run-work.py) に保存した。

```sh
scripts/check.sh --level work --base 7d7b34c5fb73a06282956043d9f972fbcb3dea57 --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=/private/tmp/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l16c/run-work.sh
```

| 確認 | 終了状態 | 時間と記録 |
|---|---|---|
| 全248モジュールの依存順の局所ビルド | 0。新しい三つの表と既存の予算停止例を含む | 最終一巡53.999秒。[local-build.py](local-build.py)・[sequential-build.log](sequential-build.log) |
| 指定三単位の dry-run | 0。仕様集計・仕様例・既定 Lean ビルドだけを選択 | 外側未計測。[dry-run.log](dry-run.log) |
| 指定三単位の work（一度だけ実行） | **検査本体0**、`L16C_CHECK_EXIT_STATUS=0`。time の外側は計測失敗で1 | 実行器の外側3.348秒。real/user/sys は3.34/3.74/0.26秒。[work.log](work.log)・[work.json](work.json) |
| `lake env lean -M 12288 ../docs/.../l16c/axioms.lean`（formal から実行） | 0。新しい補題と既存の土台・予算・本体・独立入力・閉じた評価の計18宣言を確認 | 実行器の表示0.187秒。[axioms.lean](axioms.lean)・[axioms.log](axioms.log) |
| 固定表の二入力を新しい Lean で各一度だけ計算 | 0。L16b2 の保存出力と全行一致 | 8.581秒・1.722秒。[reference-impact.py](reference-impact.py)・[reference-impact.log](reference-impact.log)・[reference-impact.json](reference-impact.json)・[reference-raw/](reference-raw/) |
| 中心二命題・既存公開定理・公理・設定・固定表・設計書の見出しと text フェンスの比較 | 0 | 外側未計測。[contract-check.py](contract-check.py)・[contract-check.log](contract-check.log) |
| 作業内の読み取り点検・`git diff --check` | 0。独立例とコメントの指摘は修正済み | 外側未計測。[review-notes.md](review-notes.md)。正式な独立レビューと受け入れは取りまとめの担当 |

仕様例は **7件成功・失敗0件・ignored 0件**、テスト時間2.95秒だった。仕様集計の自己検査は成功し、初回リリースの完了条件の未記入は0件だった。参照のない仕様節の表示は失敗と区別してログに残した。formal_build は既定の `lake build` と sorry 拒否を通った。

**最大常駐量（maximum resident set size）は取得不能**である。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` により終了1になった。検査本体の終了0と計測環境の制限を区別し、常駐量を測定済みとは扱わない。

`formal/lakefile.toml` の `moreLeanArgs = ["-M", "12288"]` を維持した。局所ビルドは import の依存順に一モジュールずつ実行し、作業末の既定ビルドの前に全依存を作り終えた。Lean のプロセスとビルド呼出しを並行させていない。ファイル単体の検査にはすべて `-M 12288` を付けた。

## 不変条件と独立例

`git diff` と B_WORK の本文の直接比較により、**NormalSoundness・WarningSoundness の定義全文が一致**することを確認した。変更した16個の Lean ファイルに元からある公開定理479件も、空白の正規化後にすべての言明が一致する。Interval 以外の形式化、旧主定理、公理と Builtins.Assumptions に差分はない。sorry・admit・新しい公理の追加はない。18宣言の公理依存は Lean 標準の propext・Classical.choice・Quot.sound の範囲であり、独自の公理と sorryAx はない。

新しい三つの表の証明は `decide +kernel` を使い、大きな計算を rfl で展開していない。test-audit の作成時の関門では、六幅の腕入口・結果型と照合値の区別・局所位置・guard と異常終了の順序を守る契約を確認した。既存の Integer64 の match と六幅の算術だけでは、六幅の腕の未接続、結果型から照合対象の幅を誤認する退行、guard の束縛漏れを検出できない。期待する値・区間・キー・trace・警告は固定し、対象の解析関数から期待値を生成していない。本番へのテスト専用の入口・公開範囲・引数は加えていない。

既存のテスト・上限・期待値・ignore・時間制限は変更していない。Lean の差分は1614行追加・153行削除であり、独立表はそのうち86行追加・削除0行である。設計書は44行追加・33行削除である。結果と記録のファイルはこの集計に含めていない。

## 固定表への申し送り

body.tsv・whole.tsv・summary.tsv は一度も書き換えていない。reference-impact.py は元の二つの Lean 入力を直列に各一度だけ計算し、L16b2 の保存出力とキーごとに比較した。生成器の main・generate を呼ばず、新しい TSV も生成していない。三表の SHA-256 は実行前後と B_WORK の内容に一致する。

| 入力・表 | L16b2 の保存出力との比較 | 新たに期待値が変わる形 |
|---|---|---|
| budget-reference の本体・全体 | 32,964行すべて一致 | 0件 |
| summary-reference の集計 | 4,020行すべて一致 | 0件 |

本枝から新しい期待値の数表を渡す対象はない。L16a の l16/results.md に記録された unsupported・negate の差は引き続き残る。保存済み三表が現在の Lean とすべて一致したとは扱わず、Rust と三表をそろえる担当は A13〜A15 と取りまとめに残す。

## 初回の失敗と修正

- 種類付きの環境の保存補題で `let range` が残ったため split に失敗した。let を簡約してから分岐する形に直した。
- `opaque` を欄名に選んだ初稿は Lean の予約語と衝突したため、意味の明確な `nonIntegerOther` へ改名した。非整数の所属を二つの欄で示す変更に伴う Unit・未知値・合流の補助証明と、種類付きの局所参照の保存補題も接続した。中心二命題の本文や主定理の言明は変更していない。
- Option 分岐の継続行の字下げで BudgetLocated の構文解析が失敗した。同じ書式の箇所も含めて直した。
- BudgetSound の未知の照合値・異常終了の合成で、手書きの継続と解析本体が異なる Lean の生成 matcher を使い、通常表示で同じ式の等値判定が閉じなかった。省略引数の表示で原因を特定し、継続をゴールから推論させる形へ直した。診断用オプションは残していない。
- 新しい例で予約語 variable を使ったため構文解析に失敗し、boundCase へ改名した。その後、最初の Boolean 表の期待不成立を kernel の検査で再現した。各腕を独立に解析する既存規則に従い、解析の期待を両真偽と key 7 の除数0警告へ直した。具体評価の真と比較 key 2 の期待、解析の規則は保持した。
- 作業内の点検記録を生成する一時 Python 入力で文字コードのエラーが出たため、ファイルへ変更が入る前に止まった。apply_patch で記録を保存し直した。

初期の診断と独立例の不成立は [diagnostics/](diagnostics/) にも保存した。修正後の全248モジュールと指定 work は成功した。

## 計画からのずれと申し送り

L16c の指定範囲を閉じた。言語の規則、中心二命題、既存の主定理の前提・結論、公理の変更を要する判断待ちはない。D2 の match の定数・範囲という記載は、現行仕様が認める Integer64 の範囲を保持し、六幅は束縛・ワイルドカードと guard へ接続する形で実装した。

| 残る担当範囲 | 申し送り | 検査・レビュー・受け入れと見込み |
|---|---|---|
| 本枝の正式な独立レビュー・受け入れ・取り込み | 既定ビルド、指定 work、定義・言明・公理・固定表の差分確認を渡す。作業内の相互点検だけで受け入れを閉じない | 取りまとめ担当。時間は不明 |
| L17・C2 | 全幅のフローの独立例と、定義・言明・仮定のレビューを閉じる。L16c の成功だけで C2 完了と扱わない | 計画の指定検査を実施。レビュー・受け入れの時間は不明 |
| A13〜A15 と後の接続 | 各幅の診断と固定表を Rust へそろえる。最大 u64 の積は u128 で比較後に戻す境界と、mayFail を診断・受け入れへ使わない契約を維持する | 計画の Rust/Lean・VM の比較を後続担当が行う。時間は不明 |

Rust 全 lib・全統合・clippy・fmt、heap、stage・change・release、性能測定、Rust/Lean・VM の全比較は本枝の割当て外であり実施していない。本枝が受け持つ未実施・不合格の検査は残っていない。

作業末の work 開始後は、本番の Lean・独立例・設計書を変更していない。以後の編集は本結果と記録の保存・パス置換だけである。別状態からの結果の引用は行っていない。保存ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、公理と sorry の追加がないことを確かめた。六幅の match を具体評価から健全性・番号・位置・独立入力の保存まで接続し、六幅のパターンは現行の言語仕様どおり束縛・ワイルドカード・guard に限る（幅付きのパターンを新しく受理しない）。A11 の固定表への新たな影響はない。L16（L16a・L16b1・L16b2・L16c）はこれで閉じる。受け入れる。
