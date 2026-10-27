# A21d の結果

着手: 2026-10-26 16:07:39 JST。終了: 2026-10-26 16:32:02 JST。所要時間: 24分23秒。

**状態: A21d の指定範囲の実装、Lean 由来の固定表の再生成・照合、局所検査、指定 work、自己点検を完了した。独立レビュー・受け入れは取りまとめへ引き渡す。**

B_WORK・HEAD は `121683e49e2bd94c99357db0951f7decc241b9df`、ブランチは `mod012/A21d`。着手時の差分はなかった。plan.md「計画の変更（2026-10-26、RV-A21 を受けて）」の A21d の行と依頼の補足を優先した。共通依頼文、受け渡す契約、A19b の検査の割り当て、RV-A21 と response、D16 の追記と訂正、a19a・a19b・a21b・l25t の結果、固定表の README、現行設計書を確認した。rtk・test-audit・japanese-tech-writing を適用した。

## 実装した範囲

| 対象 | 変更・確認 |
|---|---|
| `crates/benitoite/src/typeck/interval/flow/range.rs` | `standard_direct_call` に、`identity::name_form` が PrimName にする組み込みの操作を加えた。`BindingKind::Op` で `resolved.builtin_ops` に存在し、Failure.raise ではない宣言だけを認める。型・エフェクトのパラメータと制約が空という既存の条件は保った |
| `crates/benitoite/src/typeck/interval/flow/fixed_domain.rs` | `copy_within` の直前に、count は2から減るだけであり、found は take(count) の位置なので `offset < count ≤ expected.len()` となる前提を記した。計上・置換の処理は変更していない |
| `crates/benitoite/src/typeck/interval/tests/budget_reference.rs` | 既存の本体予算の表形式の比較に7形を追加した。本物の名前解決・型検査・本体入口を通し、Lean の独立期待値と全列を比較する |
| `crates/benitoite/testdata/interval-budget/` | 生成元に7形と独立に記述したシフトの標準表・出現表を加え、再生成器の形の総数と README を更新した。Lean の実行値で body.tsv を生成した。whole.tsv・summary.tsv は不変 |
| `formal/Benitoite/Interval/DomainExamples.lean` | exitSource を型引数付き primName、listenSource を単相の primName にした。操作の固定域の項を含めない表で警告と認定がないことを #guard で確認する。未知の正常値・失敗の導出の例は、操作の項を含めない具体環境で述べた。利用者の操作の opName の除外例は残した |
| `formal/Benitoite/Interval/FixedDomainExamples.lean` | operationCall を Console.writeLine の primName にし、操作の固定域の項がない表で位置を認定せず W0404 を作らないことを #guard で確認した |
| 01-12・07-04 | 単相の組み込みの操作の primName も同じ照会に進むこと、操作の固定域の項を標準束縛表に置かないこと、型引数付き exit は照会前に除くことを明記した |

標準表の照会は Lean の `standardCallHead`・`rangeCall`・`rangeStandardAt` と同じ頭の集合に揃えた。頭の判定の後、出現表の一参照、宣言が存在する場合だけ標準表の一致までの走査、規則ごとの認定という順序と回数は変更していない。操作の固定域の項は登録せず、W0404 の対象は純粋なシフトの直接引数だけである。Range の由来・射影は従来どおり FunName に限る。

02-05「区間解析の内部入力」の「型引数・エフェクト引数・辞書のない FunName・PrimName の頭で照会」「OpName と型引数付きの頭では照会しない」、純粋なシフトだけの契約と標準表の順序は、修正後の実装と一致する。02-05 自体の書き換えは不要だった。

Lean の実行定義・名前付き定理・公理、言語規則、Rust の型とシグネチャ、`formal/lakefile.toml` の `-M 12288` は変更していない。formal/ の差分は上記の例の二ファイルだけである。

## 固定表と退行の再現

追加したのは `builtinOperation`（Console.writeLine の後に除数0）と、`shiftPrimInside`・`shiftPrimOutside`・`shiftPrimReverse`・`shiftFunInside`・`shiftFunOutside`・`shiftReturn` の計7形である。組み込みの Integer.shiftLeft は primName、包みの Integer64.shiftLeft は funName とし、域内・域外、逆順の名前付き引数、対象引数の後の別の引数の return を含めた。

Lean の生成元は、実装の費用から期待値を作らず、27宣言の契約を独立に指定して完全名の辞書順に並べる。出現表は元の Surface の先行順から作る。既存と同じ四資源・上限0〜200・fuel 200を使い、0から完走境界の直前・ちょうど・直後までの全停止位置を比較する。

