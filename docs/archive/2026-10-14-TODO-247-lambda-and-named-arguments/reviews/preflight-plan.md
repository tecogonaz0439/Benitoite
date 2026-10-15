# 実装プランの事前点検（2026-10-14、Opus 5.5 のサブエージェント 2 つ）

## 段 1（L1〜L4）

【重大】
1. design.md「終端付きとの判別と入れ子」と R3: 終端付きを優先すると、外側のラムダの `end lambda` を内側の短いラムダが取る。反例:
   ```
   bind g <- lambda(y)
     bind f <- lambda(x) return x + 1
     return f(y)
   end lambda
   ```
   内側を終端付きと読むと外側が閉じず E0214 になる。メモ化と「外側の終端を割り当て直さない」決まりがあるので後戻りでも直らない。修正案: (a) 見出しと同じ行に本体の文があるラムダは、その文の直後（同じ行か次の行）に `end lambda` が続くときだけ終端付きとする（今の `lambda() bind _ <- …⏎ return 1 end lambda` の形、io/tests.rs:639 など約 13 か所は移行か診断）、または (b) 未確定のラムダを数えて終端を外側から対応付ける規則を定める。
2. design.md「構文解析と改行判定の構成」・L2: 構文解析器は改行判定の後の字句列（Newline を含む）を読む。改行判定の中で構文解析器の規則を再利用すると循環する。「仮の改行カーソル」で Parser の `tokens`/`pos` をどう動かすのかが書かれていない。修正案: 方式を一つに決めて書く（構文解析器が LineBreak を受け取って文脈で判断する方式か、改行判定が行の情報だけで短いラムダの終わりを決める方式）。

【中】
3. L2 で diag/codes.rs と 01-02 を変えると skill の生成物が古くなり skill_docs が落ちる。L2 に gen_skill と `cargo test --test skill_docs` を加える。
4. E0243 の文言を変えると `testdata/syntax/c11-lambda-colon.diag.json` が変わる。L2 に明記し確認表に記録させる。
5. 文の区切りは改行だけで `;` はないので E0254 と E0255 の条件が重なる。どちらを出すかを決める。
6. Token の物理行の欄の型と名前が決まっていない（R2 の表がない）。表にするか、LineBreak の字句と `Parser.text` から求めて Token を変えない案と比べる。

【軽】
7. L1 の触るファイルに `parser/mod.rs:182`（EOF）と `parser/items.rs:769`（restore_newline）が漏れている。新しい `lambda_bounds.rs` の `syntax/mod.rs` への登録も。
8. L3: 整形器に幅の改行はない。「Omitted の本体を block() で改行させない」と書く。
9. コメントの根拠は decisions/plan でなく設計書の節を引くと K に明記する。01-02 に見出しを足すなら `// spec:` の印と spec-coverage も合わせる。

## 段 2（N1〜N36）

【重大】
1. N21〜N24 の間に Lean との比較が崩れる。書き出し器（tests/desugar_export/exchange.rs 1247〜1284 行）は引数をソース順のまま `call` で出すので、逆順の名前付き呼び出しのテストで旧形式の surfaceCheckAll・desugarDiff が失敗する。対象外へ回すと N25 の条件に反する。N18〜N24 の検査に check-formal.sh がない（AGENTS.md の決まり）。修正案: v2 の書き出しを N21 の直後か中へ移し、N18〜N24 に check-formal.sh を加え、どの入力をどちらの形式で書き出すかを決める。
2. N35 で `language "0.0.3"` の宣言（testdata 47 件、examples・docs・tools にも）が BREAKING_CHANGES の登録で E0908 になる。宣言の一括更新と版の検査のテストの見直しを N35 に加える。

【中】
3. skill_docs が L2・N18・N20〜N24・N26・N31・N33 で古くなる。各作業に gen_skill と skill_docs を加える。
4. Lean のファイルの割り当て漏れ: `Release/Coverage.lean`（1789 行）、`CoverageShow.lean`、`Surface/CheckToolsExamples.lean`。CheckTools と CoverageRuntime は Coverage を import するので N5・N12 がビルドできない。実行ファイル builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheckAll が N15・N34 にない。Coverage の作業を加え、N15・N34 に六つの実行ファイルと coverage_export を挙げる。
5. N34 が大きすぎる（約 2.5 万行の名前空間の移動、書き出し器の統一と旧形式の削除、01-12・07-04、スクリプト）。三つ程度に分ける。
6. 移行中の旧表記（Legacy）の型の表現が R2 の表にない。Legacy の表現と、等しさ・ハッシュ・統合の意味を R2 に加える。
7. N20 からラムダの名前が型に入ると、`if`・`match` の分岐、リストの要素、`Reference.set`、レコードの欄、戻り値で名前の違うラムダを合わせる既存の入力が N20 で落ちる。宣言の契約がない場合に移行の道具が選ぶ名前も未定。N1 で数え、移行中の扱いと道具の規則を定める。
8. 仕様の変更で診断コードが変わる負のテストの扱いがない（`f(1, 2, 3)` の E0402 → E0451/E0453、ラムダの E0401 → E0454 が先）。「仕様上の診断の変更」の分類と旧→新の対応表を作り G7 で承認する。N28 でラムダのパラメータ名も直す対象に含める。
9. 契約が決まらない場合（使われない `bind run <- lambda(g) return g(1) end lambda`）に E0455 か、`param_names` に何を入れるかが未定。契約変数を一般化しないので同じ `apply` を `lambda(a)` と `lambda(b)` で使うと E0454。決めて N22 のテストに加える。

