# RV-R08: 相乗りの接続の独立レビュー

- 日付: 2026-10-24
- 担当: Claude Code のサブエージェント（Opus 5.5）
- 対象: [依頼](RV-R08-request.md)に従い、`f76f32234a55bd952c53aeda0685bd9dfef5a2b2..a7a6fe88c8d9213227eecbaee22f1b086ceee236` の R01〜R08 の実装・文書・記録（集約の `results.md`、`r01`〜`r08/results.md` を含む）を、`README.md` の設計者の決定、`decisions.md` の D7・D9〜D14、`plan.md` の R01〜R08 と照合した。
- 方法: 差分と現行のソース・設計書を読んだ。実行は既存の `target/debug/benitoite`（0.0.11）での小さなスクリプトの `check`・`run` だけである。cargo・`scripts/check*.sh`・`lake`・derive の自己検査は実行していない。private/ と `docs/todo/` は読んでいない。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 4 |
| 軽 | 6 |

言語規則の変更、Lean の主な定理の前提・結論の変更、公理の追加を要する所見はない。

## 中

### 中1 集約結果の S-R1 の扱いが同じ文書の中で食い違う（読めば確定）

- 場所: `results.md`「stage S-R1（R01 の後）」（5行）と、同「stage と独立レビューへの引き渡し」（33行）。`r08/results.md`「計画からのずれと申し送り」の3項目め（57行）。
- 問題: 5行は「R08 が新たに実行した `policy_selftest`（22件）を S-R1 の証拠とする。引用ではない」と書く。一方、33行と r08 の57行は「S-R1 の上記の省略記録には全欄がなく、……不足する検査は計画の stage 行で実行する」と書き、R01 の結果を引用して省いていた改訂前の S-R1 の記述（ef48dfb8）を前提にしている。読み手には、S-R1 が済んだのか、受け入れ時に実行が要るのかが定まらない。また、5行の証拠は計画の `scripts/check.sh --level stage --base B_STAGE --only policy_selftest` ではなく、`python3 -B scripts/check/test_policy.py` を直接実行した結果である。中身は同じ（`scripts/check.sh` 566行の `policy_selftest` は同じコマンド）だが、記録にその旨がない。
- 修正案: 33行と r08 の57行を、5行の現在の扱い（a4d49907 で直接実行した22件を S-R1 の実行結果とする）に合わせて直す。5行には、実行したコマンドが stage の単位 `policy_selftest` と同じであること（`check.sh` の該当行）、基準と HEAD（`a4d49907`）、実行の入口が stage の dry-run を通していないことを一文で書く。stage の入口での実行を求めるなら、計画の stage 行を取りまとめが一度実行し、その記録で置き換える。

### 中2 設計書の二章に、現行の derive の版が旧版のまま残る（読めば確定）

- 場所: `docs/design/06-tooling/06-06-agent-skills.md`「実行の前の確認」154行の「生成記録・意味ハッシュ・manifest/receiptは版3、生成規則は3.0.0-syntax-batch4、宣言inventoryは版2、設定は版1を使う」。`docs/design/03-interop/03-08-text-and-data.md`「レコードのProperty生成器」212行の「宣言inventory版2の解決済みの型の木から」。
- 問題: 現行の生成器は `3.1.0-syntax-batch5`、inventory は版3であり（`tools/derive/derive.py` 28〜29行、03-06 756行、新しい 06-09「derive の生成先と版」）、上の二箇所は現在の実装と、03-06・06-09 と食い違う。D12 は「現行の説明を D11 の版へ直す」と決めたが、調べ（`study/riders.md` の旧版表記の表）がこの二箇所を挙げておらず、R04 と R08 の照合も拾っていない。0.0.11 からある不一致だが、今回の改造が現行の版の説明をそろえた範囲の漏れである。06-06 の同じ段落は Skill の案内を写す位置づけなのに、Skill に加えた JSON/Property の事前拒否も書いていない。
- 修正案: 06-06 の版の文を、03-06「外部生成の管理と照合」への参照に置き換える（版を三章目に重ねない）か、少なくとも `3.1.0-syntax-batch5`・inventory 版3 へ直す。必要なら、ファイル単位の `uses` がある生成対象への JSON/Property の拒否も一文で加える。03-08 は「宣言inventory（版3）」か版を書かない形にする。日本語訳の同期の申し送り（Z01a）に、この二箇所に対応する訳がないかの確認を加える。

### 中3 06-09「derive の生成先と版」が章の範囲の外にあり、03-06 の決定と重なる（読めば確定）