最初の再生成では、追加入力の `.rightUnsigned` の型が定まらず Lean が終了1になった。`ShiftOperation.rightUnsigned` と型を明示して訂正した（right も同じ書式に揃えた）。[初回の出力](reference-generate.log)・[JSON](reference-generate.json)と、[Lean の生出力 ZIP](reference-generate/raw-logs.zip)を保存した。Lean の実行定義・入力の意味・予算は変更していない。単体例の最初の起動も実行ディレクトリの指定を誤って終了2となったが、Lean は起動しておらず、実行器の作業ディレクトリを直して下表のとおり成功した。

再生成器は最初に専用の desugar_export を実行し、Range の実交換の宣言だけを取得した。成功した再生成と --check は、その同じ宣言の保存先を `--range-export` で渡した。Rust の解析結果・操作数から期待値を作っていない。

| 表 | 旧→新の行数 | 既存行の変更 | 追加 | 削除 |
|---|---:|---:|---:|---:|
| body | 18,342→19,282 | 0 | 940 | 0 |
| whole | 6,304→6,304 | 0 | 0 | 0 |
| summary | 6,304→6,304 | 0 | 0 | 0 |

追加の内訳は builtinOperation が90行、shiftPrimInside・shiftPrimOutside が各126行、shiftPrimReverse が132行、shiftFunInside・shiftFunOutside が各158行、shiftReturn が150行である。[差の詳細](reference-diff.json)に表の SHA-256 と件数を記録した。既存行のキー・全列が一致し、whole・summary はバイト単位で一致する。`regenerate-reference.py --check` も三表との完全一致を確認した。

修正前の Rust で拡張した本体予算のテストを実行すると、builtinOperation の本体操作上限7で期待した不一致が起きた（[出力](regression-before.log)・[JSON](regression-before.json)）。Rust は stop=3・saved=3・peak=9・独立入力あり、Lean は stop=1・saved=2・peak=7・独立入力なしだった。照会を揃えた後は、本体・全体の予算境界を含む既存4テストがすべて成功した。

テストの作成時の関門を通した。守る契約は、任意の小予算での操作数・保持・番号・停止分類・保存した候補と独立入力の一致である。現実的な退行は、組み込みの操作の照会の欠落、シフトの標準表・引数の置換・選択・候補保存の計上のずれである。既存表にはこの二種類の call がなく、診断だけのテストでは小予算の差を捕まえない。既存の表形式のテストに行を加え、差し込み口・公開範囲・新しいテスト関数は増やしていない。既存のテスト・上限・入力・期待値・ignore を緩めていない。

## 検査と記録

