# L7 の実装結果

交換13/5の独立入力と旧版の受理/拒否をそろえ、Lean段をRV2へ渡せる状態にした。既定lake buildはsorryなしで成功した。Rustの全比較は未実施である。コミットとdocs/todo/の変更は行っていない。

## 基準と変更

B_WORKは `9ddb8885ef793a623ecbfdb52c7bea93a60b0e4c`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。

- `Exchange/Version.lean`: 型付き表層へ変換されない期待コアや未使用の定数も、共通のexchangeJsonでIntegerの範囲を検査する。型名のInteger64の既存の正規化と、他の幅の扱いは保つ。13→5・11/12→4・9/10→3・8→2、構築器とblockの版13限定、版12の再生成の拒否は先行作業で実装済みであり、今回の全読者の検査で確認した。Main・Syntax・Convert・Builtins・CheckInputを形だけ変更する必要はなかった。
- `tests/batch4-exchange/`・`test_batch4_exchange.py`: 五形式の独立入力、45定義・通常網羅性6件・プログラム網羅性3件、15テストを追加した。三種類の専用構築器、共有番号・節の辞書・継続・捕捉境界、blockの値とreturn、穴の直接参照と固定式/間接calleeの順、有界Integerの両端と全域・穴、Logの通常宣言・送り直し・Console.Writeの残存、展開済み位置を六入口へ渡す。manifestに件数とSHA-256を固定した。
- `test_batch3_exchange.py`: 旧版12の全30定義は再生成の理由で拒否し、構築器なしの11定義とcoverage 3/2件の意味は保つ。19構築器定義の意味のassertと六つの検査メソッドは新版へ移した。旧corpus.json自体は基準と同一であり、削除・新版への読み替えをしていない。旧 --rust-dir の12/4用の検査器は保持した。
- `tests/named-exchange/corpus.json`: fn:4の穴のLet一つだけを除いた厳密な期待コアへ直した。既存のassert・件数・ラベル・引数の順は保つ。
- `formal/README.md`・両独立入力のREADME・01-12・07-04: 定義との対応、受理/拒否の移行、独立入力の件数、Rust未接続の範囲を更新した。batch4のREADMEには本番Rustの追加予定入力数と六入口への割り当てを作業別に記した。構文の章01-02・診断表・標準ソースは変更しておらず、生成Skillの更新は不要である。

## 検査

作業末は同じ基準と指定のdry-runを確認した後、次を一度実行した。

```sh
scripts/check.sh --level work --base 9ddb8885ef793a623ecbfdb52c7bea93a60b0e4c --only formal_build,spec_examples,spec_tally
```

| 検査 | 終了状態・結果 | 外側時間 |
|---|---|---|
| 上記のdry-run | 0。指定した三単位だけを選択 | 0.010秒 |
| 上記の実検査 | 0。spec_tallyの自己検査と集計、spec_examplesの7件、既定lake buildとsorry拒否が成功 | 8.831秒 |
| `python3 -B formal/tests/test_batch4_exchange.py` | 0、15テスト成功。六入口で45定義・coverage 6/3件が一致 | 6.156秒 |
| `python3 -B formal/tests/test_batch3_exchange.py` | 0、7テスト成功。旧構築器の拒否と非構築器の意味を確認 | 4.149秒 |
| `python3 -B formal/tests/test_named_exchange.py` | 0、13テスト成功 | 2.370秒 |
| `python3 -B formal/tests/test_try_exchange.py` | 0、8テスト成功 | 3.637秒 |
| `python3 -B formal/tests/test_extensible_exchange.py` | 0、22テスト成功 | 6.496秒 |
| `python3 -B formal/tests/test_batch2_exchange.py` | 0、7テスト成功 | 1.411秒 |
| `python3 -B formal/tests/test_width_exchange.py` | 0、4テスト成功 | 1.203秒 |
| 開始時の公理一覧 | 0、既存269件を保存 | 0.717秒 |
| 作業末の公理一覧 | 0、269件が開始時と一致。L1開始前の40件も全て一致 | 0.739秒 |
| ソース確認 | 主定理・Assumptions・モデル・型付け等11ファイルが基準と同一。Lean 202ファイルにsorry/sorryAx・axiom宣言なし。旧corpusとmanifestのhashが一致、git diff --checkは0 | 0.263秒 |

独立交換テストは指定順に実行し、合計76テストが成功した。コマンドと時間は[exchange-timings.json](exchange-timings.json)、出力は `exchange-<名前>.log` に保存した。workの出力と時間は[work.log](work.log)・[work-timing.json](work-timing.json)、dry-runは同名の記録にある。spec_tallyは未参照節を表示したが、未記入の初回リリース条件はなく、検査は終了0である。