- 場所: `docs/design/06-tooling/06-09-packages.md`「derive の生成先と版」（63〜71行）、同章「目的と範囲」、`docs/design/README.md` の 06-09 の行、03-06「外部生成の管理と照合」756・760行。
- 問題: 06-09 の「目的と範囲」と目次の説明は、package.bnt・言語の版・依存・ハッシュ・`benitoite package` だけを挙げ、開発用の derive の生成先を含まない。新しい節はどこからも参照されていない（`git grep` で参照元なし）。さらに、節の【決定】「生成器は `3.1.0-syntax-batch5`、inventory・manifest・receipt・生成記録・意味ハッシュは版3、設定は版1、Property.libraryVersion は `2.0.0`」は、03-06 756行の同じ版の決定と重なる。「旧 manifest は……途中の適用・復旧は道具を更新する前に保存した旧道具で終える」の段落も、03-06 760行の「未完の旧applyは旧道具で復旧してから」と重なる。取りまとめが R04 で拒否の決定の重複を一つ外した（`r04/results.md`「取りまとめのレビューでの修正」）が、版と復旧の重複が残った。次に生成器の版を上げるとき、二章を直す必要が生じる。
- 修正案: 次のどちらかにする。(a) 節を 03-06「外部生成の管理と照合」へ移し、対処（個別の `uses`、型定義と生成対象の移動、`source` だけでは分離できないこと）と「この拒否を理由に E0908 を登録しない」の一文を 03-06 に置く。06-09 には何も残さないか、E0908 の登録表の直後に「開発用の道具の版は登録しない（03-06）」の一文だけを置く。(b) 06-09 に残すなら、版の列挙と旧 manifest の段落を 03-06 への参照に置き換え、06-09 の「目的と範囲」と `docs/design/README.md` の説明に「開発用の derive の生成先と版の案内」を加える。D14 の「版ごとの登録内容と移行案内を06-09へ集める」は言語の版（E0908）についての決定であり、(a) と矛盾しない。

### 中4 カスタムの JSON/Property 関数の合併後の署名の純粋さを確かめるテストがなくなった（読めば確定）

- 場所: `tools/derive/test_derive.py` のカスタム JSON 署名の表（1123〜1129行）と、カスタム Property 署名の表（1364〜1371行）の `('public record Person', 'uses Log\npublic record Person', 'derive.file_effects')` の行。
- 問題: 変更前、この行は「カスタム関数のある生成対象のファイルに `uses Log` を加えると、合併後の署名が純粋でないので `custom ... must be pure` で拒否する」ことを確かめていた。カスタム関数（`People.enc` など）が生成対象と同じファイルにあるため、今は先に `derive.file_effects` で拒否され、`TypeGraph`／テンプレートのカスタム署名の照合（`derive.py` 563行）まで届かない。ほかの行は個別の `uses IO.All` だけを使うので、ファイル単位の宣言をカスタム関数の署名へ合併して照合する経路は、どのテストも通らない。README（「Custom JSON/Property callbacks must also have pure merged signatures」）と 03-06（「合併済みの有効な署名で照合する」）が定める契約である。照合が個別の `uses` だけを見るように退行しても検出されない。
- 修正案: 二つの表のこの行を、純粋な生成対象のファイルとは別のモジュール（例: `Custom.bnt` に `uses Log` を置き、`fields` から `Custom.enc` などを指す）にカスタム関数を置く行に替え、`custom .*must be pure` を期待する。`derive.file_effects` の早期拒否の確認は `FileEffects` の表が受け持っているので、この行で重ねて確かめる必要はない。test-audit の作成時の関門を通す。

## 軽

### 軽1 06-09 の版の表の後の「この項目の移行案内は」が、0.0.5・0.0.6 の help と合わない（読めば確定）

- 場所: `06-09-packages.md`「設定ファイルの検査」の表と55行。
- 問題: 55行の「この項目の移行案内は、スクリプトを見直した後に `language` を現在の処理系の版へ更新し、依存のハッシュを更新するよう促す」は、表にしたことで全行に当てはまると読める。しかし `crates/benitoite/src/modules/text.rs` の `NAMED_ARGUMENTS_MIGRATION`（0.0.5）と `KEYWORDS_OPEN_TYPES_TRY_MIGRATION`（0.0.6）は language と依存のハッシュに触れない。0.0.9 の行は、help（`CONSTANT_REGEX_MIGRATION` の「review constant patterns, language declarations and dependency hashes」）と旧本文にあった「language 宣言・依存のハッシュ」を落とした。参照の曖昧さは移動前の本文にもあったが、表にしたことで誤読しやすくなった。
- 修正案: 55行を「0.0.7〜0.0.11 の案内は、……language を現在の処理系の版へ更新し（0.0.9 は見直しを促し）、依存のハッシュを更新するよう促す。0.0.5・0.0.6 の案内は促さない」と、実装に合わせて書き分ける。0.0.9 の行に「language 宣言・依存のハッシュを見直し」を戻す。