実行場所は `<repo>`、Lean の入口は `<repo>/formal`。固定版 Rust 1.98.1・Lean 4.34.1、書き込み可能な既存の `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。[実行器](run.py)が手元のパスを伏せ、同名の JSON にコマンド・終了状態・外側時間を保存する。

| 検査 | 結果・外側時間 | 記録 |
|---|---|---|
| DomainExamples の単体検査（-M 12288） | 終了0、3.088秒 | [JSON](examples-domain.json) |
| FixedDomainExamples の単体検査（-M 12288） | 終了0、0.387秒 | [JSON](examples-fixed.json) |
| 修正後の固定表生成 | 終了0、94.370秒。本体/全体76.949秒、集計17.235秒 | [出力](reference-generate-final.log)・[JSON](reference-generate-final.json) |
| 修正前の退行確認 | 期待した失敗、終了101、21.978秒 | [出力](regression-before.log) |
| 修正後の予算境界の局所検査 | 4件成功、終了0、17.803秒 | [出力](budget-after.log)・[JSON](budget-after.json) |
| 途中の割り当て量 | 2件成功、終了0、16.362秒 | [出力](allocations.log)・[JSON](allocations.json) |
| 固定表の --check | 終了0、93.397秒。本体/全体76.203秒、集計17.022秒 | [出力](reference-check.log)・[JSON](reference-check.json) |
| 指定 work の dry-run | 終了0、0.086秒。8単位、全統合、formal_build を確認した | [出力](work-dry-run.log)・[JSON](work-dry-run.json) |
| DomainExamples の最終の逐次ビルド | 終了0、0.679秒 | [出力](examples-build-domain.log)・[JSON](examples-build-domain.json) |
| FixedDomainExamples の逐次ビルド | 終了0、0.466秒 | [出力](examples-build-fixed.log)・[JSON](examples-build-fixed.json) |
| 作業末の work | **8単位成功、検査本体0、487.043秒。外側487.069秒・終了1（計測の制限）** | [本体](work-check.json)・[外側](work.json)・[出力](work.log) |

生成と --check の Lean の生出力は、それぞれ [生成 ZIP](reference-generate-final/raw-logs.zip)・[索引](reference-generate-final/raw-logs-index.json)、[確認 ZIP](reference-check/raw-logs.zip)・[索引](reference-check/raw-logs-index.json)に保存した。[Range の実交換](reference-generate/range-bindings.json)も残した。ZIP の展開内容と SHA-256 は保存前の出力と一致する。

Lean の単体検査と固定表の生成・確認には常に `lake env lean -M 12288` を使い、逐次実行した。例の二モジュールも一つずつビルドし、既定ビルドで両方のコンパイルを同時に起動させなかった。Lean の実行中に別のビルドや編集を進めていない。終了143・メモリ上限による停止はなかった。

作業末の指定は次のとおりである。同じ指定の --dry-run の後、[work-check.py](work-check.py)から一度だけ実行し、外側を `/usr/bin/time -l` で包んだ。--test を省き全統合とした。失敗に伴う再検査はない。

```sh
scripts/check.sh --level work --base 121683e49e2bd94c99357db0951f7decc241b9df
```

fmt、examples を含む clippy、lib 全件、全統合、ソース規約、生成 Skill、仕様集計、既定の Lean ビルドと sorry の拒否の8単位が成功した。lib は **1,332件成功・失敗0・既存 ignored 21件**、全統合は **40ターゲット・391件成功・失敗0・既存 ignored 10件** である。[ターゲット別件数](work-counts.json)を保存した。生成 Skill に新しい差分はなく、仕様集計の初回リリース版の完了条件の未記入は none だった。

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体の終了0の後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。real/user/sys は487.05 / 1454.03 / 92.78秒である。最大常駐量の未取得を0とせず、取得のための再実行もしていない。

| 割り当て量の入力 | 途中の実測値 | 保持した上限 |
|---|---:|---:|
| 20,000定数の鎖 | 442,858,487バイト | 536,870,912（512 MiB 未満） |
| 5,000定数・1,000診断 | 254,972,750バイト | 268,435,456（256 MiB 未満） |

両方とも前段の記録より35,658バイト増えたが、指定の上限内である。入力・上限・期待値は変更していない。作業末の全統合でも call_allocations の3件が成功した。

## 最終点検と申し送り

[自己点検器](self-review.py)と[結果](self-review.json)で、[検査開始時の入力ハッシュ](work-inputs-sha256.json)が最後まで一致すること、formal/ の差分が例の二ファイルだけであること、固定表の既存行・全体・集計の不変、ZIP のハッシュ、記録のパスの伏せ方、Python の構文、`git diff --check` を確認した。work の開始後に変えたのは、本ディレクトリの結果・ログの保管と点検の記録だけである。

計画の範囲の変更はない。停止条件に当たらず、4時間による区切りも不要だった。言語規則・Rust の型とシグネチャ・Lean の主要定理の前提や結論・公理に関する判断を残していない。別状態の検査結果の引用によって省いた検査はない。

private/ とそこを指すリンクは読んでいない。git の変更操作、コミット・取り込み・docs/todo の更新・保管・公開、担当の委任は行っていない。stage・short・change・release・check-formal.sh 全体と実 VM の比較は本枝では実施していない。小予算の固定表の一致を全関係状態・VM の比較の代わりとはしない。

| 残る手順 | 担当・受け入れの区切り | 見込み |
|---|---|---|
| A21d の独立レビュー、受け入れ、コミット・取り込み | 取りまとめ。本結果の引き渡し後 | 不明 |
| S-A4 の該当部分の再検査の要否判断、short の測定、案III の区切りの受け入れ | 取りまとめ。A21d の差分を確認した後。stage の範囲は取りまとめが確定する | stage は計画の3〜10分、short の標本採取は計画の15分以内。ビルド・レビュー・受け入れは不明 |
| 実交換・全関係状態・実 VM の比較と改造全体の検査 | X 作業以降と取りまとめ、計画の各区切り | 計画による。今回の枝では未測定 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。RV-A21 の中1・軽2・軽3 を閉じる。Lean の変更は例の二ファイル（操作の頭を `.primName` に直した）だけで、定義・定理は変わらない。予算の固定表は加えた7形の body の940行だけが増え、既存の行と whole・summary は変わらない。`call_allocations` の二件は約36KB 増えたが上限の内側である（組み込みの操作の頭での照会の分）。work は全統合を含んで成功したので、S-A4 の六つのターゲットも A21d の後の状態で通っている。S-A4 はやり直さない。
