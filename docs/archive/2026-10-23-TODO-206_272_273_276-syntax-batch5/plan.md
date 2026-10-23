# 第5弾の実装プラン

2026-10-23、P1作成、P2でRP1対応。[共通雛形](../../workflow/change-plan-template.md)をこの改造へ具体化した計画である。検査方針の正は [07-03「実装の規約と静的な検査」](../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、形式化の順序の正は [07-04「01-12 との対応」](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応)とする。

## 前提と依存

- 目的: 書式付きの文字列補間（docs/todo のTODO-273）、表示の幅の六関数（TODO-272）、ファイル単位のエフェクトの宣言（TODO-206の今回の部分）、誤り由来の型の回復（TODO-276）を実装する。
- 範囲外: usesの改名、ログのファイル・JSON出力先、実行時の権限制御、動的書式・桁区切り・指数・切断・利用者定義の整形、バイナリ配布、push・タグ・履歴の集約。TODO-206の全体を閉じるとは扱わない。
- 採用する判断: [decisions.md](decisions.md) D1〜D42。言語の規則はD1〜D27、計画上の選択はD28〜D40、比較元と全比較の証拠の扱いはD41・D42を参照する。
- 開始版B0: `a9c4132e6451904698cf344db1794c4d03affcd6`。処理系は0.0.10のa0d652c0と同じである。初回作業の基準はB0、後続のB_WORKは直前の取り込みの完全IDとする。取りまとめは起動前に実際のIDを依頼と結果へ記入する。
- 共通依頼文: [implementation-request.md](implementation-request.md)。担当は新しいCodexセッションで一作業ずつ、同じ作業ディレクトリで直列に実装する。git操作はせず、終了後に取りまとめがレビューと取り込みを行う。
- 形式化の内側: TODO-273の解析済み書式の妥当性・型付け・脱糖・検査の健全性だけ。TODO-272の算法、TODO-206の合併前処理、TODO-276の失敗時の推論は外側であり、追加後の成功した型付き表層は既存の対象へ渡す。07-04の対応表へそれぞれの内外を記す。

一作業の実装・文書修正は30〜60分をセッションを区切る仮予算とし、work・測定・レビューの時間を別に数える。F0後とL1後に、実装・記録の実時間と残る箇所数を使って見積もり表全体を更新する。studyの総時間は未校正であり、下の各作業の仮予算へ分けた値を、実測による工数短縮とは扱わない。作業が見込みの2倍を超えたら、完了範囲・残り・原因を取りまとめへ報告し、同じIDの継続か、機能ごとの分割を決める。失敗や未接続を完了扱いにせず、途中の変更と記録を次のセッションへ引き継ぐ。

## 段とレビュー

| 段 | 作業 | 先行条件 | 新しく接続するもの | レビューの区切り |
|---|---|---|---|---|
| 0 接続試行 | F0 | B0と決定。本番の変更を残さない | 字句診断の保留と先読みの方式 | L1前に成立条件と残り見積もりを記録 |
| I 形式化の先行 | L1・L2a・L2b・L3 | B0と決定 | 書式・型・固定引数・表層検査・交換 | 各作業の読解と、L3末の定義・言明・仮定・01-12の写しのレビュー。既定ビルドがsorryなしで通ることをF1以降の形式化の内側の実装の条件とする |
| II 独立した表示の幅 | W1・W2 | W1はB0、W2はW1。段Iへの依存なし | 幅本体・標準宣言・予算・CLI版表示 | W2で両モード・空白の加法性・同梱物を照合 |
| III 独立したファイル宣言 | A1〜A6 | A1はB0、以後A1→A2→A3、A4〜A6はA2を要する。段Iへの依存なし | 構文と合併後の契約、CLI、package、整形・生成・移行 | A2の契約、A3の入口、A4の構文集計、A5・A6の適用境界を各レビュー。A6後に接続stage |
| IV 独立した回復 | C1・C2 | C1はB0、C2はC1。段I・IIIへの意味上の依存なし | 原因・束縛・型の部分・遅延診断 | C2で抑制する診断と残す診断を対照し、成功入力の規則が同じことを確認 |
| V 書式の処理系と接続 | F1・F2・F3・F4a・F4b・F5 | 段Iのレビュー、W2、F0。F4aはC2も要する | 字句から定数評価・VM・参照評価、RustからLeanの六入口 | F4aの型・診断、F4bの全経路、F5の全比較と独立交換入力をレビュー |
| VI 全体と候補 | G1・Z1 | 各段のレビュー・取り込み・shortの判断を完了 | 改造全体の回帰、0.0.11の実CLI・訳・同梱物・配布 | G1でchange、Z1でreleaseと手動照合。取りまとめが委任範囲の受け入れを記録し、設計者へ報告 |

既定の順はF0→I→II→III→IV→V→VIである。Lean段が止まったらII・III・IVを先に実施し、V・VIへ進まない。独立段の取り込み・必要なshort・レビューを終えたら設計者へ報告して待ち、G1・Z1、0.0.11への版上げは行わない。F0で言語の区切りの変更が必要と判明した場合も、言語の規則を決めずに記録し、影響しない作業だけを進める。実装担当は同時に動かさない。取り込み順が変わればB_WORKと段の開始版B_STAGEを実際の完全IDへ固定し、依存する出力を起動前に再点検する。

### 受け渡す内部の契約

| 出力 | 提供側→利用側 | 固定する形と意味 |
|---|---|---|
| 書式の値 | L1→L2a・L2b・L3・F1・F2・F3・F4a・F4b・F5 | kind/align/sign/alternate/zero/width/precision。幅・精度は省略と明示を区別する。符号化と引数順はD29。元の各spanはRustの構文・診断だけに保持 |
| 内部の整形頭 | L1・L3・F3→F4b・F5 | `%Format.<型名>`、14基本型、valueと七定数、純粋、String。名前付き引数の契約名はvalue/kind/align/sign/alternate/zero/width/precisionで統一 |
| ファイルの元宣言 | A1→A2・A4〜A6 | `Module.file_uses: Option<UsesList>`。元のASTとUTF-8バイトspanを保持し、関数の個別usesへ複写しない |
| 有効な関数の契約 | A2→A3・A5・A6・F5 | 宣言収集の共通入口で、最外側の効果行と効果ごとの元span（個別・ファイル）を返す。既存Schemeの効果は合併済み。NoFail・atomsも合併後から作る。ASTを直接読む消費者とは区別 |
| 回復の原因 | C1→C2・F4a | 診断済み原因ID、型の部分への経路、束縛自身の明示契約。zonk前後で保持し、利用側の期待型を元の値の確定情報にしない。実行用Ty・交換へ出さない |
| 版付きinventory | A5・A6→Pythonの読者 | D33の必須欄・版をRustとPython・README・検証入力で同時に切り替える。古いapply用manifestを黙って受け付けない |

deriveのmodule.fileUsesは、宣言なしをnull、宣言ありを `{text: 元の宣言の文字列, span: {path, start, end}}` とする。importInsertLimitは同じファイルの元UTF-8バイト位置（宣言開始）かnullとし、sourceの範囲内・preambleEnd以上であることを検証する。try-actionsのowner.file_usesも同じtext/spanの形で、スニペットでは既存のoffsetとboundariesを介して元ホストの位置へ対応付ける。owner.effective_effectsは検査できた最外側の正規化済み効果名の文字列配列、未確認ならnullとし、空配列と区別する。一般のFail型を文字列名だけで同一と判定する用途には使わず、移行の承認には既存の型検査・契約確認も要求する。

L1・L2a・L2b・L3は、F2より前の01-12へ新書式の表層の例を ` ```text ` で追加しない。形式化の定義・脱糖の写しは数式または ` ```lean ` で記し、構文解析を伴う例はF2で加える。EXPECTED_FAILURESへ一時登録する案は採らず、既存の仕様例を全件通す。

以下の `src/`・`tests/`・`examples/` は `crates/benitoite/` を基準とする。`01-02`等の略記は `docs/design/` の現行章を指す。各担当はこの計画の共通節、指定D番号とstudy節、列挙した設計書・ソースを読めば実装でき、docs/todoの閲覧を前提にしない。設計書の章名・既存見出しを変えるならコードの印・生成器・全参照も同じ変更で直す。

## 作業 L1: 書式のデータと妥当性

- 読む範囲: D3〜D15・D29、study/format-and-width.md 5〜8、01-12「文字列補間」、07-04「01-12 との対応」。
- 触るファイル: `formal/Benitoite/Surface/Syntax.lean`（独立したFormatSpec定義を分離してよい）、`Surface/CheckPredicates.lean`、01-12・07-04の対応する写し。
- 手順: 有限の指定と省略を表すデータ、構文妥当性・型との適合の命題とBool判定、D29の定数列と固定シグネチャの補助定義を加える。妥当性と判定の同値を示し、全14型、幅・精度の境界、併用禁止を小さい独立例で確認する。既存のInterpPartはこの作業では変えず、後段が用いる補助定義を完成させる。
- 完了の条件: 次段へ渡すデータと述語・判定・符号化が定まり、既定ビルドと写しが一致する。主な定理の前提・結論の変更、公理（Builtins.Assumptionsを含む）の追加が必要なら作業を止め取りまとめへ報告する。
- 依存・見込み: B0、45〜60分。検査はwork L1。

## 作業 L2a: 補間の型付け・脱糖と型保存

- 読む範囲: D15・D29・D38、study/format-and-width.md 2.2・7.2・8.1、01-12の表層と脱糖、07-04の主定理の言明。
- 触るファイル: `formal/Benitoite/Surface/Syntax.lean`・`Typing.lean`・`Desugar.lean`、`Surface/Lemmas/Extensions.lean`・`ExtensionsScoped.lean`・`Typing.lean`・`Scoped.lean`、InterpPartの全再帰読者のビルド維持に必要な最小限の変更（`Check.lean`・`CheckSoundCollections.lean`・`CheckComputeCalls.lean`・`CheckLemmas.lean`等を含む）、01-12・07-04。
- 手順: `formatted ty spec`とexprTypes/converterTypes/Allowed/count、直接の純粋な固定シグネチャとD29の引数を接続する。全式評価→変換→連結と束縛の変数番号のずらしを保ち、型保存・範囲・捕捉・BuilderFree・AtomsInの補題を完成させる。新構成を含む補間は判定器で一時的に拒否し、その分岐が成功しないことにより既存の健全性・計算可能性・有限支持の証明を維持する。この防御の位置・除去箇所・L2bへ渡す補題を記録する。
- 完了の条件: 型判断と脱糖の新構成は独立した小さい例で確かめ、既定ビルドがsorryなしで通る。新構成を拒否するだけの作業にはしない。一時的な拒否は明示した途中状態であり、段Iの完了やF1以降の開始条件には数えない。全再帰読者を追随させられなければ取り込まず、残りを記録して同じIDで継続する。主な定理の前提・結論の変更、公理（Builtins.Assumptionsを含む）の追加が必要なら変更せず停止し、取りまとめへ報告する。
- 依存・仮予算: L1、45〜60分。検査はwork L2a。型付けと脱糖の出力・補題・一時防御をL2bへ渡す。

## 作業 L2b: 表層検査と健全性・計算可能性・有限支持

- 読む範囲: D15・D29・D38、study/format-and-width.md 8.1、L2aの結果と新構成・補題・一時防御、01-12・07-04の検査と主定理。
- 触るファイル: `formal/Benitoite/Surface/Check.lean`・`CheckPredicates.lean`、`CheckSoundCollections.lean`・`CheckComputeCalls.lean`・`CheckLemmas.lean`、有限支持とInterpPartの残る読者、必要なL2aの補助補題、01-12・07-04。
- 手順: L2aの一時的な拒否を、妥当性・型との適合・個数・直接の純粋な頭・文字列加算の条件を検査する判定へ替える。成功の健全性、計算可能性、有限支持を新構成へ接続し、型付けと脱糖の条件と一致させる。全14型の受理と不適合・不正な指定・間接/非純粋な頭の拒否を独立した小さい例で確認する。
- 完了の条件: 新構成を型付け・脱糖・実行可能な表層検査が同じ条件で扱い、L2aの一時防御が残らず、sorryなしで既定ビルドが通る。主定理の言明を弱めず、公理を増やさない。必要と判明した場合は変更せず停止し、変更が必要な言明と代案を取りまとめへ報告する。
- 依存・仮予算: L2a、45〜60分。検査はwork L2b。L2aと同じ担当が続ける場合も別セッション・別work・別結果を保つ。

## 作業 L3: 交換形式と組み込みの宣言照合

- 読む範囲: D15・D29・D30、study/format-and-width.md 2.3・8.3、07-04の交換形式とレビューの節。
- 触るファイル: `formal/Benitoite/Exchange/{Syntax,Convert,Version}.lean`、`Release/BuiltinTable.lean`と組み込み宣言の照合の関連箇所、`formal/tests/test_batch5_exchange.py`と独立交換入力、必要な`formal/lakefile.toml`の既定対象、01-12・07-04。
- 手順: corpus14/sidecar6でformattedと省略を入出力し、型・個数・妥当性・頭の直接性を検査する。旧corpus8〜13/sidecar2〜5の意味を保ち、旧版へ新構成を混ぜた例を拒否する。整形頭の名前と型の照合先を設けるがδの数・幅の算法を証明対象にしない。交換デコーダが共通でも、期待コア・引数列はRustから生成しない。新しい独立検証器の既定入力モードをL3で動かし、Rust入力を照合するモードをF5で追加する。既存の版分岐（test_batch4_exchange.pyのsidecar選択等）も新旧双方へ追随させる。
- 完了の条件: 既定ビルドと独立交換の検査が通り、定義・言明・仮定・写しを取りまとめが独立レビューへ渡せる。Rustの未実装との全比較を成功したとは記録しない。主な定理の前提・結論の変更、公理（Builtins.Assumptionsを含む）の追加が必要なら作業を止め取りまとめへ報告する。
- 依存・見込み: L2b、45〜60分。検査はwork L3。段Iのレビューが通るまでF1以降の形式化の内側の実装を起動しない。

## 作業 W1: 表示の幅と空白の算法

- 読む範囲: D10〜D14・D31、study/format-and-width.md 9・10、01-04「String」、03-01の依存、03-06のString。
- 触るファイル: `Cargo.toml`（クレート）・`Cargo.lock`、`src/base/mod.rs`と新しい幅本体、03-01・03-06。
- 手順: 固定依存を通常の直接依存として加える。C0/DEL/C1/U+2028/2029を境界に文字列の算法を適用し、両モードを共有する。幅と不足空白の個数・必要サイズをcheckedに計算する。U+0020で状態がDEFAULTへ戻る実ソースを再確認し、空文字・先頭結合文字・末尾VS/ZWJ・合字・制御境界に前後の空白を置く小さい独立期待値を作る。
- 完了の条件: VM・Value・Host・Wasmtimeへ依存しないRust本体として呼べ、W(space^n+s+space^m)=n+W(s)+mを両モードの受け入れ例で確かめる。一般の連結の非加法性の対照も残す。新しいライセンス許可名を理由なく増やさない。
- 依存・見込み: B0、30〜45分。Lean段が止まっても進められる。検査はwork W1。

## 作業 W2: 六関数・予算・版表示

- 読む範囲: D11〜D14・D31、study/format-and-width.md 7.3・9.3・10、03-06、06-01「版と対応する形式の問い合わせ」。
- 触るファイル: `src/prelude/stdlib/String.bnt`、`src/builtins/table.rs`・`funcs/string.rs`等の登録と実体、`src/cli/mod.rs`、`tests/runtime_builtins.rs`・`cli_process.rs`、03-06・06-01・00-04・07-04、`docs/reference/benitoite.md`、Skill生成物。
- 手順: 六つの公開署名をD13どおり登録する。論理上限・予算・usize変換を確保前に検査し、動的widthに極端なIntegerが来ても切り詰めて変換しない。0以下・既存幅超過は元内容、空白以外は加えない。JSONに任意欄を追加し、人間向け二行を保つ。新標準宣言のコメントと英語リファレンスを加え、gen_skillで再生成する。06-01にdisplayWidthUnicodeVersionは当該版では常に出し旧版では欠ける任意欄であることを記し、cli_processで確認する。00-04へ「表示の幅」（display width。D12の境界で分けた部分の幅の和、端末の移動量ではない）の行と定める03-06を加える。語と出典はstudy 3・9に従い、07-04へTODO-272の算法が形式化の対象外である行を加える。
- 完了の条件: CLI・標準署名・VM/参照評価の出力と純粋性が一致し、制御文字の意味をカーソル操作と説明しない。独立期待値にUnicode17の絵文字・CJK・ゼロ幅と予算境界を含む。
- 依存・見込み: W1、45〜60分。検査はwork W2、S-Wはその結果を引用する。

## 作業 A1: ファイル宣言の構文と元位置

- 読む範囲: D1・D2・D16・D32・D34・D36、study/file-effects.md 3.1・3.8、01-01の改行、01-02「ファイルの先頭の部分」。
- 触るファイル: `src/syntax/ast.rs`・`parser/decls.rs`・`parser/header.rs`・`parser/types.rs`・`header.rs`、`modules/load.rs`、型検査・package・整形器・inventory等の入口の防御、`diag/codes.rs`、02-10の診断の説明、Moduleを構築するテスト補助、01-02・02-03・00-04、生成Skill。
- 手順: Module.file_usesを加え、メタデータとimportの後の一宣言を読む。parse_usesの入れ子の回復をそのままファイル位置へ流用せず、実改行を末尾とするリスト読取りを設ける。既存の継続規則どおりコンマ後の改行を扱い、通常宣言の後・二度目・空リストをE0261等で回復する。先頭だけの読取りと全文解析を揃える。D36に従い型検査の前にファイル宣言ありを追加元の位置付きの未接続の制限として拒否し、小さい契約で成功させない。構文を直接読む各入口も、未対応なら明示的に拒否し、A4〜A6へ外す箇所を渡す。構文解析自体はModuleを返せるようにして後続の実装とAST検証を可能にする。
- 完了の条件: 個別usesの構文・末尾コンマ・CRLF・コメントとファイル宣言の正負の対照が通り、語の改名を含まない。`package.bnt`のファイルusesを拒否し、本体なし@builtin/@externalの次行のusesも遅い宣言として拒否する。後者は再現を確認してから「関数のusesは同じ物理行」の案内を判断する。型検査と未対応の構文入口が成功せず、宣言なしの入力は従来どおり通る対照を確認する。00-04へ呼び名と適用範囲を加え、構文の変更と生成文法を同時に揃える。
- 依存・見込み: B0、45〜60分。A2が型検査の防御を外すまで新構文の検査成功・実行を許さず、A4〜A6の未対応入口の防御も完成まで保つ。検査はwork A1。

## 作業 A2: 解決・合併・有効な契約

- 読む範囲: D1・D17〜D19・D32・D36、study/file-effects.md 3.2・3.4・3.5・3.7、01-03、01-06、01-07、02-04・02-05。
- 触るファイル: `src/resolve/{mod,walk,checks}.rs`、`typeck/decls.rs`・`effects/declarations.rs`・`external.rs`、`types/mod.rs`の由来の表、関連する入口・公開性の検査、`tests/declarations.rs`・`vm_handlers.rs`・`io_modes.rs`、必要な`src/diag/codes.rs`、01-03・01-06・01-07・02-04・02-05・02-10・07-04、生成Skill。
- 手順: A1の型検査前の防御を外して合併経路へ切り替え、ファイルのスコープで名前と具体型を一度解決し、Module.decls直下のItem::Fnへだけ有効な効果行を作る。元ASTは保持し、全関数のScheme確定とsignature_no_failの前に合併する。リスト内の重複は個別検査、リスト間は解決済み効果と型の同一性で合併する。Fail別名・異なるFail・IO.All展開・変数NoFail・公開性・外部照合を合併後に検査する。
- 完了の条件: main/@test/@builtinを例外にせず、trait/implement/ラムダ/関数型、エフェクトの操作の宣言、定数、ハンドラの節、局所の関数値には足さない。操作と定数も負の対照に含める。未束縛名を関数数だけ重複報告せず、追加元のspanが診断まで残る。import先の宣言を呼び出し元ファイルへ再適用しない。型検査前の一時防御が残らず、ファイルusesだけで追加したFailがNoFailとハンドラの既存規則へ反映されることをvm_handlers・io_modesで確認する。形式化の内外を07-04に記す。
- 依存・見込み: A1、60分。検査はwork A2。

## 作業 A3: 入口の許可・検査報告・縮小警告

- 読む範囲: D18・D20・D24・D32、study/file-effects.md 3.3・3.6、06-01の上限照合とmain報告、06-04、06-06。
- 触るファイル: `src/cli/effect_limit.rs`・`cli/tools/test_runner/check_report.rs`とmainの報告経路、`typeck/effects/`のW0501、`tests/checked_args.rs`・`test_command.rs`・`cli_process.rs`、必要な`src/diag/codes.rs`、02-10、06-01・06-04・06-06、Skillの手書き文書と生成物、英語リファレンス。
- 手順: 合併済みSchemeから許可・報告の上限を得て、追加したConsole.Write/LogにもE0512の補助位置を付ける。本体が純粋でも宣言の追加分を許可対象にする。ファイルIO.AllのW0501は関数ごとに出し、共通宣言の自動編集を出さない。個別usesの修正は追加分を考慮する。Skillでは06-01の受け手の条件全体（完全な単一のJSON、理解するschemaVersionとkind、status:ok、complete:true、終了状態0）を含むD24の成功条件・宣言上限・不明時の扱いを、版を固定した処理系の報告仕様への参照とともに説明する。
- 完了の条件: mainと@testの型・許可・JSONが同じ追加後の上限を示す。通常checkの標準出力は空のままである。mainのhandleでは追加済みの契約を取り消せない例と、純粋な関数を別ファイルへ置く例を示す。doc例は外側のファイル宣言を引き継がない。
- 依存・見込み: A2、45〜60分。検査はwork A3。

## 作業 A4: packageの構文集計

- 読む範囲: D25・D26、study/file-effects.md 3.5のpackage節、06-09のエフェクト報告。
- 触るファイル: `src/cli/tools/package/effects.rs`、`tests/package_command.rs`、06-09、`docs/reference/`のpackage説明があれば当該箇所。
- 手順: 外部公開Item::Fnの有無でファイル追加分を一度合併し、個別と共通の効果名を同じ識別器へ通す。裸Log/Benitoite.Log・隠す名前・import別名を点検する。IO.Allを展開せず、traitや入れ子の型に追加しない。記録とupdateの増減を揃え、A1のpackage入口の未対応の防御をこの接続と同時に外す。
- 完了の条件: ファイル宣言だけを変えたときの増減、複数公開関数の重複、public(package)のみ・traitのみ・非公開のみの除外、型の誤りがある依存、構文の誤りなら書かない対照が通る。従来の裸Logも記録が変わり得ると案内する。
- 依存・見込み: A2、30〜45分。検査はwork A4。

## 作業 A5: deriveの有効契約とimport挿入境界

- 読む範囲: D18・D32・D33・D39、study/file-effects.md 3.2・3.8、03-06の生成支援、`tools/derive/README.md`のMarkers・生成記録・自己検査。
- 触るファイル: `examples/derive_inventory/{mod,schema}.rs`、`tools/derive/derive.py`・`test_derive.py`・READMEと関係する検証入力、`tools/derive/examples/derive.generated.json`・`People.bnt`・`Address.bnt`、03-06・07-04。
- 手順: inventory3と必須のfileUses/importInsertLimitを出し、解決済みの有効な型からProperty等の純粋さを検査する。preambleEndはメタデータ・docの末尾のまま保つ。importは既存importの後、ファイルusesの前だけに置く。既存の管理領域がusesの後ならその領域へimportを足さず、安全な新しい位置を選ぶか理由付きで拒否する。D33の生成器版と旧記録のpreview/check/applyの条件を同時に切り替え、A1のderive入口の防御を外す。同梱三例をD39の新preview→確認済みハッシュでapply→checkで再生成し、旧版は専用の拒否/再確認の対照に分ける。記録や管理領域のハッシュを手で書き換えない。
- 完了の条件: LF/CRLF・コメント・既存管理領域の前後・importなしを対照にする。生成トップレベル関数は追加後の型で拒否され得ることを示す。旧manifestの無確認の適用を拒否し、旧記録の本文の保護・新preview→確認済みhashでapply→check→再適用を通す。承認済みmanifestの検証自体を緩めない。
- 依存・見込み: A2、45〜60分。検査はwork A5。例のビルドはこの道具を検証するために局所で必要であり、changeの全examplesと目的を分ける。

## 作業 A6: 整形器・try-actions・標準ソースの規約

- 読む範囲: D16・D23・D32・D33、study/file-effects.md 3.6・3.8、06-01のfmt、06-03、06-06。
- 触るファイル: `src/cli/tools/formatter/roles/walk.rs`と関連する役割・印字、`examples/try_actions_inventory.rs`、`tools/try-actions-migrate/{migrate.py,test_migrate.py,README.md}`、標準ソースを解析する既存lib検査、`tests/fmt_command.rs`、06-03・06-06・07-04、生成Skill。
- 手順: ファイル宣言を元ASTから走査し、位置・コメント・効果順・冪等性を保つ。inventory2に個別uses・file_uses・effective_effectsを分けて渡し、manifest2で旧版を拒否する。非トップレベルのownerへ効果を追加せず、解析断片や契約不明では上限をnullとして自動承認しない。標準ソースを読む既存の検査へfile_uses不在の確認を加える。A1の整形器とtry-actions入口の未対応の防御を各接続と同時に外し、未接続の入口に残る防御がないことを一覧で照合する。
- 完了の条件: 型の誤りがある入力のfmtも新宣言を保持する。共通usesのspanが一関数への編集範囲にならない。生成Skillの標準署名は個別契約を欠かず、利用者向けの構文へ@builtin除外等の例外を加えない。
- 依存・見込み: A2、45〜60分。検査はwork A6、接続stage S-A。

## 作業 C1: 診断済み原因と束縛の由来

- 読む範囲: D21・D22・D34、study/file-effects.md 5.1・5.3・5.4、02-04「位置の式の事前展開」、02-05「誤りの報告と検査の継続」。
- 触るファイル: `src/typeck/{infer,context,generate,solve}.rs`・`solve/provenance.rs`、必要な`calls.rs`、`pipeline/source_location.rs`の原因の受け渡し、02-04・02-05。
- 手順: 開始版から新規にビルドしたCLIでE0467とE0403の二経路を再現する。既存Provenanceへ原因IDと部分の経路を加え、Declared優先の前からbind右辺→束縛の関係を残す。利用側の期待型と束縛自身の明示契約を分け、zonk後も前者を元の値の根拠にしない。
- 完了の条件: `bind f <- error`のfに後からIntegerを要求した後のOptionパターンの余分なE0401を抑え、同じ関数・別関数の独立したInteger/String誤りを残す。`bind f: Integer <- error`と、利用側の`bind n: Integer <- f`のn自身の明示契約の後の不一致も残す。errorは説明用記号であり、実際の入力には既存の誤り式を使う。
- 依存・見込み: B0、45〜60分。検査はwork C1。

## 作業 C2: 複合型・正常な結果型・後検査

- 読む範囲: D21・D22・D34、study/file-effects.md 5.3の条件4〜7と受け入れ表、02-05、07-04の推論の対象外。
- 触るファイル: `src/typeck/solve/provenance.rs`・`solve.rs`・`calls.rs`・`patterns.rs`と後検査、`tests/declarations.rs`・`golden.rs`が読む回復の入力、02-04・02-05・07-04。
- 手順: List/レコード/関数/失敗型の部分への原因の追跡を接続する。List[Error]/List[Integer]の要素とList[Error]/Integerの外側を分け、正常なidIntの結果型IntegerをStringへ使う誤りを残す。型クラス・演算子・網羅性等は個別に依存を判断し、不明なものは独立した診断を残す。
- 完了の条件: 全体や成分単位の一律抑制がなく、原因修正後は通常の検査が全使用に働く。成功入力の型・効果・実行可否・交換形式を変えず、失敗入力に根の診断が必ず残る。抑制の限界も設計書へ正確に反映する。
- 依存・見込み: C1、45〜60分。検査はwork C2、S-Cはその結果を引用する。

## 作業 F0: 字句・先読みの短い接続試行

- 読む範囲: D3・D28、study/format-and-width.md 4.1・4.2、reviews/RS1-response.mdのX1・X2、01-01・01-02・02-03。
- 触るファイル: 当該作業の記録と`work/m011/scratch/`だけ。本番と同じ初期状態をscratchへ複写し、必要な最小の試行用差分はその中だけで作る。差分はscratchにパッチとして保存し、作業ツリーのsrcはF0開始時と同一のまま終える。未完成の本番変更を取り込まない。
- 手順: 既存のビルド済みCLIの由来を確かめ、足りなければ局所ビルドする。`when + "${n:>3}"`と旧式の本物のwhen区切り、default、return_arrow、入れ子、短いラムダ、CRLF・改行の分類を小さい正負の組で調べる。新書式の現行拒否を不具合の再現とは混同しない。保留診断と補間の入れ子ごとの状態の隔離を、式側の誤った数・不正Unicode・個数制限も含め試す。
- 完了の条件: 再現した経路・再現しなかった経路・未確認を区別し、F1/F2が使う保留列と入れ子の状態の受け渡し、テストの最小対照、残り時間を記録する。方式の不成立なら取りまとめへ代案と影響を報告し、コロンを別の記号へ無断変更しない。
- 依存・見込み: B0、30〜45分。L1の前に行う。検査はwork F0。本番を変更しない試行なのでLean先行の実装には当たらない。F1以降の形式化の内側の実装は段Iのレビューを待つ。成立しない言語の規則の選択は決めず、取りまとめへ記録と代案を渡す。

## 作業 F1: 保留診断と補間の入れ子

- 読む範囲: D3・D28・D34、F0の結果、study/format-and-width.md 4.1・4.2、02-03。
- 触るファイル: `src/syntax/lexer.rs`・`lexer/string.rs`・`token.rs`・`newline.rs`・`lambda_bounds.rs`・`parser/{mod,foreign,exprs,interp}.rs`、`modules/load.rs`等のlex/parseの全読者、02-03。
- 手順: 補間IDと範囲を持つ保留診断を渡し、従来のlex→resolve_newlines→parseの呼び出しで失われないようにする。既存の呼び出しシグネチャを変えるならrgで全読者を同じ変更に追随させる。StrStart/Mid/Endの入れ子ごとに改行・ラムダの状態を隔離し、外側の旧構文の先読みは対応する文字列全体を飛ばして外側の本物の区切りを探索する。
- 完了の条件: 書式の確定がなければ保留した診断をすべて戻し、従来の誤りを黙って捨てない。書式による#・^・<-等が外側の構文と誤認されず、正しい旧式内部のコロンも保つ。入力を反復解析して二乗にする実装を加えない。02-03では「補間の入れ子」と既存の字句解析器の呼び方を使い、用語集のコア計算や呼び出しの「枠」と混同する名称を導入しない。
- 依存・見込み: F0と段Iの既定ビルド・レビュー、45〜60分。検査はwork F1。式の有効な書式の提供はF2〜F4bで閉じる。

## 作業 F2: 書式AST・解析・診断と整形の保持

- 読む範囲: D3〜D8・D28・D34、study/format-and-width.md 5.1・7.1、01-01・01-02・02-03、06-03。
- 触るファイル: `src/syntax/ast.rs`・`parser/interp.rs`と新書式解析、`diag/codes.rs`、02-10の診断の説明、`cli/tools/formatter/`、ASTの生成・走査の全読者、`tests/fmt_command.rs`、01-01・01-02・02-03・00-04・06-03、生成Skill。
- 手順: InterpSegmentへ任意の書式と部分spanを加える。式を一度読み終えてから元ソースの範囲を解析し、数字列はホスト整数への変換前に上限を判定する。E0262で不正種類・空白・空・.2のみ・-・併用禁止を示す。fmtは書式の内容を通常の演算子や数の空白規則で変形せず保持する。書式ありの型検査はF4a、脱糖・実行はF4bで接続するものとして、旧経路へ無言で落とさない防御を置く。
- 完了の条件: 名前付き引数・レコード・パターン・block内注釈・短いラムダ・多重補間・三重引用符の元位置が保たれ、rawは本文のままである。書式なしのASTと出力を保ち、未接続の新構成を実行させない。書式の文法入力を変えた変更でgen_skillを再生成する。01-12の新書式の表層の例はこの作業で追加し、spec_examplesで確かめる。
- 依存・見込み: F1、45〜60分。F4bまで段Vは未完了であり、この作業だけで機能完成としない。検査はwork F2。

## 作業 F3: 型別の数の整形と内部組み込み

- 読む範囲: D4〜D14・D29、study/format-and-width.md 5・6・7.2・7.3、01-04・03-06、L3のシグネチャ。
- 触るファイル: `src/base/`の新しい数の整形本体・`decimal.rs`・`prim/`、`builtins/table.rs`・`funcs/`と登録、`builtin!` の固定引数を型付きタプルで受ける形式、`tests/runtime_builtins.rs`、03-06・02-06等の脱糖先の契約。
- 手順: 固定引数の14頭を登録し、Float32はbinary32の値を直接丸め、Floatの最短表記を再丸めしない。Decimalは係数とscaleから数字列を作り、有界Decimalを丸め直して値域超過させない。整数最小値の大きさは符号なしで扱う。符号・基数接頭辞→ゼロ埋め→共有の幅算法と寄せを適用する。検査済みspecを受ける本体と、取り出し・予算・確保を行うbuiltinsを分ける。
- 完了の条件: study5.2の全型、2.5/3.5と負値、Float32との差、Decimal最大値の.00、零と非有限値、-42の#08x等を独立期待値で確かめる。生の書式文字列を実行時に再解析しない。不正な内部引数は処理系の不変条件の違反として扱い、利用者の可変書式APIにしない。
- 依存・見込み: 段I・W2（F1/F2とは意味上は独立）、45〜60分。検査はwork F3。

## 作業 F4a: 書式の型集合・適合と回復の接続

- 読む範囲: D3〜D15・D21・D22・D29・D34・D38、study/format-and-width.md 7・8、L2bの確定規則、01-06・01-12・02-05・02-10、C2の原因の受け渡し。
- 触るファイル: `src/types/mod.rs`のTySetと型情報、`typeck/generate.rs`・`solve.rs`・`traits/mod.rs`と必要な制約の読者、`src/diag/codes.rs`、`tests/declarations.rs`・`golden.rs`、01-06・02-05・02-10、生成Skill。
- 手順: 書式の種類から閉じた型集合を選び、具体化後に適合を検査し、E0468へ値と書式の位置を渡す。C2の由来から生じた不適合だけを抑え、独立した不一致を残す。全14型とフラグの表、未確定型・書式なしE0422を照合する。F2の未接続の防御は、型検査の局所確認を可能にする場合も型検査後・脱糖前に残し、公開のcheck/run/定数経路を成功・実行可能にしない。
- 完了の条件: 内部の型検査で型集合・適合・由来の正負を確認し、型情報とspanがF4bへ渡る。成功入力の書式なしの型と効果を保ち、新書式の未接続の防御が全入口で残る。診断の登録・02-10・型の説明・生成物を揃える。書式付き機能全体の完成とは扱わない。
- 依存・仮予算: F2・C2と段Iのレビュー、45〜60分。検査はwork F4a。F4bへ型情報・診断の条件・防御の位置を渡す。

## 作業 F4b: 書式の脱糖・定数評価・実行の接続

- 読む範囲: D3〜D15・D29・D38、study/format-and-width.md 7.2・7.3・8、L2bの型付けと脱糖、F4aの型情報・防御の記録、01-12・02-05・02-06。
- 触るファイル: `src/typeck/consts.rs`、`ir/desugar/exprs.rs`、VM/参照評価の組み込み接続の必要箇所、必要な型情報の読者、`tests/declarations.rs`・`runtime_builtins.rs`・`golden.rs`、02-05・02-06・英語リファレンス・Skillの手書き文書と生成物。
- 手順: F4aの適合済みの型から全式を左から各一度評価し、型別変換と連結を行う。D29の固定定数を作り、書式ありのStringも整形を呼ぶ。定数評価もF3と同じ本体を使い、128バイトの見込みを流用せずサイズ算定・予算検査を確保前に行う。全経路がつながってからF2/F4aの防御を外す。
- 完了の条件: 効果のある複数の式で全式評価→変換→連結の順序を確認し、VM/参照評価/定数が独立した同じ期待値へ一致する。書式なしの変換・型推論・定数・評価順を保つ。未接続の防御が残らず、新書式を旧経路へ落とさない。保持方式を変えた場合は次作業前に必要なheap検査も終える。
- 依存・仮予算: F4a・F3、45〜60分。検査はwork F4bと局所heap/stress/doc。安全点を越える値の保持方式を変えたらcheck-heapもこの作業末に追加する。

## 作業 F5: RustとLeanの全接続

- 読む範囲: D15・D30・D32・D35、study/format-and-width.md 2.3・8.3、study/file-effects.md 3.7、07-04。
- 触るファイル: `tests/desugar_export.rs`・`desugar_export/{exchange,builtins,named}.rs`とmanifest、`formal/tests/`の独立入力・照合、必要な`scripts/check-formal.sh`の入口、07-04。
- 手順: formattedを表層交換に残し、式・変換頭・指定・省略をRustから出す。Lean/Rustが別々に作った定数引数とコアを比べる。全受理型・不適合・上限外・空書式の構文拒否に相当する不正交換・個数不一致・非純粋/間接頭・空断片・連続補間を独立入力に含める。ファイルusesと個別usesの同等な成功入力で、合併後の宣言・atoms・NoFail・本体が一致することをE2にも通す。
- 完了の条件: 新構成が対象外へ落ちた件数を確認し、六入口、独立交換入力、組み込み宣言表、名前付きプログラム、routing/exchange manifestの件数が揃う。check-formal全体が通る。文字列の出力算法の検査をコア形の比較で代用しない。
- 依存・見込み: F4b・A6・C2、45〜60分。検査はwork F5、接続stage S-F、全比較K1。数と幅のランタイム本体はこの作業で改造しない。

## 作業 G1: 改造全体の回帰と証拠の集約

- 読む範囲: D35、07-03の四水準・引用条件、各作業のresultsとレビュー。
- 触るファイル: 改造の`results.md`と`g1/results.md`、原因が判明した不足の関連ファイルだけ。修正が機能単位で大きければ別作業へ分け、結果を取り込んでから戻る。
- 手順: 全作業のwork・stage・short・レビューを照合し、未解決の不具合を完了扱いにしない。性能の退行の疑いの判断を候補準備前に終える。changeをB0から一度実行する。必要な修正後は古くなった検査だけをやり直す。
- 完了の条件: 既定/heap全targets・stress・doc・二構成lint・長い対象・生成物・規約・依存・道具の検査をそろえ、全比較の証拠の担当を確認する。D42によりK1は参考記録に限定し、唯一の受け入れ証拠となるK2はZ1に残す。版・訳・CHANGELOGはまだ上げない。
- 依存・見込み: 段I〜Vの受け入れ、実装・記録30〜45分、長い検査の時間は下表。検査はwork G1とchange。

## 作業 Z1: 0.0.11の候補と最後の照合

- 読む範囲: D27・D31・D35・D37、git-workflowの「ソースだけのリリース」、05系のソース配布・第三者表示、06-01・06-06。
- 触るファイル: `crates/benitoite/Cargo.toml`・`Cargo.lock`、`CHANGELOG.md`、`docs/reference/`、`docs/ja/reference/`・`docs/ja/skill/`、同梱Skill・生成入力と生成物、版を表示する現役README等、配布用第三者表示、`src/modules/package.rs`・`modules/text.rs`・`modules/tests.rs`、`tests/package_command.rs`、06-09、`z1/results.md`と改造の`results.md`。
- 手順: 全体で一度だけ0.0.11へ上げ、機能・互換性・移行の注意をCHANGELOGへ記す。D37の0.0.11のsummary/helpをBREAKING_CHANGESと診断文へ登録し、06-09の版別の案内と照合する。0.0.10以前のlanguage宣言からの案内と0.0.11で案内不要になる境界、package updateの移行文を確認する。性能の増減を書かない。英語の現行文書と手書きSkillを揃えてから日本語訳と版を更新し、生成参照はgen_skillで作り直す。最小実行版の参照・過去版・archiveの本文を一括置換しない。第三者表示は `scripts/release/licenses.sh <rustc-vVで固定したhost> <候補の一時出力>` で作り直し、bundled-licensesの入力と対応付ける（06-01と05-01の正式な照合に従う）。通常のソース配布手順と同梱物を照合する。
- 完了の条件: 実候補のCLIの版/JSON/二行契約、check報告の上限、許可不足の位置、新構文の成功・失敗、fmt冪等性、packageの増減、Skill抽出・生成物・訳・移行案内が一致する。release_stack成功10件と最終の関係状態のcheck-formalを含む証拠を照合し、取りまとめが委任範囲の受け入れを記録する。終了0だけで受け入れ完了としない。
- 依存・見込み: G1と最後のshortの判断、実装・文書45〜60分。検査はwork Z1・release・全比較K2。訳の量が60分を越えるなら同じZ1の継続として記録し、版上げを別作業で重ねない。

git-workflowの手順のうち、docs/todoの今回の範囲の整理と改造文書の保管は取りまとめが受け入れ後に担当する（実装担当は操作しない）。TODO-206はファイル宣言の部分だけを完了とし、ログ出力先等を残す。控え・履歴の集約・集約メッセージの承認・タグ・タグ後のアーカイブ・pushは設計者の指示を待つ。今回は候補のソース内容と配布手順を照合し、リリース済みと表示しない。集約後はコミット依存のbuild情報とSkill producerの証拠を再照合する必要がある。

## Z1 の検査の続行（2026-10-24）

work Z1 の初回は、ハッシュの共通の成功 fixture に旧版宣言が残り、lib の三件が E0908 で失敗した。fixture の版と、独立に求めた固定ハッシュを更新して同じ work を再実行した。次は golden の hash-mismatch の期待値に旧ハッシュが残っていたため、この期待値だけを独立な新ハッシュへそろえた。成功済みの fmt・lint_default・lib_default と build_info（通常対象）・cli_process・desugar_export は同じ入力なので繰り返さず、未完了の部分を次で実行する。各指定は先に --dry-run を付ける。

```sh
scripts/check.sh --level work --base e0ed5eb2888349dbb0d251843627c527d7ffc0b0 \
  --only tests_related,source_rules,skill_generated,spec_tally,licenses \
  --test golden --test package_command --test reference_examples \
  --test skill_docs --test skill_examples --test spec_examples \
  --test stdlib_doc_examples --test test_command
```

続行では golden が成功し、package_command の設定ファイルの版を含む固定ハッシュに更新漏れが見つかった。同じ独立計算で旧値と新値を確認し、この期待値だけを更新した。統合テストのソース変更に対する fmt・lint_default と、package_command および未実行の対象だけを再開する。成功済みの lib・golden・CLI・脱糖交換は入力が変わらないので繰り返さない。

```sh
scripts/check.sh --level work --base e0ed5eb2888349dbb0d251843627c527d7ffc0b0 \
  --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,licenses \
  --test package_command --test reference_examples --test skill_docs \
  --test skill_examples --test spec_examples --test stdlib_doc_examples --test test_command
```

## 検査の割り当て

### 基準・実行と保存の共通条件

文書のリンク・見出し・採番・編集範囲はcheck.shの対象ではない。source_rulesはplaceholderのallowとunsafeの許可範囲の二つだけを調べる。P1で実行した指定と結果はpreflight.mdに過去の記録として残す。P2はgit操作禁止のためcheck.sh（dry-runもgitを読む）は起動せず、読み取り専用のPythonとrgで対象6文書の相対リンク・アンカー・フェンス・末尾空白・D番号と作業ID・依存・予算の和、開始時に保存した本文との差を確認し、RP1-response.mdへ記録する。Rustの全libや実装後の検査を先取りしない。

F0・G1の文書だけのworkは自動分類で実行対象なしとなる。文書については読み取り専用のPythonで同じ文書確認を行い、各results.mdへコマンド・対象・結果を残す。F0はscratchと本番の開始時本文もバイト単位で照合する。実装修正を含めるG1は読者を指定したRustのworkに切り替える。

取りまとめは起動時にB_WORKを完全IDで固定して渡す。以下のコマンドのB_WORK/B_STAGE/B_AFTERは、その完全IDの引数を表す記号であり、未解決の記号をシェルへ渡さない。B_STAGEは当該段の最初の作業前、B_AFTERは当該取り込み後の完全IDである。実行前に同じ基準・指定へ `--dry-run` を加え、選択と理由を確認して日本語で知らせる。`check-formal.sh`等の独立コマンドにはdry-runがないため、入力と担当を照合する。

workのRust既定集合は入口へ任せ、lib全件・関連統合・fmt・clippyを直接重ねない。共有入力の読者が増えれば全読者の統合ターゲットを補う。`--test`省略は全統合であり、なしと誤読しない。文書・Python・LeanだけへRustの全libを追加しない。テスト変更はtest-auditの作成時の関門を通し、実装の写しの期待値を避ける。

生成を要する各作業では `cargo run -p benitoite --example gen_skill` を編集後に一度行い、workの `skill_generated` が生成元と生成物を照合する。文法・標準ソース・診断の表のいずれを変えた場合も同じ変更で行う。英語の現行参照は対応する機能と同時、日本語訳はZ1で揃える。

| 水準・作業 | 基準・対象 | 契約・入力の読者 | コマンド・構成・対象 | 担当 | 見込み時間 | 保存先 |
|---|---|---|---|---|---|---|
| work L1・L2a・L2b | B_WORK、Leanと写し | 形式化定義・既定の定理・01-12の例と集計 | 各 `scripts/check.sh --level work --base B_WORK`。formal_build・spec_examples・spec_tallyを自動選択し、既定lake buildのsorry拒否を含む。Rustの全libは選ばない | 各担当 | 各1〜5分＋仕様例・集計の時間は不明、初回不明 | `l1/results.md`・`l2a/results.md`・`l2b/results.md` |
| work L3 | B_WORK | 上記と独立交換の読者 | `scripts/check.sh --level work --base B_WORK`。formal_build・spec_examples・spec_tallyを自動選択。局所に `python3 -B formal/tests/test_batch5_exchange.py`（L3で追加）と必要なLean実行器をビルドして実行 | L3担当 | 3〜10分＋仕様例・集計の時間は不明、初回不明 | `l3/results.md` |
| work W1 | B_WORK | 幅本体と通常依存 | `scripts/check.sh --level work --base B_WORK --test runtime_builtins` | W1担当 | 5〜12分 | `w1/results.md` |
| work W2 | B_WORK | 標準関数・CLI・例 | `scripts/check.sh --level work --base B_WORK --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden`。一時文字列なしの確保のためheapの文字列片の入口を拡張するので、共通入口の読者goldenと自動選択のheap_checksも含める。doc_defaultも自動workに含まれるので、後の局所特殊構成はheap_local,stress_localだけを実行し重複させない | W2担当 | 5〜15分（heap_checksは10分以内） | `w2/results.md` |
| work A1 | B_WORK | Moduleの全AST読者と文法 | `scripts/check.sh --level work --base B_WORK`。Moduleの共有構造と全構築箇所を変えるため統合を限定しない。局所に `cargo build -p benitoite --examples` で道具を含む全AST読者をビルド | A1担当 | 8〜20分、examplesの初回不明 | `a1/results.md` |
| work A2 | B_WORK | 型契約・本体・外部・公開性 | `scripts/check.sh --level work --base B_WORK --test declarations --test checked_args --test golden --test property_library --test external_signals --test vm_handlers --test io_modes` | A2担当 | 5〜15分 | `a2/results.md` |
| work A3 | B_WORK | main/testの上限・報告・警告・Skill（手書きSkillの例の変更を含む） | `scripts/check.sh --level work --base B_WORK --test declarations --test checked_args --test test_command --test cli_process --test reference_examples --test skill_docs --test skill_examples` | A3担当 | 5〜15分 | `a3/results.md` |
| work A4 | B_WORK | 記録・updateの構文集計 | `scripts/check.sh --level work --base B_WORK --test package_command` | A4担当 | 5〜12分 | `a4/results.md` |
| work A5 | B_WORK | Rust inventoryとPython・生成コード | `scripts/check.sh --level work --base B_WORK --test declarations --test property_library`。局所に `cargo build -p benitoite --bin benitoite --example derive_inventory`、`python3 -B tools/derive/test_derive.py` | A5担当 | 10〜25分、自己検査の初回は不明 | `a5/results.md` |
| work A6 | B_WORK | fmt・移行・標準署名 | `scripts/check.sh --level work --base B_WORK --test fmt_command --test skill_docs --test skill_examples`。migrate_selftestsは自動選択され、source-migrateとtry-actions自己検査を含む | A6担当 | 8〜20分 | `a6/results.md` |
| work C1・C2 | B_WORK | 回復と成功入力の規則 | 各 `scripts/check.sh --level work --base B_WORK --test declarations --test checked_args --test golden` | 各担当 | 各5〜15分 | `c1/results.md`・`c2/results.md` |
| work F0 | B_WORK | 読み取り試行と記録 | `scripts/check.sh --level work --base B_WORK`。本番へ変更を残さず、文書は対象なし。読み取りのPythonで文書と本番の開始時本文を確認し、試した局所コマンドをresultsへ保存 | F0担当 | 文書確認5〜10分、局所ビルド不明 | `f0/results.md` |
| work F1・F2 | B_WORK | lex/parse共有入力とその全読者 | 各 `scripts/check.sh --level work --base B_WORK`。広いASTと入口の変更なので全統合を選ぶ。F2は局所に `cargo build -p benitoite --examples` も実行。F1で再帰の枠を変えた場合は局所にrelease_stackも追加 | 各担当 | 各8〜20分、F2のexamples初回不明、stackは約5分＋ビルド | `f1/results.md`・`f2/results.md` |
| work F3 | B_WORK | 整形本体・組み込み | `scripts/check.sh --level work --base B_WORK --test runtime_builtins --test declarations --test desugar_export`。内部頭の分類を受け取る交換の読者も確認する | F3担当 | 5〜15分 | `f3/results.md` |
| work F3R | `8194162aedca62200a229b57a4e5cf64b3bbd902` | RV-F13の再現・修正、構文・診断・整形と書式化本体の読者 | `scripts/check.sh --level work --base 8194162aedca62200a229b57a4e5cf64b3bbd902`。`--test`を省き全統合ターゲットを選ぶ。局所の再現と文書確認はf3r/results.mdに記録 | F3R担当 | 8〜20分 | `f3r/results.md` |
| work F4a | B_WORK | 型集合・診断・回復・AST読者 | `scripts/check.sh --level work --base B_WORK --test declarations --test golden`。局所に `cargo build -p benitoite --examples` | F4a担当 | 5〜15分、examplesの初回不明 | `f4a/results.md` |
| work F4b | B_WORK | 定数・VM/参照評価・例・AST読者 | `scripts/check.sh --level work --base B_WORK --test declarations --test runtime_builtins --test golden --test spec_examples --test reference_examples --test skill_docs --test fmt_command --test skill_examples`。一時防御を外したfmtの検証と、追加した手書きSkillの実行例も確認する。局所に `cargo build -p benitoite --examples` と下のheap/stress/doc | F4b担当 | 8〜20分＋局所特殊構成、examplesの初回不明 | `f4b/results.md` |
| work F5 | B_WORK | 交換・宣言表・全定義 | `scripts/check.sh --level work --base B_WORK --test desugar_export --test coverage_export`。独立全比較K1は別行 | F5担当 | 5〜15分 | `f5/results.md` |
| work F5R | `7fdc02eb40c33dade9a39b4d8bff7ef7f7a4ede5` | RV-F4の残る指摘、回復・定数評価・交換・手書きSkill・Leanコメント | `scripts/check.sh --level work --base 7fdc02eb40c33dade9a39b4d8bff7ef7f7a4ede5 --test declarations --test runtime_builtins --test golden --test desugar_export --test skill_docs --test skill_examples --test spec_examples`。Leanのコメント変更により自動選択する既定ビルドを含める。局所に回復表の修正前後と、書き出したF5の入力を六入口へ渡す `python3 -B formal/tests/test_batch5_exchange.py --rust-dir target/formal-batch5` を実行 | F5R担当 | work 5〜15分、局所2〜5分 | `f5r/results.md` |
| work G1 | `baca0076e5f08abace9cc22136ed2f690f208684` | 記録・文書、RV-F5 L1〜L4のPython報告と全比較の入口、changeで見つけたtry-actions inventoryの列挙型match | 最初の `scripts/check.sh --level work --base baca0076e5f08abace9cc22136ed2f690f208684` はformal_buildのみで成功。その後のexampleのlint修正には `scripts/check.sh --level work --base baca0076e5f08abace9cc22136ed2f690f208684 --test declarations` を使い、型を読む側の契約も確認する。局所に `python3 -B formal/tests/test_batch5_exchange.py --rust-dir target/formal-batch5 --report target/g1/batch5-exchange-results.json`（独立入力の単体テストと既存のF5出力の六入口比較）、`bash -n scripts/check-formal.sh`。exampleの全構成lintとtry-actions自己検査は下記changeの未完了分で確認する。読み取りのPythonによる文書確認を結果へ保存 | G1担当 | 文書確認5〜10分、Rustのwork 5〜15分、局所検査は1分以内の見込み | `g1/results.md` |
| work Z1 | B_WORK | 版・生成物・翻訳・同梱物 | `scripts/check.sh --level work --base B_WORK --test build_info --test cli_process --test reference_examples --test skill_docs --test skill_examples --test stdlib_doc_examples --test package_command --test golden --test spec_examples --test test_command --test desugar_export`。Z1で互換性境界を登録するため現役の成功入力のlanguage宣言と診断期待値も更新し、共有入力の読者golden・spec_examples・test_command・desugar_exportを追加する。ビルド情報の長い対象は版とCargo入力が変わるため引用せず、`cargo test -p benitoite --test build_info -- --ignored`を実候補で実行 | Z1担当 | 8〜20分、長い対象追加は不明 | `z1/results.md` |
| S-W（引用） | IIのW2後 | 六関数とCLI・両実行器 | W2のworkのruntime_builtins・cli_processを引用。同じ接続・入力・構成を既に検査し、W2後に関係変更がないためstageを再実行しない。引用条件の全欄を保存 | 取りまとめ | 追加実行0、引用照合5〜10分 | `results.md` |
| stage S-A | IIIのB_STAGE→A6後 | 契約・入口・package・整形・生成 | `scripts/check.sh --level stage --base B_STAGE --only tests_related --test checked_args --test test_command --test package_command --test fmt_command --test property_library`。A5の自己検査の成功も照合 | 取りまとめ | 3〜12分 | `results.md` |
| S-C（引用） | IVのC2後 | 原因と複合型・後検査 | C2のworkのdeclarations・goldenを引用。同じ接続・入力・構成を既に検査し、C2後に関係変更がないためstageを再実行しない。引用条件の全欄を保存 | 取りまとめ | 追加実行0、引用照合5〜10分 | `results.md` |
| stage S-F（条件付き） | VのF5後 | 書式・幅・回復・定数・交換 | F5がsrcを変えた場合だけ `scripts/check.sh --level stage --base B_STAGE --only tests_related --test runtime_builtins --test declarations --test golden --test desugar_export`。変えなければ入力・生成物・構成の一致も確かめ、F4bのworkとF5のdesugar_exportを引用する。src以外の関係入力が変わった場合も古くなった対象だけ再実行 | 取りまとめ | 実行時3〜12分、引用時は照合5〜10分 | `results.md` |
| change | B0→G1、全段統合後 | 改造全体と所定構成 | `scripts/check.sh --level change --base a9c4132e6451904698cf344db1794c4d03affcd6` | 取りまとめ | 45〜90分の仮予算、実時間は不明 | `g1/results.md`・`results.md` |
| change G1の続行 | B0、初回lint_heap停止後 | exampleのlint修正と未実施分 | `scripts/check.sh --level change --base a9c4132e6451904698cf344db1794c4d03affcd6 --only lint_heap,test_default_all,test_heap_all,test_stress,doc_default,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests,licenses,long_only,heap_checks,formal_build`。fmtとlint_defaultは修正後のworkで成功したため重ねない。A5以後に共有の解析器等が変わったため、`cargo build -p benitoite --bin benitoite --example derive_inventory` と `python3 -B tools/derive/test_derive.py` もG1で再実行する。F1Rの比較道具の回帰は `python3 -B -m unittest discover -s tools/bench/compare -p 'test_*.py'` で確認する | G1担当 | change全体の仮予算内、derive自己検査は過去実測約72秒＋ビルド | `g1/results.md`・`results.md` |
| release | B0→Z1の実候補 | 最適化ビルドの再帰と候補・証拠 | `scripts/check.sh --level release --base a9c4132e6451904698cf344db1794c4d03affcd6`。自動はrelease_stackのみ。下記の実CLIと同梱物の手動照合も行う | 取りまとめ | stack約5分＋ビルド、照合20〜40分 | `z1/results.md`・`results.md` |

G1の照合では、S-W・S-C・S-Fで引用を予定したworkの後にW2R・C2R・F5R等の関係変更があるため、旧workを最終状態へ引用して検査を省かない。S-Aの後にも共有入力が変わっている。G1のchangeの全件・特殊構成と必要な自己検査で同じ接続を確認し、別のstageを重ねない。K1はD42どおり参考記録とし、全比較の受け入れはZ1のK2だけで判断する。

自動分類の終了3では、該当ファイル・選択済み単位を示し、設計者に当該水準の `--level … --only`、互換の `--full`・水準なしの`--only`、`--none`を尋ねる。既に上表で名指した検査はその指定で進める。委任を根拠に必要な検査を黙って省かない。終了2は計画の指定を直し、失敗と道具不在は終了1として未実施の担当・時期を残す。

### 全比較・特殊構成・測定・候補の照合

| 必要な検査 | 実行・引用の割り当て | 契約・構成・具体的な指定 | 担当・時間・保存先 |
|---|---|---|---|
| 既定・heapのall-targets、doc、stress全件、二構成lint | G1のchangeに一度 | test_default_all/test_heap_all/test_stress/doc_default/lint_default/lint_heap。既定gc-mark-sweep、heapはheap-verify付き、stressはさらにgc-stress。fmt・規約・生成Skill・仕様集計・依存・Python・移行自己検査も含む | 取りまとめ、change全体45〜90分の内数、実測不明、g1/results.md |
| derive自己検査 | A5、必要なら最終G1で古くなった分 | check.shのmigrate_selftestsはderiveを含まない。A5の直接コマンドを実施し、G1で以後の入力・生成器の差分を照合する | A5担当、10〜25分の内数、初回不明 |
| long_only | G1のchange | heap/stressを構成ごとに一括、formal書き出しを含めず成功0件を拒否。約15分＋ビルド。Z1で関係するコード・入力が変わった部分だけ再実行 | 取りまとめ、g1/results.md |
| 局所heap-verify・gc-stress・doc | F4b、W2/F3で新しい確保・保持経路を変更した場合もその作業 | `scripts/check.sh --level work --base B_WORK --only heap_local,stress_local,doc_default --test runtime_builtins --test golden`。libの保持経路を変えた場合は `cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify <当該フィルタ>` とgc-stress追加構成を局所実行し、起動依頼で実フィルタを固定 | 各担当、3〜12分の仮予算、初回不明、当該results.md。次の作業の前提にする前 |
| check-heap.sh | heap配下を変えた作業があればG1のchangeがheap_checksを選ぶ。なければ不要な理由をg1/results.mdへ記す。ヒープ不変条件・安全点を越える値の保持方式を変えた作業はその末尾にも必要 | `scripts/check-heap.sh`。nightlyのMiri二構成と到達可能性比較。通常の組み込みで既存の結果確保を使うだけなら局所の全Miri追加は不要と記録し、変更が広がったら前倒しする | 取りまとめ／当該担当、約10分＋ビルド、g1または当該results.md |
| Lean既定ビルドとレビュー | L1・L2a・L2b・L3、段I末にレビュー | formal_buildは既定lake buildとsorry拒否だけである。定義・言明・仮定と01-12の写しを照合し、主定理の変更・追加公理なしを確認。Rustとの全比較の成功には数えない | 各担当・取りまとめ、ビルド各1〜5分、レビュー20〜40分、l1・l2a・l2b・l3のresults.mdとreviews/ |
| check-formal全体K1（参考記録） | F5、接続を閉じる区切り。D42により受け入れの証拠には引用しない | `scripts/check-formal.sh`。六入口、組み込み宣言表、網羅性、全定義の表層検査、独立入力、corpus/sidecar、routing/exchange manifestと件数を照合 | F5担当・取りまとめ、実測不明、仮予算15〜30分、f5/results.mdと永続の要約 |
| check-formal全体K2 | Z1、最後の関係状態 | `scripts/check-formal.sh`を再実行する。候補と同じ生成物・標準ソース・テスト入力であることを記録。G1のformal_buildを全比較の代わりにしない | 取りまとめ、実測不明、仮予算15〜30分、z1/results.md・results.md |
| 性能比較short | W2・A1〜A4・A6・C1・C2・F1・F2・F3・F4a・F4bの取り込みごと。F5/G1が処理系を変えた場合も追加。W1は未接続の関数と依存だけなのでW2後の一回へまとめる。A5はexamples/toolsだけなので対象外（本体へ範囲を広げた場合は追加） | `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=B_AFTER`。既存の全族の代表点を使い、新しい族や専用測定器は作らない。必要時は同じ状態のquick→estimate-fromで校正する | 取りまとめ、ビルド別で各15分以内、初回ビルド不明。tools/bench/results/のMarkdown・HTML・manifest・全標本と当該results.md |
| targets・full、LLM評価、実行ファイルの増分 | 対象外 | 性能目標を約束せず、ソースだけの候補である。targets/fullは別途範囲・見込みを示した了承が必要であり、今回の委任へ含めない。語の比較・SkillのLLM評価も頼まれていない。実行ファイルの大きさの増分も、今回は性能目標やバイナリ配布の受け入れ条件がなく測らない。採る場合は短いビルド比較から時間を見積もり、別途了承を得る | 実行しない。必要が判明したら取りまとめから設計者へ別に提案 |
| release_stack | Z1のrelease。F1等で再帰枠を変えた場合はその末尾にも局所割り当て | 最適化したビルドでの深い再帰のテスト、`pipeline::tests::stages_fit_the_measured_stack_`の成功10件。候補の構成・入力と一致を確認 | 取りまとめ、約5分＋ビルド、z1/results.md |
| 候補の版・CLI・同梱物・配布 | Z1 | `cargo build --release -p benitoite`後、実CLIの `--version`・`--version=json`、一つずつの最小の新書式とファイル宣言のcheck/run、失敗のJSONと終了、`fmt --check`、`skill`の抽出を06-01の正式なCLIで実行。0.0.11・Unicodeの二版・producer・ライセンス表示、gen_skill差分なし、英語/訳/CHANGELOG/移行案内、ソース配布の対象・除外を照合 | Z1担当・取りまとめ、20〜40分＋ビルド、z1/results.md。タグ付き正式アーカイブと公開は待つ |

gc-stressでは回収回数に比例して費用が増すため、新規の受け入れ例は通常0〜数個の値・幅1〜数十を用いる。65535の幅や極端な動的幅の境界は単発の予算検査として扱い、大きな反復や深い入力との積を作らない。新しい大きさのテストを導入する必要は現時点ではない。大きさ自体を確かめるものはignore付きlongへ分け、通常構成の境界をstressだけで消さない。既存のテストの大きさ・期待値・時間制限は緩めない。初回stressが遅ければ、原因を測って新しい入力の構成を再点検し、変更理由を記録する。

shortは測定担当だけが動く時点に直列に行い、了承を待たない。15分は標本採取の上限であり、ビルド時間と分ける。重い負荷・ばらつき・判定不能を記録し、10%または2msの大きい方を越える疑いは段の中で調べる。直すか後の課題に回すかは取りまとめが委任範囲と照合し、保証・範囲を変えるなら設計者へ報告する。測定はG1とZ1の準備に入る前に済ませる。Z1で処理系の動作の修正が要る場合は準備を中断して修正作業へ戻り、shortと古くなった検査を終えてから候補を作り直す。

長い検査の実時間は不明である。既知の固定見込みはcheck.shとstudyの値であり、新しい測定の実績ではない。取りまとめは本実行前にdry-runで選択を確認し、既存キャッシュで短い局所一回（5分を目安）を観測して、全体・節別・ビルドの見込みを更新して設計者へ示す。今回すでに委任されたchange/releaseの範囲はそのまま進められる。未承認の長い測定の追加はせず、見込みの2倍超過・合意した区切りの不成立時は報告して進め方を調整する。

### 残りの作業・検査・測定・レビュー・受け入れ

次の表を残り手順の一つの見積もり表とする。実装の欄は文書修正を含み、検査・測定・レビューを加算しない値である。不明を含むため、全体の確定した終了時刻は示さない。試行・実装・記録は計23作業（F0・G1・Z1を含む）、下表の仮予算の合計は990〜1320分（16.5〜22時間）である。これはセッションの分割予算であり、所要時間の予測ではない。

| 順・ID | 内容 | 実装・記録の仮予算 | 検査・測定の見込み | レビュー・受け入れの見込み |
|---|---|---|---|---|
| 計画の受け入れ | P1文書と事前点検の独立レビュー・修正 | 修正は不明 | 文書リンクと採番の静的確認5〜10分 | 20〜40分、設計者待ちは不明 |
| 0 F0 | 字句接続の短い試行と再見積もり | 30〜45分 | 文書確認5〜10分、局所ビルド不明 | 10〜20分 |
| I L1 | 書式のデータ・妥当性・固定引数 | 45〜60分 | work 1〜5分＋仕様例・集計不明、初回不明 | 10〜20分 |
| I L2a | 型付け・脱糖・型保存・範囲と捕捉 | 45〜60分 | work 1〜5分＋仕様例・集計不明、初回不明 | 15〜30分 |
| I L2b | 表層検査・健全性・計算可能性・有限支持 | 45〜60分 | work 1〜5分＋仕様例・集計不明、初回不明 | 15〜30分 |
| I L3 | 交換と宣言照合・写し | 45〜60分 | work 3〜10分＋仕様例・集計不明、初回不明 | 段Iの定義・言明・仮定20〜40分 |
| II W1 | 幅の本体と依存 | 30〜45分 | work 5〜12分、shortはW2後に一回 | 10〜20分 |
| II W2 | 六関数・予算・版 | 45〜60分 | work 5〜15分、S-Wは引用照合5〜10分、局所特殊構成3〜12分、short 15分以内＋ビルド不明 | 15〜25分 |
| III A1 | ファイル宣言と位置 | 45〜60分 | work 8〜20分、examples初回不明、short 15分以内＋ビルド不明 | 10〜20分 |
| III A2 | 解決・合併・契約 | 60分 | work 5〜15分、short 15分以内＋ビルド不明 | 15〜30分 |
| III A3 | 許可・報告・警告・説明 | 45〜60分 | work 5〜15分、short 15分以内＋ビルド不明 | 10〜20分 |
| III A4 | package記録と増減 | 30〜45分 | work 5〜12分、short 15分以内＋ビルド不明 | 10〜20分 |
| III A5 | deriveと挿入境界 | 45〜60分 | work/自己検査10〜25分（初回不明）、shortなし | 15〜25分 |
| III A6 | fmt・try-actions・標準規約 | 45〜60分 | work 8〜20分、S-A 3〜12分、short 15分以内＋ビルド不明 | 15〜25分 |
| IV C1 | 原因と単純束縛 | 45〜60分 | work 5〜15分、short 15分以内＋ビルド不明 | 15〜25分 |
| IV C2 | 部分構造と後検査 | 45〜60分 | work 5〜15分、S-Cは引用照合5〜10分、short 15分以内＋ビルド不明 | 15〜25分 |
| V F1 | 保留診断と補間の入れ子 | 45〜60分 | work 8〜20分、必要時stack約5分＋ビルド、short 15分以内＋ビルド不明 | 15〜25分 |
| V F2 | AST・解析・診断・fmt | 45〜60分 | work 8〜20分、examples初回不明、short 15分以内＋ビルド不明 | 15〜25分 |
| V F3 | 数の整形・14頭 | 45〜60分 | work 5〜15分、局所特殊構成3〜12分、short 15分以内＋ビルド不明 | 15〜25分 |
| V F4a | 型集合・適合・診断・回復 | 45〜60分 | work 5〜15分、examples初回不明、short 15分以内＋ビルド不明 | 15〜25分 |
| V F4b | 脱糖・定数・実行 | 45〜60分 | work 8〜20分、examples初回不明、局所特殊構成3〜12分、short 15分以内＋ビルド不明 | 20〜30分 |
| V F5 | 六入口と全比較の接続 | 45〜60分 | work 5〜15分、S-F実行時3〜12分/引用照合5〜10分、K1不明（仮予算15〜30分）、shortは本体変更時のみ15分以内＋ビルド不明 | 20〜30分 |
| VI G1 | changeと証拠集約 | 30〜45分 | 文書確認5〜10分、change不明（仮予算45〜90分、longを含みMiriはheap変更時） | 20〜40分 |
| VI Z1 | 0.0.11・訳・同梱物・release | 45〜60分、訳の継続は不明 | work 8〜20分、K2不明（仮予算15〜30分）、stack約5分＋ビルド、実CLI/配布照合20〜40分 | 20〜40分。取りまとめの委任範囲の受け入れと設計者への報告 |
| 設計者復帰後 | 計画判断の確認、集約・タグ・アーカイブ・pushの指示 | 不明 | 指示後の候補とコミット依存情報の再照合は不明 | 待ち時間は不明。今回実行しない |

studyの実装・文書の見込みはformat-and-width 12の21〜41時間とfile-effects 6の9〜18時間、合わせて30〜59時間である。変更前の21作業の仮予算は930〜1200分（15.5〜20時間）であり、旧本文の16〜21時間は足し算と一致していなかった。L2とF4を各45〜60分の二作業へ分けたため、今回は各々30〜60分を追加して990〜1320分とした。計画の受け入れ修正・訳の継続・設計者復帰後の不明な時間と、検査・測定・レビューはこの合計に含まない。

studyとの差は、studyが作業の完了までの所要時間を推測し、この表が一セッションの分割と継続を判断するための仮予算を積み上げているためである。分割自体に短縮効果は見込まない。study 12で第4弾のL作業の時刻からLeanの段を1〜3時間へ補正した根拠はあるが、数の整形・字句接続・回復・文書の段2〜5には同じ補正の根拠がない。終了見込みには30〜59時間の未校正の幅を残し、F0後とL1後に実装・記録の実時間と残る箇所数、ビルド・検査・レビューを分けて再見積もりする。継続が必要なIDは不明を隠さず表へ追記し、仮予算を使い切っても未完成を完了にしない。

## 結果とレビュー修正の管理

| 結果ID | 保存先 | 後の変更・引用の判断 | 再実行の担当 |
|---|---|---|---|
| 各work | 小文字作業ID/results.md | 基準・コマンド・終了状態・外側の時間・計画との差・申し送り。失敗は原因と修正を追記 | 当該担当 |
| S-W/S-A/S-C/S-F | results.md | 接続・入力・構成と取り込み後の完全IDを対応付ける | 取りまとめ |
| K1/K2 | f5/results.md・z1/results.md、集約はresults.md | 一時targetのログだけを引用元にしない。件数とmanifest・入力一覧、元ログの永続の要約を保存 | 取りまとめ |
| short | tools/bench/results/の記録、当該results.mdから参照 | B0・B_AFTERと構成、出力一致、負荷、ばらつき、判定不能、退行の判断を保存 | 取りまとめ |
| change/release | g1/results.md・z1/results.md、集約はresults.md | 候補・差分・版・同梱物の関係が変わった結果だけ更新 | 取りまとめ |

引用する場合だけ、07-03「結果の保存と引用」の全欄（基準・HEADの完全ID、差分の有無と一覧、コマンド・構成・入力・toolchain・件数・終了状態・時間・環境制限、元の記録、以後の変更、同じ関係状態である理由、判断者・日付）を残す。別状態なら未コミット差分・未追跡入力のSHA-256も保存する。成功を引用する根拠のない省略はせず、未実施には担当・時期を記す。

レビューの依頼・報告・対応は`reviews/`へ保存し、ファイル・見出し・問題・直しを対応付ける。実装担当の起動前に[preflight.md](preflight.md)の下書きを取り込み済みのコードで更新・レビューする。取りまとめは担当外の変更を混ぜず、修正後は古くなった検査だけをやり直す。