### 軽2 `Log.formatRecord` の大きさの上限の報告が `Log.emit` を名指す（名前は読めば確定、報告の実際の文面は未実行）

- 場所: `crates/benitoite/src/builtins/funcs/log.rs` 76・85行の `StrBuf::new("Log.emit")`。
- 問題: `format_record` は emit・`Log.formatRecord` で共有され、上限を超えると `ResourceError::ValueTooLarge { function: "Log.emit", .. }` を返す。公開した `formatRecord` を利用者が直接呼んで上限（`MAX_STRING_BYTES` = 1 GiB）を超えたとき、報告は呼んでいない `Log.emit` を示すはずである。1 GiB の文字列を作る再現は、同じ作業ツリーで別の担当がビルドしているため実行していない。withTextLogger 経由では以前からこうなっていた。
- 修正案: `format_record` に関数名を引数で渡し、`formatRecord` からは `"Log.formatRecord"` を渡す。直さないなら docs/todo に「直接の呼び出しの報告名」として登録する。

### 軽3 `Manager.prepare` の `TypeGraph` の構築を対象の検査の後へ移したことが記録にない（読めば確定）

- 場所: `tools/derive/derive.py` 1011〜1027行、`r02/results.md`。
- 問題: R02 は `inventory['_typeGraph'] = TypeGraph(...)` を、対象ごとのループ（新しい `derive.file_effects` と既存の `derive.opaque_target`）の後へ移した。受理する入力の結果は R03 の旧新比較で一致を確かめているが、型グラフの拒否と opaque の拒否が両方当たる入力では、報告する誤りの順が変わる。R02 の記録はこの並べ替えに触れていない。
- 修正案: 振る舞いを直す必要はない。`r02/results.md` か本レビューへの対応に、「型グラフより先にファイル単位の宣言と opaque を判定するため並べ替えた。拒否する入力の報告順だけが変わる」と一文残す。

### 軽4 SKILL.md の「Its declaration inventory」が指す語を失った（読めば確定）

- 場所: `crates/benitoite/skill/SKILL.md` 269行。
- 問題: 事前拒否と移動の案内を間に挟んだため、「Its」の直前の文は「…before making a fresh preview.」になり、指す語（derive の道具）がない。
- 修正案: 「The derive tool's declaration inventory uses version 3; …」とする。訳の同期（Z01a）でも合わせる。

### 軽5 作業結果に一時スクリプトの絶対パスが残る（読めば確定）

- 場所: `r03/results.md`「旧新の互換比較」と「実行した検査」の `/private/tmp/benitoite-r03-compat.py`、`r04/results.md`「実行した検査」の `/private/tmp/benitoite-r04-doc-check.py`。
- 問題: `/Users/...` は差分のどこにもない（ベンチマークの記録も `<repo>`・`<home>` に伏せてある）。ただし上の二つは手元の一時パスで、スクリプトも保存していないので、記録から再現できない。R08 は同じ種類のスクリプトを `<tmp>` と書いた。
- 修正案: `<tmp>/benitoite-r03-compat.py` などに伏せ、スクリプトを保存していないことを一言添える。R03 の旧新比較を後で引用するなら、比較の手順（取り出した B0、固定入力10件、比べたファイル）が本文にあるので、それで足りるかを取りまとめが判断する。

### 軽6 03-07 に文書の例の中身の説明が入っている（読めば確定）

- 場所: `docs/design/03-interop/03-07-io-modules.md`「Log と SourceLocation」の53・55行（「英語リファレンスと同梱 Skill の実行例では……」「例は `end with` の後に `File.readText` で……」）。
- 問題: 設計書は処理系の仕様を書く場所であり、利用者向けの例がどう組まれているか（読み戻し、宣言する効果、JSON の形）は英語リファレンスと Skill に書いてある。例を直すたびに 03-07 も直す必要があり、ずれやすい。規則として要るのは「JSON の標準形式は定めない」「Log から Json への依存を加えない」「出力関数は解放後に呼ばない」程度である。
- 修正案: 53・55行を、規則（標準の JSON 形式を定めない、Log は Json に依存しない、パスごとの実行時の許可はこの組み合わせでは制御しない）に絞り、例の中身は英語リファレンスの節への参照にする。