【軽】
10. 交換形式の今の版は corpus 7、組み込みの表と網羅性 1。「v1・v2」は紛らわしいので版 8 などと呼ぶ。
11. parser の `parse_name`／`record_ahead` は `Upper.Upper(lower:` をレコードの構文として読むので、`Pair.Pair(arg1: x)` の E0456 はレコードの経路で出す。レコードの構成子を関数値にしたときの名前（欄の名前か argN か）も未定。
12. N18 の「検査エラーで止める」ときの診断コードが未定。一時的なコードは RETIRED の表と Skill に残るので避ける。
13. N19・N20 で関数型の表示が変わり testdata の 11 件の JSON が影響を受ける。golden と記録を検査に加える。
14. N25 で 07-04 に「準備中」と書くのは設計書の規約に反する。改造のディレクトリに記録する。
15. コードのコメントに作業の ID を書かないとプランに明記する。
16. 新しい `tools/named-arguments-migrate/` を AGENTS.md のディレクトリ構成の表に加える。

## 対応

2026-10-14。現行のコードと照合し、[design.md](../design.md)・[decisions.md](../decisions.md)・[plan.md](../plan.md) を修正した。以下の R は設計者の未回答の暫定方針である。処理系・現在の設計書・テスト・docs/todo は変更せず、コミットもしていない。