公理確認の入力は[baseline-axioms.lean](baseline-axioms.lean)・[axioms.lean](axioms.lean)、出力は同名の `.log`、比較は[axioms-comparison.json](axioms-comparison.json)にある。作業末は保存した入力を `/private/tmp/batch4-axioms.lean` に写し、formal/で `lake env lean /private/tmp/batch4-axioms.lean` を実行した。importはBenitoite、対象はREADMEの主定理・公開11件・program・各先行作業の追加定理/小証明の全269件であり、今回追加した定理はない。標準三公理propext・Classical.choice・Quot.soundの範囲を保つ。L1開始前の比較元は `l1/axioms-before.txt` である。

[source-audit.json](source-audit.json)にソースの比較を保存した。Release.Model.assumptions、HasTypeVを含む型付け、主定理、公開checker、既定importとビルド対象は開始版と同一である。R133による仮定の意味は先行作業で切り替え済みのままであり、今回の交換の検査はその規則を変えない。旧い型付けのモデルへ戻したり、新しい公理・Assumptionsを足したりしていない。

Rustを変更していないため全lib・clippy・fmtを追加せず、gc-stress・all-targets・check-formal.sh全体・stage/change/releaseは実行していない。同じ既定lake buildを完了検査の外で重ねていない。

## 途中の確認と失敗の修正

途中は変更した交換入口の六実行ファイルだけを `formal/` で `lake build desugarDiff builtinCheck coverageDiff coverageProgramDiff surfaceCheck surfaceCheckAll` に渡し、関連するPythonテストメソッドを直接実行した。途中の試行の全ログ・外側時間は保存していない。

範囲外の期待コアは変更前に、desugarDiffが終了1の比較不一致、残る三つのcorpusの読者が終了0となった。回帰テストの8場合で失敗を確認し、共通の整数検査で全て終了2・範囲外の理由となるよう直した。

新しい手書き入力の最初の試行では、Fail節の交換arityを2と書いた誤りを既存の交換形式の1へ直した。直接calleeに余分なLetを数えた誤りは、固定式だけのLetへ修正した。Integerの一点の穴を表示0とした期待は、現在のotherの表示である `_` へ直した。非網羅性そのものはfalseの厳密な期待を保った。旧版の非構築器だけを選んだ場合は末尾matchのfn:211も除かれるため、Q11の注釈を[1,0]から[0,0]へ直した。入力の集合と注釈の対応を修正したものであり、Q11の一致検査を外していない。

捕捉拒否の変異では、囲む関数/ラムダが必ず抜ける形を先に満たし、目的の局所kindの拒否へ到達させた。coverageの範囲外の変異は件数注釈も入力の1件に合わせ、別の件数誤りで拒否される入力にしなかった。新版のkindの拒否理由とlazy内returnの理由は現在のcheckerの厳密な文言を確認した。Pythonの括弧の誤りも修正した。

## 計画との差とテストの関門

範囲と作業順の変更はない。実態に合わせた最小の具体化をdecisions.mdのR156に記した。期待コアが型付き表層へ変換されないため、整数の検査を共通のJSON境界にも追加した点が実装上の補完である。named-exchangeの古い穴のLetもL5の規則へ移す必要があった。主定理の前提・結論・公理・Builtins.Assumptionsを変える判断は不要であった。

旧構築器のrefsを要求するassertはkindの必須性へ、getRefの不一致はkindの注記の不一致へ、専用操作のStateを空の宣言で隠す拒否は通常引数のAskを隠す拒否へ移した。通常値化・番号・七つの捕捉境界・辞書・継続・定数の拒否のassertは新版で維持する。旧版の30件成功を維持したとは記録せず、旧版での拒否と、新版での意味の成功を分けて記録した。ignore化・弱い期待への変更はない。

作成時の関門はbatch4-exchange/READMEに記した。持ち主は六つの本番交換CLIであり、JSONの保持・受理/拒否・厳密な期待コアと比較の件数を確認する。テストダブルや本体のテスト専用APIは使っていない。新規の76テストという意味ではなく、既存を含む七スイートの合計が76である。入力に深い再帰・長いリストはなく、Kの大入力の縮小は要しない。

Rust本体・テストの行数の増減は0。Lean本体はVersion.leanへ14行追加、削除0。Pythonはbatch3から90行減、新しいbatch4へ340行追加であり、六つの既存検査メソッドは新版へ移した。大きい独立JSONは本体のコードとは別の検査入力である。

## 後の作業への申し送り

- RV2は既定ビルド・公理比較・01-12/07-04の写し・独立入力をレビューできる。今回の成功はLean段の証拠であり、Rust全比較の成功ではない。
- B2はtests/desugar_exportとその読者を13/5へ切り替える。旧12/4の構築器を新規則へ読み替える互換処理は作らない。旧batch3用の --rust-dir はそのまま新版に使えない。
- 本番Rustの予定入力数と六入口への割り当ては `formal/tests/batch4-exchange/README.md` の表を使う。T1・T2・B2・B3・G2・G3で実ソースから局所比較を行い、各作業が実際の件数を固定する。全比較の件数の最終更新は各Rust作業とV1へ渡す。
- Logは通常宣言・既存checkerの適用例であり、hereの実展開・stderrの出力・出力一回性はG1/G2の実装で確認する。検査済みListの小モデルの証明はG3の通常コードの保証とは別である。
