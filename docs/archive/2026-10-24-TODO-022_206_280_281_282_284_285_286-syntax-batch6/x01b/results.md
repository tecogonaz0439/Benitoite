# X01b の結果

着手（最初の時刻取得）: **2026-10-26 20:21:59 JST**。終了: **2026-10-26 20:45:30 JST**。所要時間: **23分31秒**。

**状態: X01b の独立交換への接続、合成節点・全対象演算と深い不正入力の局所検査、指定 work と差分の点検を完了した。独立レビューと受け入れは取りまとめへ渡す。**

B_WORK と HEAD は `22303cf6f1ce73472dc9f8b6e60696f21bac9489`、ブランチは `mod012/X01b`。着手時の差分はなかった。AGENTS.md、共通依頼文、plan の前提・契約・X01〜X05・X01b の検査・RV-C5 後の変更、D4 の変更・D5・D17・D20、指定された L26〜L29S・A19〜A21・X01a の申し送りと RV-C5 を確認した。rtk・test-audit・japanese-tech-writing を適用した。

## 実装した範囲

| ファイル | 変更と目的 |
|---|---|
| `crates/benitoite/tests/desugar_export.rs` | 既存の識別の検査を統合ターゲットの直下から共有の書き出しへ接続した。通常のテストとして実行し、ignored の全件書き出しを起動しない |
| `crates/benitoite/tests/desugar_export/interval.rs` | X01a の13入力に、七種の全対象演算と四種の負号、シフト27宣言の名前付き引数の二順序、既存の Range と偽の同定、組み込みの操作・利用者の操作・利用者の関数の頭の入力を加えた。解決済みの宣言と署名から標準表を作り、Range の八つの同定は実際の構成子宣言から得る。元ソース・対応・独立交換の本文を書き出す |
| `crates/benitoite/tests/desugar_export/interval/source.rs` | 算術の対象キーへ六比較を追加し、負号を符号付き四種に限った。型引数・エフェクト引数のない funName/primName の実名を標準表と照合して apiAt と sourceKeys に加える。元位置を持たない標準演算は assertion で拒否する |
| `crates/benitoite/tests/desugar_export/exchange.rs` | 合成した concatenate と文字列補間の変換関数の型に、必須の引数名を付けた。concatenate は宣言の引数名、補間の単項変換関数は value を使う。実読者が拒否した型情報の欠落を直した |
| `formal/tests/test_interval_exchange.py` | `--source-dir` を追加し、実ソースの交換を intervalDiff の実 CLI へ渡す。全型表と元位置・対象キー・頭の分類を照合し、正しい入力を一箇所ずつ変えた深い不正入力を、意図した理由で終了2にする。従来の五 profile の独立期待値と負例はそのまま実行する |
| `crates/benitoite/tests/desugar_export/interval/README.md` | 実際のコマンド、出力、読者の契約の検査と通常予算の解析の区別、後続の担当を記した |

本番 Rust は追加・削除とも0行である。Rust のテストと交換の補助は278行追加・13行削除、Python の比較は133行追加・3行削除である（[集計](self-review.json)）。テストの契約を削除していない。既存の識別の検査関数を統合ターゲットの直下へ移し、準備と走査を共有した。

作成時の関門では、通常解析と実 Surface の識別・元位置を、Lean の厳密な読者へ欠落なく渡すことを独立した契約とした。現実的な退行は、比較演算または標準 call のキーの欠落、合成関数の型情報の欠落、組み込みと包みの頭の混同、深い未知欄の読み捨てである。既存の六入口は区間解析の全型表・標準表・元演算キーを読まないため、この境界の失敗を捕まえない。X01a の本物の pipeline と任意の内部記録先を使い、処理系の段をテストダブルへ置き換えていない。新しい本番の差し込み口や公開範囲は追加していない。

## 局所比較の内容と件数

最終の実ソースの交換は24入力から得た **195元定義・1,381出現・227対象キー**を持つ。七種の整数の加算・減算・乗算・整数除算・剰余・六比較と、符号付き四種の負号の **81組**を確認した。シフトは27宣言を各二順序の名前付き引数で通し、組み込み20宣言の **primName 40出現**、包み7宣言の **funName 14出現**を照合した。組み込みの操作は primName、利用者の操作は opName、利用者の関数は funName を保つ。操作と HTTP の欄を固定域へ戻していない。

合成した195個の根は syntheticBodyRoot として元 NodeId・span を持たない。対象キーは元位置を必須とする。リスト展開と文字列補間の多対一の NodeId、二重の with、ラムダ・lazy・ハンドラの別本体は X01a の通常解析との照合を保つ。補間の元の式と変換関数は同じ NodeId に異なる span を持ち得るので、NodeId の多対一と span の照合を区別した。