| 指摘 | 修正箇所と対応 |
|---|---|
| 段 1・重大 1 | decisions.md R8（R3 の旧案を取り下げ）と design.md「終端付きとの判別と入れ子」: 同じ行または直後の行の終端に限定し、plan.md L1a で旧複数行入力を先に移行する。grep の候補 525 件・同じ行に終端のない 61 件と限界を R8 に記録し、互換性への制限は設計者への確認事項とした。 |
| 段 1・重大 2 | decisions.md R9 と design.md「構文解析と改行判定の構成」、plan.md L2: 字句列だけで行・区切りを判定し、単文の正しさは後段の parser で検査する方式に決めた。改行判定から Parser を呼ぶ循環と仮の Parser カーソルを除いた。 |
| 段 1・中 3 | plan.md L2: gen_skill による再生成、生成物の変更範囲、skill_docs を追加した。 |
| 段 1・中 4 | plan.md L2 と design.md「負のテストの分類と仕様上の診断の変更」: c11-lambda-colon.diag.json の主文・ヘルプの更新と、E0243 を維持する確認表を明記した。 |
| 段 1・中 5 | decisions.md R10 と design.md「段 1 の診断案」、plan.md L2: 複数行・改行した複数文の条件を E0254 に統合し、未割当の E0255 の新設を取り下げた。同じ行の二文の並置には parse_block の現行の構文診断を維持する。 |
| 段 1・中 6 | decisions.md R2・R9 と design.md の段 1 の R2 表: Token に start_line: u32・end_line: u32 を追加する案を選び、1 起点・排他的末尾・LF/CRLF・EOF・回復用 Newline の規則を定めた。Token を変えない案も R9 の選択肢 C に記録した。 |
| 段 1・軽 7 | plan.md L1・L2 と design.md の段 1 の R2 表: parser/mod.rs の EOF、parser/items.rs の restore_newline、syntax/mod.rs の lambda_bounds の登録を割り当てた。 |
| 段 1・軽 8 | design.md「フォーマッタ」と plan.md L3: 現行に幅による自動改行がないことを確認し、Omitted の本体を block() で改行させない作業へ書き換えた。 |
| 段 1・軽 9 | plan.md K: コメントは現在の設計書の章・節を引き、作業 ID と decisions/plan を根拠にしない。01-02 の見出し・spec 印・spec-coverage・生成元・参照を同じ変更で揃える条件を追加した。 |
| 段 2・重大 1 | design.md「交換形式と差分検査」と plan.md N19・N20・N21a・N21b・N22〜N25: 型・宣言の出力を先に用意し、名前付き通常呼び出しの実行と新出力は N21b で同時接続する。全 N18〜N24 に check-formal.sh を加え、入力単位で旧 corpus 7／新 corpus 8 を選び、対象外への退避を禁止した。 |
| 段 2・重大 2 | design.md「版と移行の診断」と plan.md N1・N35: 現行の language 宣言の一覧化・版更新と、旧版／未来の版を試すケースの見直しを追加した。指摘の 47 件は現行の `rg -l 'language "0.0.3"' crates/benitoite/testdata` では 46 ファイルなので 47 の固定値は採らず、実装時に数え直す。 |
| 段 2・中 3 | plan.md L2・N18〜N24・N21b・N26・N31・N33: 各作業の生成物と生成元を変更範囲に含め、gen_skill と skill_docs を完了条件に追加した。 |
| 段 2・中 4 | plan.md N5a・N5b に Coverage・CoverageShow・CoverageRuntime、N12 に CheckToolsExamples を割り当て、N15・N25・N34〜N34b に六つの入口と coverage_export の接続・全件比較を明記した。 |
| 段 2・中 5 | plan.md N34 を全件の新形式への統一と切り替え patch の準備にし、N34a に正式モデル・全入口・01-12/07-04 の同時切り替え、N34b に旧形式と一時経路の削除を分けた。G8 と後続の依存も更新した。 |
| 段 2・中 6 | decisions.md R2 と design.md「AST と静的な型の表現」の移行表、plan.md N18・N19・N33: ContractOrigin、IContract::Legacy、仮の名前の個数、Eq/Hash と制約の統合の違い、出力と削除を具体化した。 |
| 段 2・中 7 | decisions.md R11、design.md「既存入力の機械的な移行」「実装の途中の整合」、plan.md N1・N17・N19・N20・N33: 全種類の旧合流を数え、移行中だけ理由付きの旧適合を維持する。宣言がない成分はソース先頭のラムダ名を確認用候補にし、衝突・複数期待・公開契約を保留する。 |
| 段 2・中 8 | design.md「負のテストの分類と仕様上の診断の変更」と plan.md K・N1・N28・G7: 仕様による診断変更を独立分類にし、旧→新・根拠・元の誤りの検査の維持先を設計者が承認する。N28 の変更対象にラムダ名と束縛参照を追加した。 |
| 段 2・中 9 | decisions.md R12 と design.md「適合と推論」、plan.md N22: 未使用 run と g(1) は E0455、同一検査単位で確定後の a/b 不一致は E0454 とし、未確定 param_names は出力しない。注釈付き多相 apply と区別した検査を追加し、使い勝手は設計者への確認事項とした。 |
| 段 2・軽 10 | decisions.md R7、design.md「交換形式と差分検査」、plan.md K・N15 以降: v1/v2 の呼び方を corpus 7→8・型表 1→2・網羅性 1→2 に置き換えた。 |
| 段 2・軽 11 | decisions.md R13 と design.md「文法と呼び出しの対象」・命名表、plan.md N20・N21・N21b・N23: RecordExpr の resolve 経路でも E0456 を出し、レコード構成子値の契約名は宣言順のフィールド名とした。データ構成子の argN と取り出す関数の value を区別した。 |
| 段 2・軽 12 | plan.md N18・N19・N21b・N23: 非公開の解析補助を先に用意し、一般の parser 分岐は受け手と同時に接続する方式へ変更した。一時的な未実装エラーコードを作らず、未接続の一般経路には現行の構文診断を維持する。 |
| 段 2・軽 13 | plan.md N1・N19・N20 と design.md の負のテスト分類: 関数型の表示を含む JSON 11 ファイルを rg で確認した。実装時に一覧を固定し、golden と旧→新表示の理由の記録を各作業へ追加した。 |
| 段 2・軽 14 | design.md「交換形式と差分検査」と plan.md N25・N34a: 準備中のモデルの説明は改造ディレクトリの formal-rules.md に置き、現在の 07-04 には追記しない。正式モデルと写しの更新を N34a に揃えた。 |
| 段 2・軽 15 | plan.md K: 本番コードのコメントに作業 ID を書かない条件を明記した。 |
| 段 2・軽 16 | plan.md N17: tools/named-arguments-migrate/ の登録を AGENTS.md の表への実装時の変更として追加した。今回 AGENTS.md は変更していない。 |

文書の確認: 48 作業の一意性・既存 ID の維持・六つの必須欄・直接の依存順・G1〜G8 の全件割り当て、相対リンク、R1〜R13、対応表の 9＋16 行を確認した。`git diff --check` に問題はなく、`scripts/check.sh --dry-run` は文書だけの変更として検査対象なしを選んだ。その選択で `scripts/check.sh` を実行し、終了状態 0 を確認した。処理系のテストと Lean のビルドは実行していない。