## 実行して確かめたこと

スクリプトはリポジトリの外の一時ディレクトリ `<tmp>/rv-r08/` に置き（保存しない）、`target/debug/benitoite`（0.0.11）で実行した。

| 確かめた主張 | 観察 |
|---|---|
| 英語リファレンスの二例（テキストと JSON）の期待出力 | 節から取り出した二例を `run` し、どちらも期待出力と一致、終了0 |
| 「using the captured Writer after release is a runtime error」 | Writer を捕捉した出力関数を `with` の外へ返して呼ぶと、`R0402: File.Writer is used after it was released`、終了1 |
| 書き込みの失敗を値で扱い、ブロックの最後で `File.closeWriter` の Result を調べる形 | 正常時は `closed ok`、書いた行が残る。失敗時の振る舞いは 03-07「File」の【決定】（失敗の状態と解放の失敗）と一致する記述であることを読んで確かめた。書き込みの失敗そのものは再現していない |
| 「State for release」 | `main` から `State` を外すと `with` の行で E0501 |
| 「directly stringifying a non-finite `Json.Value.Float` would produce null」 | NaN・正の無限大・負の無限大とも `null`（配列の中でも `[null]`） |
| `Float.isNaN(number - number)` による非有限の判定 | 正負の無限大で真、1.5 で偽。`Float.toString` は `Infinity`・`-Infinity`・`NaN`。例は無限大を実行していないと書いており、主張と矛盾しない |
| `formatRecord` の非有限の表示 nan/inf/-inf | `attr."a"=inf attr."b"=-inf attr."c"=nan` |

## 読んで確かめた主な事実

- derive の事前拒否は `Manager.prepare` にあり、`preview`・`check`・初回の `apply`（`self.prepare() != plan` の再計算）が同じ入口を通る。receipt による再適用の経路は `prepare` を呼ばないので、復旧へ拒否を広げていない。診断は対象・機能・宣言の原文・元の UTF-8 バイト位置・理由を含み、最初に当たった対象で全体を拒否する。判定は `'property'`／`'json'` のキーの有無で、既存の opaque の判定と同じ書き方である。
- Show/Order が生成する実装のメソッドにファイルの効果が及ばないことは、01-07 の「ファイルの直下の関数宣言すべて」の規則と一致する。`source` が型の宣言元と一致しなければならないことは、`derive_inventory` の `TARGET_SOURCE_DOES_NOT_MATCH_DECLARATION` で確かめた。
- 生成器 `3.1.0-syntax-batch5`、inventory・hash 3、設定1、Property.libraryVersion 2.0.0 は、`derive.py` の定数、03-06、06-09、README、英語リファレンス、SKILL.md で一致する（中2の二箇所を除く）。過去版の移行節（英語リファレンスの「Migrating to 0.0.10」、README の旧規則の段落、03-06 760行）は当時の版のまま保たれている。
- `Log.bnt` の `formatRecord` は `@builtin("Log.formatRecord")`、引数名 `record`、純粋、戻り値 String のまま `public` と doc を加えただけである。withTextLogger は `formatRecord` を呼び、既定の emit は同じ Rust の `format_record` を使う。生成参照 `stdlib/Log.md` の本文は Log.bnt の doc と一致し、`bundle.rs` は既存の `Log.md` を埋め込む。
- 英語リファレンス「File and JSON log sinks」と `idioms.md`「File and JSON log sinks」の本文は、文字単位で同一である。`Json.Value` に符号なし整数の構成子がないことは `Json.bnt` で確かめた。
- `scripts/check.sh` の新水準の `lint_default` だけに `--examples` を加え、互換指定の `rust`（674行）は従来のまま、`legacy-commands.json` は差分なし。`test_policy.py` の期待コマンド（work と change）と分類の表、07-03 の三つの表、workflow の二つの雛形の記述は一致する。
- 01-03 には language の意味・省略できる場所・照合規則だけが残り、具体的な版は残っていない。06-09 の表の7件の版と順は `BREAKING_CHANGES` と一致し、0.0.6・0.0.7 だけ CHANGELOG の節を名指さない違いも help と一致する（軽1を除く）。`modules/tests.rs` の spec 印と `package.rs` の `//!` の参照する見出しは変わっていない。
- 01-04 の Q4 の訂正は、02-05「警告」の対象の表（`typeck/consts.rs` の `integer_call` の9モジュール×3関数、別名を含み、`Byte`・関数値・穴・パイプを除く）と一致し、新しい局所解析の条件を含まない。
- 差分のどこにも `/Users/...` は残っていない。