新しい `reader-corpus.json` は、**識別と読者の契約だけを検査する入力**である。全体の操作上限0による未着手、最終の状態、段停止、wholeBudgetSkipped を手で指定している。Lean は解析を始める前に全本文・型表・元演算キー・標準表を読み、正しい入力では matched=true になる。ただし解析済み本体は0件なので、全 Top として accepted=false・終了1になることも要求する。これを解析の一致や受け入れの成功には数えない。元の `.point` は別の通常予算の入力として区間 `[42,42]`、本体7操作・全体8操作、保存3項・最大保持7項、次番号2と二つの対応を独立の手計算で与え、matched=true・accepted=true・終了0を確認した。期待値を Rust や Lean の観測値から作っていない。

深い未知欄8件、合成関数・ハンドラ節の中の未知構成子3件、版・型表・対象キー・API 対応・番号の不正9件、生の JSON の重複欄2件、計 **22件の新しい拒否例**を確認した。正しい実ソースの交換を先に通し、各変更が noncanonical Surface fields or constructor、unknown Expr constructor、target correspondence などの意図した理由で終了2になることを確かめた。深さ停止や解析の不一致を拒否例の成功にしていない。

最終の Python の局所検査は、上記の24起動を含む **168回の実 CLI 起動、終了0、6.107秒**だった（[記録](exchange-verified.json)・[出力](exchange-verified.log)）。従来の独立期待値は五 profile で解析174本体、閉じた評価器109本体の比較、理由付きの評価除外65本体を保つ（[manifest](profile-manifest.json)・[fuel](fuel-selection.json)）。解析の深さ除外は0件である。Byte の評価不能と域内シフトの unknown の失敗を、VM 比較済みへ加えていない。実 Rust の全解析と VM の比較が完了したという意味ではない。

局所比較の入力・元ソース・報告・出力669ファイルを、相対名の [ZIP](local-records.zip) と [SHA-256 の索引](local-records-index.json)へ保存した。[保存器](save-local.py)は圧縮後のハッシュも照合した。[局所要約](local-summary.json)と[実ソースの件数](source-summary.json)を別に残した。

## 検査と途中の修正

実行場所は `<repo>`。[run.py](run.py) が各コマンド・終了状態・外側時間を同名の JSON と log に保存し、手元のパスを伏せる。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。

| 検査 | 結果と記録 |
|---|---|
| 最初の書き出しの起動 | 実行器を X01a/resume から移した後の repo の親の数が一段違い、Cargo.toml を見つけず終了101となった。実行器の根の計算を修正した（[記録](identity-first.json)） |
| 新しい実ソースの構文・名前解決 | div/mod を関数名にしたこと、非等号を != としたこと、二引数のシフトの名前の省略、Process の import と効果名の不足で順に失敗した。入力を現行の規則へ直し、終了0になった（`identity-compile`・`identity-syntax-corrected`・`identity-named-corrected` の各 log/JSON、[修正後](identity-heads-corrected.json)） |
| 最初の実読者との接続 | property not found: names で失敗した。合成関数の型情報の欠落を実際の境界で再現し、交換の補助へ引数名を付けた（[失敗](exchange-first.log)・[修正後の書き出し](identity-types-corrected.json)） |
| 多対一と拒否理由の点検 | 補間の NodeId と span の組を同じとする誤った assertion、with に同じ NodeId の重複を要求する assertion を修正した。後から加えた API 対応の欠落例は、call の検査より先に target correspondence で拒否されるため、その意図した理由を期待した（`exchange-types-corrected`・`exchange-node-corrected`・`exchange-final`・`exchange-reasons-final` の各 log/JSON） |
| 最終の実ソースの書き出し | 24入力と195元定義の対応照合に成功、終了0、5.093秒（[記録](identity-final.json)・[出力](identity-final.log)） |
| 最終の局所比較 | 168起動成功、終了0、6.107秒（[記録](exchange-verified.json)）。従来の独立期待値・入力の大きさ・予算を緩めていない |
| 途中の割り当て量2件 | 2件成功・失敗0、終了0、11.411秒（[記録](allocations.json)・[出力](allocations.log)）。20,000定数は442,858,487バイト、5,000定数・1,000診断は254,972,750バイトで X01a と一致。上限512 MiB・256 MiB、入力、期待値は不変 |
| 初回の work | fmt は成功し、clippy の wildcard_enum_match_arm で終了1、本体14.212秒（[本体](work-check-first.json)・[出力](work.log)）。標準宣言の種類のワイルドカード分岐を列挙型の全ケースの明示へ直した。全 lib・全統合の前に止まっている |
| 修正後と同じ dry-run | 終了0、0.086秒。fmt・clippy・全 lib・全統合・ソース規約・生成 Skill・仕様集計・formal_build の8単位を選択（[記録](work-corrected-dry-run.json)・[出力](work-corrected-dry-run.log)） |
| 修正後の work | **8単位成功、本体終了0、452.539秒**（[本体](work-check.json)・[出力](work-corrected.log)）。lib は1,332件成功・失敗0・ignored 21、全統合は40ターゲット・392件成功・失敗0・ignored 10。生成 Skill の照合、仕様集計、Lean の既定ビルドも成功（[集計](self-review.json)） |

作業末は次の指定を使い、修正で古くなった fmt・clippy と、初回に実行されなかった残りの検査を同じ入口で完了した。成功後の検査を計測のために重ねていない。

```sh
scripts/check.sh --level work --base 22303cf6f1ce73472dc9f8b6e60696f21bac9489
```

**最大常駐量（maximum resident set size）は取得不能**である。`/usr/bin/time -l` は `sysctl kern.clockrate: Operation not permitted` を報告して終了1になった。[work-check.py](work-check.py)で検査本体の終了0を別に保存し、[外側](work-corrected.json)の終了1と区別した。real/user/sys は452.56 / 1347.67 / 51.80秒、外側時間は452.564秒である。初回も同じ取得拒否だった。未取得を0と記録せず、計測だけの再実行を行っていない。

## 最終点検と申し送り

[点検器](audit.py)と[結果](self-review.json)で、[最終 work の開始時の入力ハッシュ](work-inputs-final.json)が検査後も一致すること、差分が上の6ファイルと本 x01b の記録に限られること、保存した Python の構文・ZIP のハッシュ・記録のパスの伏せ方・git diff --check を確認した。[初回のハッシュ](work-inputs.json)も残した。最終の work の後は結果記録と点検だけを更新した。

Lean の定義・定理・公理、`formal/lakefile.toml` の `-M 12288`、予算の固定表、本番 Rust の型・署名、manifest/lock は変えていない。局所比較は既存ビルド済みの intervalDiff を逐次起動し、Lean のビルドは work の一回だけである。既定ビルドは既存キャッシュを使い、work の開始後に更新された olean は0件だった。別の lake/lean や並行の Lean ビルドを起動していない。

計画の範囲の変更、言語規則や Lean の主定理・公理・本番 Rust の署名を変えないと進めない停止条件はない。4時間の上限による中断もない。警告抑制、固定表や割り当て量の上限・入力・期待値の緩和で不一致を隠していない。private/ とそのリンク、担当の委任、git の変更操作・コミット・取り込み・docs/todo の更新・公開は利用していない。stage・change・release・check-formal.sh 全体と実 VM の比較は本枝の割り当てでは実施していない。別状態の検査を引用して省いた検査はない。

| 残る手順 | 担当と受け渡す内容 | 見込み |
|---|---|---|
| X01b の独立レビュー・受け入れ | 取りまとめ。全対象キー・元位置、標準表の実宣言との同一性、深い拒否例、読者だけの検査と解析済み件数の区別、work の証拠を確認する | 不明 |
| 全関係定義の列挙・通常予算の解析と全 profile の比較、検査・レビュー・受け入れ | X02a/X02b と取りまとめ。reader-corpus の本文・全型表・標準表・apiAt を使えるが、上限0の未着手を通常解析の成功へ転用しない。元の共有検査の順を保つ全定義 manifest を列挙する。キー単位の候補、元 NodeId・原因・一次位置でまとめた後の警告、操作・保持・停止を照合する。候補の operation は内部観測の Debug 表現なので、交換の演算へ対応させる | 計画の各1〜1.5時間。レビューは不明 |
| 実 VM の比較、既存六入口との全比較、検査・レビュー・受け入れ | X03〜X05 と取りまとめ。Range の実本体、域外シフトの失敗位置、域内 unknown と Byte の除外を計画どおり区別する。今回の読者の検査や五 profile の固定例だけで K1 完了としない | 計画による。今回未測定の時間は不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。変更はテスト側の交換・desugar_export と局所の検査で、本番の Rust・Lean の定義・予算の固定表は変わらない。実ソースの195定義の入力は識別と読者の契約の確認であり、操作上限0の未着手を `notAnalyzed` で照合して解析済みの件数に加えていない。通常予算での全関係定義の比較は X02 の担当である。work は八単位とも成功した。X02a へ進む。
