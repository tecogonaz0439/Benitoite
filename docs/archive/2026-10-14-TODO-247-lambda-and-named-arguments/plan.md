# TODO-247 実装プラン

## 目的と実行条件

[design.md](design.md) を、段 1 の L1〜L4 と段 2 の N1〜N36 に分けて実装するプランである。今回の依頼では文書だけを作り、以下の作業は実行しない。Codex がメインの作業ディレクトリで一つずつ作業し、作業の完了ごとに `san_benito` に取り込める状態にする。複数の作業を同時に実装せず、サブエージェントへの配布を前提にしない。

一作業の目安は実装・差分確認に 30〜60 分である。ビルド・検査の待ち時間は別に見込む。証明の時間は試行前には確定できないため、Lean の作業で 60 分を超える見通しが立った場合は、まだ変更していない補題群を次の枝番の作業へ分ける。取り込み単位に未証明の定理や失敗するビルドを含めない。この分割は既存の定理を消したり弱めたりする理由にはしない。

Q1〜Q15 は決定済み、R1〜R13 は設計者不在時に推す案で進める暫定方針である。R2 の型・欄の変更表を含む実装の開始指示が、後の実装作業の前提である。現在の設計とインターフェースを変更する承認を、文書だけの今回の依頼からは得たものとしない。表にない公開の型・シグネチャの変更が必要なら、その実装を始める前に変更案を報告する。

## 各作業に共通する完了の関門 K

各作業の「検査: K」は次のコマンドと差分確認をすべて含む。処理系を変えない文書・Lean の作業にも、依頼に従って既定のライブラリテストと fmt・clippy を完了条件として付ける。今回の文書作成でこれらを実行するという意味ではない。

```sh
cargo test -p benitoite --lib
cargo fmt --all --check
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
scripts/check.sh --dry-run
scripts/check.sh
```

走らせる前に検査の種類を設計者へ知らせる。`--dry-run` の選択と理由を確認し、長い検査・全体の検査・`check-heap.sh` を含むなら見込み時間を先に報告する。分類不能で `== stop:`・終了状態 3 になった場合は、該当ファイルと `--full`・`--only`・`--none` の選択を設計者へ尋ね、その答えどおりにする。スクリプトなどを加える作業にはこの可能性がある。既定の選択で省かれる default_lib は、上の `cargo test -p benitoite --lib` で確認する。

構文・型・脱糖の形式化した範囲に接続する作業は `scripts/check-formal.sh` も通す。新しい Lean の準備作業は `formal/` で `lake build` を通し、変更したモジュールを lake のルートまたは対象に登録して未ビルドのまま完了にしない。旧交換形式の検査も保つ。旧形式は corpus 7・型表 1・網羅性 1、新形式は corpus 8・型表 2・網羅性 2 と呼ぶ。N21b から新旧を入力単位で検査し、N34a で全件を最終形式へ切り替える。

K の差分確認は、テストの意図・仕様・観測結果の維持を含む。テストの追加・変更の前に `test-audit` の四つの問いへ答え、作業の記録に残す。既存の assert を消さず、期待値を緩めず、終了状態を変えたり、無関係な誤りへ付け替えたりして通さない。仕様によって診断が変わる負の入力は、design.md「負のテストの分類と仕様上の診断の変更」の旧→新対応表に根拠・元の検査の維持先を記し、具体的な新コードへ厳密に合わせる。G7 でその表を設計者が承認する。位置や型の表示が仕様上変わる期待値は、その理由と修正前後を確認表へ記録して厳密な比較を維持する。

本番コードのコメントは作業 ID（L2・N21 など）や decisions.md・plan.md を根拠にせず、現在の設計書の章と節を引く。01-02 に見出しを追加・改名する場合は、`// spec:` の印、tools/spec-coverage、gen_skill、目次と見出しの参照も同じ変更で確認・更新する。

## 取り込みの順序とレビュー

実行順は L1 → L1a → L2〜L4 → N1〜N5 → N5a → N5b → N6〜N21 → N21a → N21b → N22〜N34 → N34a → N34b → N35 → N35a → N36 とする。既存 ID は維持し、枝番を含めて番号順である。依存欄は直接の前提を示し、番号順なのでそれより前の全作業も取り込み済みである。各作業に処理系のコンパイル・K・個別の関係するテストを付け、複数作業を合わせないと検査を通せない状態を残さない。

| まとまり | 作業 | レビューの焦点と次へ進む条件 |
|---|---|---|
| G1 | L1・L1a・L2〜L4・N1（6 作業） | R8 の旧入力の移行、物理行・終端・整形、段 2 の合流と診断の基準。R8 の互換性への制限を実装前に確認する |
| G2 | N2〜N5・N5a・N5b・N6（7 作業） | 新コアの名前・置き換え・保存、Coverage と CoverageRuntime の import・保証。新たな公理や定理の弱化がない |
| G3 | N7〜N11（5 作業） | 進行・エフェクト健全性、ソース順・穴・パイプと性質 1 |
| G4 | N12〜N16（5 作業） | checker の健全性、corpus 8・型表 2・網羅性 2、六つの入口。定義・言明・証明をレビューし、N18 以降の前提とする |
| G5 | N17〜N21・N21a・N21b（7 作業） | 移行器、Legacy の表現と合流、AST・契約・通常呼び出し。名前付きの実行と同じ作業で新形式の差分検査を接続する |
| G6 | N22〜N26（5 作業） | 未確定契約、穴・パイプ・特殊な呼び出し、全入口の新旧比較、標準ライブラリ。新しい成功入力は実装した作業で独立検査する |
| G7 | N27〜N31（5 作業） | 成功・失敗入力の移行、生成器、現行の設計書。仕様上の診断の旧→新対応表を設計者が承認し、元の誤りの検査の維持先を確認する |
| G8 | N32〜N34・N34a・N34b・N35・N35a・N36（8 作業） | 最終規則、正式モデルへの切り替え、旧経路削除、版・language 宣言・訳、公開前の検査 |


各まとまりのレビューは Codex の自己確認と設計者が読める差分・記録を前提とする。証明の定義と言明のレビューでは、元の定理名、前提、結論、新しい名の保持、差分検査の範囲を対応表で示す。未完の公開やリリースのタグ付けをレビューの代わりに行わない。設計者不在時も文書の詳しい設計は進めるが、実装時に必要なレビューの関門を省かない。

## 段 1 の作業

### L1 物理行とラムダの終わりの表現

- 目的: 境界判定と整形に必要な情報を加え、従来の終端付きの振る舞いを維持する。
- 触るファイル: `src/syntax/token.rs`, `lexer.rs`, `lexer/string.rs`, `syntax/ast.rs`, `parser/exprs.rs`, `parser/mod.rs` の EOF、`parser/items.rs` の restore_newline、`syntax/mod.rs` の新設 lambda_bounds 登録、これらの型を直接構築する parser・formatter のテスト、`docs/design/02-impl/02-03-frontend.md`。`src/` は `crates/benitoite/src/` を指す。
- 手順: R9 と R2 の表に従って Token に start_line: u32・end_line: u32 を追加し、CRLF・文字列・コメントを含む字句解析の全経路を更新する。`LambdaEnding` と `LambdaExpr.ending` を追加し、現在の parser は全て `Explicit` を出す。既存の構築箇所を同じ作業で更新する。R2 の欄の変更に限定する。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::lexer`、`cargo test -p benitoite --lib syntax::parser`、`cargo test -p benitoite --test fmt_command`。既存の終端付きラムダの解析・整形・診断が維持される。
- 依存: 実装開始の指示と R2 の変更範囲の確認。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。位置情報の追加だけで期待する字句や本体の意味を変えない。

### L1a 同じ行に本体を始める複数行の旧ラムダの移行

- 目的: R8 の制限を接続する前に既存入力の本体と観測結果を保つ。
- 触るファイル: crates の src・tests・examples・testdata、tools の現行 .bnt と生成入力、fuzz の現行入力、現行文書の該当例、生成元と Skill の生成物、改造ディレクトリの候補と確認表。
- 手順: R8 の grep の 61 候補から同じ行の単文直後に終端がある例・生成断片を分け、header/body の実際の境界を確認する。二文目・継続行・複数行ブロックのある終端付きだけ、本体先頭に改行を加える。通常・raw・format の Rust 文字列、生成器と連結断片を個別に確認する。構文失敗を試す入力は元の誤りを維持し、archive・reference/・docs/todo は編集しない。生成元を変えた場合は gen_skill で再生成する。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test random_programs`、`cargo test -p benitoite --test spec_examples`、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_docs`、`scripts/check-formal.sh`。出力・終了状態・対象の診断は不変で、変更・不要・保留の実件数を記録する。
- 依存: L1、R8 の互換性への制限を含む実装開始の指示。
- 注意: テストを弱めない。既存の assert と end lambda は消さず、期待値を緩めない。grep 候補数を変更件数としない。L2 が全対象を読めることを移行前後の確認表で示す。

### L2 字句による境界走査・改行判定・短いラムダ

- 目的: Q1・Q2・R8〜R10 の境界を通常の構文解析で受理・診断する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/syntax/newline.rs`, `parser/mod.rs`, `parser/exprs.rs`, `parser/types.rs`, `syntax/mod.rs`、字句列だけを読む非公開の境界カーソル（新設 `syntax/lambda_bounds.rs`）、`diag/codes.rs`, parser の `text` と関係するテスト、`testdata/` の構文のケース、`docs/design/01-spec/01-01-lexical.md`, `01-02-syntax.md`, `02-impl/02-03-frontend.md`, `07-quality/07-04-formal-semantics.md`。
- 手順: R9 の lexer → newline → parser の順で字句走査を実装する。境界走査から Parser を呼ばず、AST や ID を作らない。通常の parser が行内の一文と内部の構文を検査し、R20 で改めた R8 の終端対応・R10 の診断の統合を適用する。短い開きを閉じてから外側の改行を判断する。parser の本体と終端種別を確定する。E0254・E0256 と E0243 の文言を追加・更新する。`testdata/syntax/c11-lambda-colon.diag.json` の主文・ヘルプを明示的に更新し、コード維持と旧→新文言を確認表に記録する。01-02 の見出し・spec 印と参照を揃え、gen_skill で再生成する。型付き表層は変えず、終端省略の解析を 07-04 に「対象外」と記録する。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test spec_examples`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`scripts/check-formal.sh`、`formal/` で `lake build`。内側のコンマ、一行のブロック、型・uses、直接の入れ子、CRLF、複数行の文字列、継続演算子、外側の閉じ忘れと回復を parser の境界で検査する。
- 依存: L1a。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。意図した閉じ忘れを別の終端で回復して成功させない。変更が大きい場合は境界走査の非接続の準備を L2a、通常経路への接続を L2b に分け、接続時に改行判定と parser を一緒に変える。

### L3 短いラムダを保つ整形と検証

- 目的: 終端の選択、物理行、本体の範囲、コメントを整形後も維持する。
- 触るファイル: `src/cli/tools/formatter/roles/walk.rs`, `roles.rs`, `print.rs`, `verify.rs` と各 tests、`tests/fmt_command.rs`, `tests/golden/formatting.rs`, `docs/design/06-tooling/06-03-formatter.md`。
- 手順: Omitted の本体を `block()` で改行させず、Explicit だけをブロックとして整形する。現在の整形器には幅による自動改行がない。前後の字句番号に対応する本体の範囲と終端種別を検証する。終端を自動で増減しない。順序を変える整形は加えない。
- 完了の条件・検査: K、`cargo test -p benitoite --lib cli::tools::formatter`、`cargo test -p benitoite --test fmt_command`、`cargo test -p benitoite --test golden`。再解析・字句とコメントの一致・冪等性・同一行が通る。
- 依存: L2。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。検証を外して短い形を通す変更はしない。

### L4 文書上の推奨と段 1 の例

- 目的: 短い形、else・shadow の非推奨、包括的な分岐の名前を同じ方針で案内する。
- 触るファイル: `docs/design/01-spec/01-02-syntax.md`, `01-03-names-modules.md` と一般例のある章、`docs/reference/benitoite.md`、Skill の `SKILL.md`・手書き参照、標準ライブラリの一般の説明例、`examples/gen_skill.rs` の生成元への対応、生成される Skill 文書。
- 手順: R20 に従い、見出しの行に本体を始めたラムダは同じ物理行の終端だけを取ること、次の行以降の `end lambda` は内側の短い形を閉じず、対応する外側のラムダを閉じること、空行は対応に影響しないことを説明する。旧二行形式は本体を次の行へ移すか一行にまとめる。Z1 の書き直しの一覧を参照し、R19 の空行保持を例に残さない。有効な構文と推奨を分ける。条件の順序と作用先を保持した match の例、別名の bind、衝突しない包括的なパターンを使う。段 1 では位置呼び出しを使い、新しい名前の規則を先に設計書へ書かない。`cargo run -p benitoite --example gen_skill` で再生成する。
- 完了の条件・検査: K、`cargo test -p benitoite --test spec_examples`、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_examples`、`cargo test -p benitoite --test skill_docs`。構文説明と専用の既存テスト、過去の記録を残す。
- 依存: L3。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。else・shadow・case _ の禁止や警告を加えない。訳は N35、名前付きへの最終変更は N31・N32 とする。

## 段 2 の作業

以下の Lean の `NamedRelease/`・`NamedSurface/`・`NamedExchange/` は `formal/Benitoite/` の下に新設する一時的なディレクトリである。対応する現在の `Release/`・`Surface/`・`Exchange/` のモジュールを元にし、最終規則だけを定義する。旧形式と新形式を同じ型とみなす変換はしない。K と `lake build` を通すためだけの `sorry`・公理・診断抑制は認めない。

### N1 移行前の基準と分類の固定

- 目的: 元のテストの観測結果と候補を、後の変更と比較できる形にする。
- 触るファイル: 改造ディレクトリの実装記録（新設）。study の集計、tests・testdata の入力と期待値は読み取り。
- 手順: 基準の成功・診断・終了状態を記録する。候補を成功・意図した失敗・生成入力・歴史資料に分類する。Q10 の全宣言と内側の型を照合し、R2 の変更範囲を確認する。R11 の if・match・リスト・Reference.set・レコードの欄・戻り値を、旧注釈や呼び出し以外の合流として AST・型情報で抽出し、種類別の実件数・位置と契約名の候補を記録する。仕様上の診断の旧→新対応表と、型表示が影響する JSON 11 件の実ファイル一覧も作る。language 宣言は対象の版と版の検査の目的別に数える。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test random_programs`、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_examples`。基準の失敗と移行の対象・除外が説明できる。
- 依存: L4。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。基準の失敗を削除せず、本番の不具合と環境条件を分ける。

### N2 名前を持つ Lean のコアの定義

- 目的: 最終の共有型と名前の整形式を、既存モデルを壊さず定義する。
- 触るファイル: 新設 `NamedRelease/Syntax.lean`, `Model.lean`, `WellFormed.lean`, `Semantics.lean`, `Typing.lean`, `Assumptions.lean`、`formal/Benitoite.lean`、改造ディレクトリの `formal-rules.md`（新設）。
- 手順: 対応する Release の定義を別の名前空間へ写す。Ty.fn・Val.lam と宣言・操作・メソッドに names を加え、長さ・一意性・位置一致を型付けに含める。実行は位置のままにする。定義と元の規則の対応を記す。
- 完了の条件・検査: K、`formal/` で `lake build`。新モジュールをビルド対象へ登録し、定義・型付け・整形式の例が通る。旧モデルと入口も通る。
- 依存: N1。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。名前の正しさを新しい公理にしない。未証明の定理を仮置きしない。

### N3 置き換えと変数移動の基礎補題

- 目的: shift・rename・subst が契約名を保つことを示す。
- 触るファイル: `NamedRelease/Subst.lean`、`Lemmas/Basic.lean`, `Rename.lean`, `Closed.lean`, `TyLemmas.lean`、`formal-rules.md`。
- 手順: 対応する定義と補題を写す。型・エフェクト・値変数の移動で名前を変えないことを証明する。関数型、ラムダ、操作、辞書を含める。
- 完了の条件・検査: K、`formal/` で `lake build`。変更した補題と旧モデルの最終定理が通る。
- 依存: N2。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。比較前に契約名を消す定義にしない。

### N4 型付けの置き換え・反転・正準形

- 目的: 保存と進行に必要な型付けの補題を揃える。
- 触るファイル: `NamedRelease/Lemmas/TySubst.lean`, `TySubstMain.lean`, `SubstTyping.lean`, `Inversion.lean`, `Canonical.lean`, `Regularity.lean`。
- 手順: 補題を新しい型へ移す。名前と個数の整形式を型付けから導く。高カインド・剛な型・エフェクトの置き換えでも名前を保持する。
- 完了の条件・検査: K、`formal/` で `lake build`。元の補題との前提・結論の対応を `formal-rules.md` に記す。
- 依存: N3。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。名前一致を追加の外部仮定として押し付け、保存を弱めない。

### N5 ストア・継続・辞書の補題

- 目的: 制御と型クラスの補題を名前を持つ型へ合わせる。
- 触るファイル: `NamedRelease/Lemmas/StoreLemmas.lean`, `ContLemmas.lean`, `Dict.lean`, `OuterC.lean` と関連する WellFormed・Typing。
- 手順: 操作・継続・セル・辞書とメソッドの型の名前を保持して補題を移す。ハンドラの局所束縛の綴りを契約に固定しない。網羅性の定義と CoverageRuntime の移植は N5a・N5b へ分ける。
- 完了の条件・検査: K、`formal/` で `lake build`。各補題が新しい共有型で通る。
- 依存: N4。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。網羅性やエフェクトの保証を削らない。

### N5a 網羅性の定義と基礎補題

- 目的: CheckTools・CoverageRuntime が import する Coverage を新型で用意する。
- 触るファイル: `NamedRelease/Coverage.lean` の型・パターン・被覆判定と基礎補題、`NamedRelease/CoverageShow.lean` の表示の定義、ビルドのルート。
- 手順: 対応する Release/Coverage.lean（現行 1,789 行）の定義と基礎補題を移す。関数型の名前を保持し、判定の意味を変えない。未移植の定理を宣言せず、移植した言明の証明まで完成する。
- 完了の条件・検査: K、`formal/` で `lake build`。新定義・基礎補題と旧モデルが通る。
- 依存: N5。
- 注意: テストを弱めない。名前を消して型比較を通さず、sorry と公理を足さない。60 分を超える補題群は未変更分をさらに枝番へ分ける。

### N5b 網羅性の健全性・表示・実行時補題

- 目的: 新 Coverage の保証と利用先を完成する。
- 触るファイル: `NamedRelease/Coverage.lean` の残る証明、`CoverageShow.lean`、`Lemmas/CoverageRuntime.lean`、`formal-rules.md`。
- 手順: 元の全言明と対応する健全性を証明し、表示と実行時補題を接続する。N12 の CheckTools が import できることも確認する。
- 完了の条件・検査: K、`formal/` で `lake build`。網羅性の全保証と旧モデルの差分検査を維持し、定理の対応表が揃う。
- 依存: N5a。
- 注意: テストを弱めない。残る定理を削除・弱化しない。比較の入口は N15、Rust の coverage_export の接続は N21b〜N25 とする。

### N6 コアの保存と遷移の健全性

- 目的: 遷移が型と宣言の契約を保つことを証明する。
- 触るファイル: `NamedRelease/Lemmas/PresHelpers.lean`, `PresBase.lean`, `PresMain.lean`, `Preservation.lean`, `StepSound.lean` と関連する Semantics。
- 手順: 遷移の全場合を維持して保存を証明する。呼び出し・操作・辞書の位置の型は names と params の対応から導く。
- 完了の条件・検査: K、`formal/` で `lake build`。preservation と step_sound に対応する言明・証明が揃う。
- 依存: N5b。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。遷移の一部を対象から落とさない。60 分を超える見通しなら基礎の遷移と制御の証明を枝番へ分ける。

### N7 進行・エフェクト健全性とコアのレビュー

- 目的: 新しいコアの最終定理を揃える。
- 触るファイル: `NamedRelease/Lemmas/Progress.lean`, `EffectSound.lean`、`Theorems.lean`, `Examples.lean`, `BuiltinTable.lean`、`formal-rules.md`。
- 手順: 進行・保存・エフェクト健全性を元と対応する前提・結論で証明する。Q10 の内部名と公開名を組み込み表に反映し、定義と言明のレビュー資料を作る。
- 完了の条件・検査: K、`formal/` で `lake build`。新しい公理・sorry がなく、コアのレビューの所見を解消する。
- 依存: N6。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。関数型から名前を消して定理を通さない。

### N8 名前付きの表層の定義と脱糖

- 目的: ソース順と契約の位置を区別する表層を定義する。
- 触るファイル: `NamedSurface/Syntax.lean`, `Typing.lean`, `WellFormed.lean`, `Desugar.lean`、`formal-rules.md`。
- 手順: 既存の全定義を新しい共有型へ写す。call と HoleArgs にラベル・位置を持たせ、位置 0 の挿入、穴のソース順、argN、取り出す関数の value を定める。ソース順の let の後、参照だけを並べる。
- 完了の条件・検査: K、`formal/` で `lake build`。通常・穴・パイプ・操作・メソッドを含む定義と型付けの例が通る。
- 依存: N7。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。式を宣言順へ並べて評価順を変えない。

### N9 表層の変数移動と文の列の型保存

- 目的: 呼び出しの証明の基礎を揃える。
- 触るファイル: `NamedSurface/Lemmas/ShiftClean.lean`, `SubstClean.lean`, `Scoped.lean`, `ScopedRename.lean`, `ExtensionsScoped.lean`, `Sequence.lean`, `Invariants.lean` と基礎の補題。
- 手順: 名前を保持して既存の補題を写す。return・try・単文・文の列・束縛の作用先と型保存を維持する。長い let の変数番号の移動を含める。
- 完了の条件・検査: K、`formal/` で `lake build`。新しい全構文の帰納法で補題が通る。
- 依存: N8。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。短い形の解析境界まで証明したと称さない。

### N10 呼び出し・パイプ・穴の型保存

- 目的: 位置対応と穴の名前が性質 1 を保つことを示す。
- 触るファイル: `NamedSurface/Lemmas/Calls.lean`, `CallHead.lean`, `Typing.lean`、Desugar の位置対応の補助。
- 手順: 位置の全域性・単射性とソース位置ごとの型を使う補題を作る。callee の先行評価、ソース順の let、位置順の参照、穴の遅れた評価、パイプの挿入を証明に含める。
- 完了の条件・検査: K、`formal/` で `lake build`。逆順指定と複数の穴の型保存が定理から導ける。
- 依存: N9。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。ソース順と宣言順の計算が可換だと仮定しない。

### N11 制御・コレクション・辞書と性質 1

- 目的: 既存の表層の全範囲を新規則へ接続する。
- 触るファイル: `NamedSurface/Lemmas/Extensions.lean`, `Patterns.lean`, `Records.lean`, `Dict.lean`, `Program.lean`、`Theorems.lean`, `Examples.lean`。
- 手順: 操作・ハンドラ・型クラス・構成子値・レコード・制御の補題を移す。Calls の補題をつなぎ、プログラム全体の脱糖の型保存を証明する。
- 完了の条件・検査: K、`formal/` で `lake build`。性質 1 が元の範囲に対して成立し、契約の不一致を型付けで拒否する。
- 依存: N10。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。操作や型クラスを証明から除かない。大きければ制御と辞書を枝番へ分ける。

### N12 実行可能な表層の検査

- 目的: Rust の出力を独立して検査する checker を作る。
- 触るファイル: `NamedSurface/Check.lean`, `CheckPredicates.lean`, `CheckSupport.lean`, `CheckTables.lean`, `CheckTools.lean`, `CheckPatterns.lean`, `CheckToolsExamples.lean` と検査の定義。
- 手順: 契約名・ラベル、位置の範囲・重複・不足、ラムダ・メソッド、穴・パイプを検査する。 実装メソッドは位置による束縛へ変換する前の引数名を保持し、型クラスの `MethSig.names` と並び全体を比較する。N8〜N11 の `ImplDecl.methods` は本体だけを持つため、この一致を検査済みとは扱わない（R35）。既存の全構文を維持し、Rust が渡す位置を名前から検証する。
- 完了の条件・検査: K、`formal/` で `lake build`。誤ったラベル・逆の対応・重複位置の反例を独立入力で拒否する。
- 依存: N11、N5b の Coverage と CoverageShow。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。入力が既に正しいという仮定を足さない。

### N13 検査の健全性: 呼び出しと基本の式

- 目的: checker の成功から基本の式と呼び出しの型付けを導く。
- 触るファイル: `NamedSurface/CheckLemmas.lean`, `CheckInduction.lean`, `CheckSoundBasicExpr.lean`, `CheckSoundSequence.lean`, `CheckSoundCalls.lean`。
- 手順: 基礎を移し、名前・positions の検査の成功から型付けの前提を導く。穴とパイプの契約生成も含める。
- 完了の条件・検査: K、`formal/` で `lake build`。検査成功から名前・位置の整形式と型付けを導ける。
- 依存: N12。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。ラベル検査の成功を外部から仮定して健全性を弱めない。

### N14 検査の健全性: 残る全範囲

- 目的: プログラムとコレクション・制御・辞書の健全性を完成する。
- 触るファイル: `NamedSurface/CheckSoundControl.lean`, `CheckSoundCollections.lean`, `CheckSoundDicts.lean`, `CheckTablesSound.lean`, `CheckProgramSound.lean`, `CheckSound.lean`, `CheckExamples.lean`, `CheckCounterexamples.lean`。
- 手順: 宣言・操作・型クラスの契約名とラムダの一致を検査する証明を移す。 `CheckSoundDicts` とプログラム全体の健全性では、実装メソッドの引数名と型クラスの宣言名の一致を、N12 の検査成功から導いて本体の型付けへ接続する（R35）。元と同じ保証のプログラム全体の言明を揃える。
- 完了の条件・検査: K、`formal/` で `lake build`。checker の健全性・性質 1・コアの最終定理が全て通る。
- 依存: N13。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。対象外を増やさない。必要なら制御と辞書の証明を枝番へ分ける。

### N15 Lean の corpus 8・型表 2・網羅性 2 と独立した入口

- 目的: 契約名とソース順を失わずに新モデルへ入力する。
- 触るファイル: `NamedExchange/Syntax.lean`, `Convert.lean`, `Builtins.lean`, `CheckInput.lean`、新設 `formal/NamedSurfaceCheck/Main.lean`, `NamedDesugarDiff/Main.lean`, `NamedBuiltinCheck/Main.lean`, `NamedCoverageDiff/Main.lean`, `NamedCoverageProgramDiff/Main.lean`、新設 `NamedSurfaceCheck/All.lean`（surfaceCheckAll）、`lakefile.toml`、corpus 8・型表 2・網羅性 2 の独立した入力。
- 手順: corpus 8・型表 2・網羅性 2 の JSON の欄を定義し、名前欠落を拒否する。組み込み・操作・メソッドの型を Q10 の表で接続する。比較の正規化で契約名・位置を消さない。旧 corpus 7・型表 1・網羅性 1 の入口を維持する。desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll の六つ全てに対応する新入口をビルドへ登録する。coverage_export との交換の定義も揃える。
- 完了の条件・検査: K、`formal/` で `lake build`。新形式の正常・不正入力を新入口で検査し、旧入口の検査も通る。
- 依存: N14。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。新形式から名前を消して旧形式に通す変換をしない。

### N16 形式規則・定理・交換形式のレビュー

- 目的: Rust の表現変更より前に新しい形式化の保証を確定する。
- 触るファイル: `formal-rules.md`、レビュー記録、Named のモデルの所見の修正。
- 手順: 元と新しい定理の前提・結論・範囲を対応表にする。関数型、positions と評価順、穴・パイプ・操作・メソッド、対象外を確認する。G4 の所見を解消する。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh` の旧入口の検査、新入口の独立入力の検査。sorry と新たな公理がなく、定義と言明のレビューを終える。
- 依存: N15。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。レビューより前に新しい型・呼び出しの意味を処理系へ実装しない。

### N17 確認可能な移行道具と基準の manifest

- 目的: 機械的な書き換えを人が照合・保留・再適用できる形にする。
- 触るファイル: 新設 `tools/named-arguments-migrate/README.md` と抽出・manifest・diff のスクリプト、`crates/benitoite/examples/named_arguments_inventory.rs`、移行確認表、`AGENTS.md` のディレクトリ構成の表。
- 手順: 現在の parser・resolve・typeck の公開境界で成功入力の契約と範囲を抽出する。Rust 文字列と Markdown を元ファイルの範囲へ戻す。既定は読み取りと diff の出力、適用は確認済み manifest のハッシュ一致を必須にする。R11 の命名の成分を抽出し、宣言の期待名、なければ最初のラムダの実名を候補にする。合流の件数と全候補を N1 と照合し、衝突・公開契約・複数期待は保留する。失敗入力は元の診断と仕様上の変更を別分類で記録する。新しい道具を AGENTS.md の表へ登録する。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden`。道具の少数の独立入力で、コメント・文字列・構成子・型注釈を誤編集しないことを確認する。全対象の `manifest.json`・確認表・unified diff を生成できる。
- 依存: N16。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。調査用の count-calls.py を移行器として流用しない。期待値の一括更新を生成しない。

### N18 名前付き引数と型注釈の AST・構文・整形

- 目的: 新しい構文を保持し、旧入力も開発中に解析できる状態にする。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/syntax/ast.rs`, `parser/exprs.rs`, `parser/types.rs`、Arg と FnType を消費する resolve・typeck・desugar・formatter、`diag/codes.rs` と関係するテスト。
- 手順: R2 の Arg::Named と FnType の欄を追加し、全消費箇所をコンパイルできる形へ更新する。名前付きの値・穴・型を解析し、ラベルを resolve の参照にしない。構文と整形を検査する。Arg::Named の解析補助は非公開の関数として準備し、その関数の parser・formatter の単体検査で構文を確認する。一般の parse_args への新分岐の接続は N21b、名前付きの穴とパイプの接続は N23 とする。途中の一般入力には現行の構文診断を維持し、未実装という検査エラーや一時的な診断コードを作らない。旧入力は従来経路で維持する。新しい型注釈の一般経路への接続は型表現ができる N19 で行う。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib syntax::parser`、`cargo test -p benitoite --lib resolve::`、`cargo test -p benitoite --test fmt_command`、`cargo test -p benitoite --test golden`。新しいラベルを無視して実行しない。
- 依存: N17。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。旧表記の欠落名は Legacy の別の表現にし、最終の名前の並びの長さの不変条件を破ってよいまま放置しない。

### N19 静的な型の契約名と型の走査

- 目的: 名前を型の表示・置き換え・比較に保持する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/types/mod.rs`、`typeck/infer.rs`, `context.rs`, `solve.rs`, `limits.rs`、`ir/core_ir.rs` の Lambda・Def・OpDef と下位 IR への写像、builtins・参照インタプリタ・tests の型と IR の構築箇所、`tests/desugar_export/` の新型の出力補助。
- 手順: FnTy・Scheme.param_names と IFnTy.contract、コア IR の静的な param_names を追加する。全初期化と walk・substitute・zonk・show・Hash・下位 IR への写像を更新する。`tests/desugar_export/` に新型と注釈の corpus 8 の出力補助を同じ作業で加え、N15 の独立入力の検査へ渡す。Var.name は局所名として保つ。旧型は Legacy として出どころを区別し、その経路だけ現在の適合を維持する。新しい型注釈の parser 経路も接続し、明示型どうしは名前を位置ごとに比較する。R2 の ContractOrigin と IContract::Legacy、Eq・Hash の厳密な構造比較と制約の旧適合の区別を実装する。R11 の分岐・リスト・セル・レコード・戻り値には理由付きの旧制約を生成し、新しい明示型の成分は同じ作業で移行する。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib types::`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test golden`。N1 の型表示 JSON 11 件を個別に照合し、変わる Named の期待値だけ理由と旧→新表示を記録する。旧経路のcorpus 7 は維持する。
- 依存: N18。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。params の型の確認を残し、名前の確認を追加する。実行時のクロージャに欄を加えない。

### N20 宣言・ラムダ・組み込みの契約の出どころ

- 目的: 契約名を宣言と実際に書いたラムダから一貫して取る。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/typeck/decls.rs`, `generate.rs`, `effects/declarations.rs`, `traits/collect.rs`, `traits/impls.rs`, `records.rs`, `external.rs`、`builtins/table.rs`、`prelude/stdlib/` の高階の型注釈、`tests/desugar_export.rs` と補助・型表の新出力。
- 手順: 宣言名を Scheme、ラムダの実際の名前を IFnTy に入れる。データ構成子値の argN、レコード構成子値の宣言順のフィールド名、取り出す関数の value、内部の演算の名前を与える。Q10 の内側の型注釈を道具で追加する。クラスの名前比較の準備をし、R11 の全種類の旧合流を Legacy で維持し、名前を厳密にする適合成分だけ同時に移行する。新宣言とラムダの検査は、旧適合がない完全移行済みの最小プログラムを corpus 8・型表 2 へ書き出して同じ作業で比較する。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --lib resolve::`、`cargo test -p benitoite --lib builtins::`、`cargo test -p benitoite --test runtime_builtins`、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test golden`。N1 の型表示 JSON の変更理由と旧→新を記録する。標準ライブラリ全体の収集と型検査が通る。
- 依存: N19。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。局所名を暗黙に読み替えない。新しい明示型に関係する適合のために必要な入力の改名は同じ作業で行う。

### N21 既知の契約への CallPlan と通常呼び出しの準備

- 目的: 名前付きの通常呼び出しの型検査と脱糖の補助を準備する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/typeck/mod.rs`, `context.rs`, `generate.rs`, `solve.rs`、新設 `typeck/calls.rs`、`ir/desugar/exprs.rs`、`resolve/walk.rs`, `resolve/lookup.rs` の RecordExpr の構成子判別、`diag/codes.rs` と text、型と実行順のテスト。
- 手順: CallPlan を出力し、既知の契約の未知・重複・不足と引数型を検査する。新しい名前付き呼び出しの補助を用意し、一般 parser への接続は N21b とする。旧複数位置指定は移行中の旧経路とする。callee と引数をソース順に let し、参照だけを宣言順へ置く。RecordExpr で解析された直接のデータ構成子にも E0456 を出す経路を用意する。新しいパイプ・穴の一般構文への接続は N23 へ置く。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --lib ir::desugar`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test call_allocations`。新補助の単体検査で対応とソース順を確認し、実行順の統合検査は N21b で接続する。末尾呼び出しと確保の既存の契約を保つ。
- 依存: N20。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。表の欠落でラベルを無視するフォールバックを作らない。

### N21a Rust の新形式の書き出し器の準備

- 目的: 名前付き呼び出しを実行へ接続する前に、corpus 8 の出力を用意する。
- 触るファイル: `tests/desugar_export.rs`, `tests/desugar_export/` の新出力補助、`tests/coverage_export.rs` と補助、`scripts/check-formal.sh` の版別の振り分けの準備、移行 manifest。
- 手順: N19・N20 の新型・新宣言の出力補助に、ソース順のラベル・式、CallPlan の位置、穴・挿入の静的欄の書き出しを加える。旧 corpus 7 は維持する。型表 2・網羅性 2 の出力を作り、独立した入力で N15 の入口と照合する。範囲内入力の版と対象件数を記録する。
- 完了の条件・検査: K、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。旧全件と新補助の独立入力が通る。
- 依存: N21、G4 のレビュー完了。
- 注意: テストを弱めない。通常の名前付き呼び出しの一般入力の新形式への振り分けは N21b で接続する。N19・N20 の新型・新宣言の最小入力の検査は維持する。新型から名前を消して旧入力として検査しない。

### N21b 通常の名前付き呼び出しと差分検査の同時接続

- 目的: 一般入力の新しい呼び出しを、実行と Lean の検査へ同じ作業で接続する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、 parser/exprs.rs の一般の引数の分岐、N21 の typeck・desugar・resolve の補助、N21a の exporter と版別の振り分け、`scripts/check-formal.sh`、実行順と負の入力のテスト、formal-rules.md。
- 手順: 名前付きの通常引数を接続する。追加する成功入力は依存宣言を含めた全契約を移行し、corpus 8 と型表 2 へ書き出す。旧適合だけの単位は corpus 7 と型表 1 へ残す。RecordExpr の E0456 も一般経路へ接続する。呼ぶ式・引数をソース順に評価し、参照だけを宣言順へ置く。新しい穴とパイプの parser 分岐は N23 まで一般経路へ接続しない。
- 完了の条件・検査: K、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test call_allocations`、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`formal/` で `lake build`、`scripts/check-formal.sh` の全入口の新旧比較。逆順の引数・callee・途中の失敗・末尾呼び出しと確保の契約を確認する。
- 依存: N21a。
- 注意: テストを弱めない。逆順の新入力を corpus 7 へ渡さず、対象外へ回さない。対象内の成功入力がどちらの版でも検査されない状態を残さない。

### N22 未確定の契約と保留呼び出し

- 目的: 呼び出しの記述順から契約順を作らない推論を完成する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`tests/desugar_export.rs` と補助・版別の出力、`src/typeck/infer.rs`, `solve.rs`, `context.rs`, `generate.rs`, `traits/solve.rs`, `calls.rs`、`diag/codes.rs`, `typeck/text.rs` と関係するテスト。
- 手順: IContract::Var の統合と保留制約を実装する。通常の制約と呼び出しの Flow を変化がなくなるまで解く。最後の未確定は E0455 にし、別の制約から後で契約が定まる入力は受理する。契約変数は一般化しない。R12 の未使用 run と g(1) は E0455、同じ検査単位で確定後の a/b 不一致は E0454 とする。未確定の param_names は出力しない。新たに受理する入力を corpus 8 に書き出す接続も同じ作業で加える。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test random_programs`。未使用、単一位置指定、後から契約が確定する入力、同一単位の不一致、注釈付き多相 apply を検査する。注釈・分岐・別名・高階・エフェクト包含と型クラスの既存の検査を保つ。
- 依存: N21b。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。検査単位を越えて呼び出し元から契約を後付けする新しい推論を導入しない。

### N23 パイプ・穴・構成子の関数値

- 目的: Q6・Q7・Q9 の契約と評価の時期を接続する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`tests/desugar_export.rs` と補助・版別の出力、`src/typeck/generate.rs`, `calls.rs`、`ir/desugar/exprs.rs`, `decls.rs`、型と golden のテスト。
- 手順: 新しい名前付きの穴とパイプの parser 分岐、型検査・脱糖、corpus 8 の出力を同じ作業で接続する。自動挿入の位置 0 と重複を記録する。穴の名前を元の契約からソース順に取り、生成する型に入れる。callee と固定引数は生成した関数の内側で評価する。直接のデータ構成子は位置、値と穴は argN とする。レコード構成子値は R13 のフィールド名とする。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --lib ir::desugar`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test random_programs`。左辺の一回の評価、固定引数の遅れ、穴の名前と順、return・try・resume の境界を確認する。
- 依存: N22。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。空いた場所への推測や自動の再部分適用を加えない。

### N24 操作・メソッド・外部・コード生成

- 目的: 全ての関数型の呼び出しを同じ契約で実行する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`tests/desugar_export.rs` と補助・版別の出力、`src/typeck/effects/`, `traits/impls.rs`, `external.rs`、`ir/desugar/dicts.rs`, `effects.rs`、`bytecode/codegen/emit.rs`、`external/check.rs` と統合テスト。
- 手順: クラス宣言の名を実装、操作宣言の名を呼ぶ側に要求し、ハンドラの局所束縛は自由とする。外部へ位置に写して渡し、WIT は位置の照合を保つ。新たに受理する対象内の操作・メソッド・辞書の出力を同じ作業で corpus 8 と新型表に接続する。値の配置・安全点・Call・TailCall・辞書の内部引数を確認する。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test vm_handlers`、`cargo test -p benitoite --test call_allocations`、`cargo test -p benitoite --test verify`、`cargo test -p benitoite --test l13_external_commands`。既存の外部・辞書・エフェクトの検査が通る。
- 依存: N23。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。VM の名前検索・引数用の辞書・新しい言語値の確保を導入しない。

### N25 Rust の 新形式 出力と Lean の差分の接続

- 目的: 新しい契約名とソース順を独立した検査へ渡す。
- 触るファイル: `tests/desugar_export.rs` と `desugar_export/`、新形式の出力補助、formal の新入口、`scripts/check-formal.sh`、`formal-rules.md`、改造ディレクトリの対応記録（現在の 07-04 への「準備中」の追記はしない）。
- 手順: N21b〜N24 で接続済みの名前・ラベル・ソース順・位置・穴・挿入と版別の振り分けを照合する。移行済みの独立入力を新入口と比較し、全ての旧入力は 旧形式の検査を続ける。どちらにも検査されない範囲内入力を作らない。六つの入口（desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll）と coverage_export の対象件数を確認する。正式モデルと 01-12・07-04 の更新は N34a とし、追加モデルの準備と対応は formal-rules.md に記す。
- 完了の条件・検査: K、`cargo test -p benitoite --test desugar_export`、`formal/` で `lake build`、`scripts/check-formal.sh` の旧形式の全件と 新形式の移行済み入力。改ざんしたラベル・位置は 新形式の検査が拒否する。
- 依存: N24、G4 のレビュー完了。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。正規化で契約名を消さない。旧入力を対象外にして件数を減らさない。

### N26 標準ライブラリの呼び出しとコールバックの移行

- 目的: 標準ライブラリを最終契約へ揃える。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/prelude/stdlib/` 全体、移行 manifest・確認表と道具の必要な修正。
- 手順: 147 候補と高階の型・ラムダを道具で分類し、Q10 の名で patch を作る。型クラスの実装と mapFrom・foldFrom・Regex・HTTP の内部呼び出しも直す。保留の関数値と局所名の衝突は個別に解く。
- 完了の条件・検査: K、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --lib resolve::`、`cargo test -p benitoite --lib builtins::`、`cargo test -p benitoite --test runtime_builtins`、`cargo test -p benitoite --test desugar_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。公開・内部の全名が表と一致する。
- 依存: N25。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。Rust 本体の名を正にして公開宣言を改名しない。確認できる diff と理由の表を残す。

### N27 成功する testdata の機械的な移行

- 目的: 成功するスクリプトの観測結果を保って移行する。
- 触るファイル: `crates/benitoite/testdata/` の成功する入力、移行 manifest・確認表、道具の必要な修正。
- 手順: 1,502 候補のうち成功入力を道具で変更し、型とラムダ名も合わせる。出力・値・評価順・終了状態の期待値は維持する。確認済み manifest だけを適用する。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test desugar_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。結果が維持され、二度目の移行の差分が空になる。
- 依存: N26。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。60 分で確認できない分量は testdata の分野ごとの枝番に分ける。未確認の一括更新は取り込まない。

### N28 失敗を試す testdata の診断を保つ移行

- 目的: 元の誤りを名前必須の診断に隠させない。
- 触るファイル: testdata の check 失敗・run 失敗の入力と必要な位置の期待値、移行 manifest・確認表。
- 手順: 元のコードと誤りの原因を記録する。その検査へ到達するためのラベル・型・ラムダのパラメータ名と束縛された参照を直す。仕様上変わる診断は旧→新表に根拠と元の退行の維持先を記し、G7 で承認を受ける。名前必須の新ケースは別に追加する。型の表示・位置の期待値は理由を個別に確認し、終了状態と対象の誤りを維持し、承認した仕様上の変更だけ厳密な新診断へ合わせる。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test desugar_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。各ケースが元の対象の誤り、または理由を記録した仕様上の診断で失敗する。元の型・個数の誤りの退行の検査が別のケースで残ることも確認する。
- 依存: N27。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。expected の一括更新や E0449 への置き換えで済ませない。分量は分野の枝番へ分ける。

### N29 Rust 内の入力・生成器・fuzz の種の移行

- 目的: .bnt 以外から作る入力も揃える。
- 触るファイル: src のテスト文字列、`tests/` のスクリプト、`tests/random_programs/generator.rs`, `shrink.rs`、examples の生成入力、fuzz の入力を作る箇所・種、移行 manifest。
- 手順: 782 候補を元の文字列の範囲で編集し、連結・format・補間・生成入力は保留を個別に解く。生成器は名前・型・穴・パイプを整合させ、縮小器もラベルと型を保つ。Rust の assertion の構造を維持する。
- 完了の条件・検査: K、`cargo test -p benitoite --test random_programs`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test desugar_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。固定の種の差分と、生成・縮小した入力の名前の規則が通る。
- 依存: N28。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。エスケープ後の行番号を元の編集位置に使わない。単体テスト・統合入力・生成器は分量に応じて枝番に分ける。長い fuzzing や LLM の評価を始めない。

### N30 現行の例・道具の入力・参照解の移行

- 目的: 現在使うその他の .bnt を実行できる形にする。
- 触るファイル: examples、tools/bench の現行入力、tools/skill-eval の現行参照解、その他の現行 .bnt、移行 manifest。
- 手順: 396 候補を分類して patch を確認する。歴史的な比較案・測定記録を除外する。関数値や局所名の衝突を個別に解き、元の結果を維持する。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden`。対象入力を `benitoite check` または道具の短い既存の自己検査で確認する。副作用の条件を確認した実行例は既存の期待結果と比較する。
- 依存: N29。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。性能測定や LLM を呼ぶ評価を始めない。reference・archive・docs/todo を編集しない。

### N31 設計書と正式な規則の写しの準備

- 目的: 実装した内容と現行例の説明を揃える。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、 design.md の文書表に列挙した `docs/design/01-spec/`, `02-impl/`, `03-interop/`, `06-tooling/`, `07-quality/` の章、必要な付録 08-04 と目次・参照、改造ディレクトリの最終文書の patch。
- 手順: 名前・適合・保留推論・対応表と評価順、構成子・パイプ・穴・対象外を説明する。一般例を移行する。Legacy の受理を公開仕様に追記しない。名前必須と最終の適合の記述は N33 の切り替え patch として準備する。01-12 の写しは N34a の正式モデルの変更で同時に反映する。
- 完了の条件・検査: K、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --test spec_examples`、リンクと見出しの参照の確認。実装済みの部分だけ適用し、残りは改造ディレクトリの patch でレビューできる。
- 依存: N30。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。テストが読む text ブロック・見出しを除外しない。未実装の最終規則を先に現在の仕様として書かない。

### N32 現行リファレンス・Skill と生成物

- 目的: 最終の書き方と移行方法を人と LLM に案内する。
- 触るファイル: `docs/reference/benitoite.md`, `install.md`、Skill の `SKILL.md` と手書き参照、`examples/gen_skill.rs` の型と診断の生成、生成される grammar・diagnostics・stdlib。
- 手順: Q3 の例を名前付きへ直し、Q5 の一致・ラッパー・穴・パイプ・生成する名前を説明する。移行節を加える。生成元を変え、`cargo run -p benitoite --example gen_skill` で再生成する。非推奨だが有効な構文の説明を保つ。
- 完了の条件・検査: K、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_examples`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --test spec_examples`。再生成後の差分が安定し、例と型が一致する。
- 依存: N31。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。生成物を手で直さない。最小実行版の文書と過去の例を移行しない。

### N33 最終規則の強制・移行診断と Legacy の削除

- 目的: 旧入力の受理を終え、名前と順を例外なく検査する。
- 触るファイル: Skill の生成される参照文書（gen_skill の出力）、必要な `examples/gen_skill.rs` の表示・生成元への対応、`src/syntax/parser/types.rs`、`typeck/calls.rs`, `infer.rs`, `solve.rs`, `traits/impls.rs`、`diag/codes.rs` と text、`modules/package.rs` の移行ヘルプ、移行確認表、N31 の最終設計書の patch。
- 手順: 全保留を解消する。複数位置指定・混在・旧関数型を拒否し、一引数の高階の名前も要求する。E0257・E0449〜E0456 と E0908 の案内、R6 の優先順位と安全な編集を完成する。Legacy・仮の補完と旧適合を削除し、最終文書を同時に適用する。新規則の負のケースを関門を通して追加する。
- 完了の条件・検査: K、`cargo run -p benitoite --example gen_skill`、`cargo test -p benitoite --test skill_docs`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test random_programs`、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_examples`、`cargo test -p benitoite --test spec_examples`、`formal/` で `lake build`、`scripts/check-formal.sh`。全対象が最終規則で検査され、暫定経路がゼロになる。
- 旧適合の削除の回帰条件（G5 指摘3）: `apply(f: function(x: Integer, y: Integer) -> Integer, ...)` の旧本体で `f(x: 1, y: 2)` を呼び、外側から `sub(y, x)` を位置指定で渡す入力を負の回帰テストにする。移行中は旧本体が内側を Legacy にするため、sub に y=1・x=2 が渡る。N33 では外側を名前付き呼び出しへ直した入力 `apply(f: sub, ...)` に E0454 を要求し、契約名の相違を位置指定の移行診断だけで隠さない。`sub(x, y)` に揃えた対照入力は受理し、x=1・y=2 を渡す。暫定的な入れ替わりを成功の契約として固定するテストは追加しない。
- 呼び出し経路の統一の回帰条件（G6 指摘5）: 同じ名前付き引数を含む本体で `target(1, 2)`、`1 |> target(2)`、`target(1, _)` を検査する。現在は通常呼び出しだけが旧位置指定の経路で受理される。N33 では通常・パイプ・穴のすべてで複数位置指定を E0449 にし、`target(a: 1, b: 2)`、`1 |> target(b: 2)`、`target(a: 1, b: _)` は受理する。旧入力用の経路とこの暫定差を残さない。
- SEC-F1 の検出位置の回帰条件（G7、R80・R92）: 名前付き呼び出しの対応を保留して解く制約の順序に検出位置が依存するため、旧適合の削除後も `handlers/secf1-effect-confusion` と `secf1-value-confusion` が `resume(p)` の位置で E0401 と同じ流出の注記を出すことを厳密な golden で確認する。`secf1-nested-escape` は引数位置で直接流出を拒否する E0401 を維持する。期待位置を機械的に更新せず、変われば制約の順序と保証への影響を調べて判断を記録する。
- 最終設計書の確認（G7、R78・R92）: `n31/n33-final-design.patch` の適用後に、01-02 の複数位置指定の一律拒否と 02-10 の E0449 が実装と一致することを確認する。パイプ・穴だけで E0449 を実装していた暫定差を解消する。
- 依存: N32、N26〜N30 の保留解消。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。残数をゼロと表示するだけでなく全入力を再検査する。版番号を創作しない。

### N34 全入力の新形式への統一と切り替え patch の準備

- 目的: 正式モデルを動かす前に corpus 8 の全件と削除対象を確定する。
- 触るファイル: `tests/desugar_export/`、`tests/coverage_export.rs` と補助、正式化の patch・manifest・定理対応表、改造ディレクトリの記録。
- 手順: Legacy がない全対象の出力を corpus 8・型表 2・網羅性 2 に統一し、Named の六つの入口で全件比較する。旧入口用の独立した入力は N34a まで維持する。名前空間・import・lake 登録・六つの Main とラッパー・01-12・07-04・check-formal.sh の切り替え patch を作る。
- 完了の条件・検査: K、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。Named の全件比較と旧入口の独立入力が通り、対象内件数・対象外理由を基準と照合する。
- 依存: N33、G4 のレビュー完了。
- 注意: テストを弱めない。正式の定義と 01-12 をこの準備だけで切り替えない。未検査の範囲を残さず、切り替え patch をレビューできる形にする。

### N34a 正式モデル・全入口・規則の写しの同時切り替え

- 目的: 証明済みの新モデルを正式な定義と文書へ反映する。
- 触るファイル: `formal/Benitoite/Release/`, `Surface/`, `Exchange/` と Named の対応先、全 import と lakefile、DesugarDiff・BuiltinCheck・CoverageDiff・CoverageProgramDiff・SurfaceCheck の Main と `SurfaceCheck/All.lean`（surfaceCheckAll）、`scripts/check-formal.sh`、`01-spec/01-12-core-calculus.md`, `07-quality/07-04-formal-semantics.md`, `07-03-compiler-testing.md`。
- 手順: N34 の patch を適用し、名前のある新モデルを正式な名前空間へ移す。元と同じ保証の定理を確認した上で旧正式モデルを置き換え、六つの正式入口とチェックのスクリプトを corpus 8・型表 2・網羅性 2 へ同時に切り替える。Coverage・CoverageShow・CheckToolsExamples も含める。01-12 の写しと 07-04 の対応表を同じ変更で反映する。`V_Fun`・`V_Prim`・`V_Op`・`C_Meth`・`HasTypeClauses.cons` の `NamesWF` は「整形式から従う」と写しに書き添え、独立した外部仮定として扱わない（formal-rules.md「型付けから従うラムダ名と宣言名」）。旧入口をビルドと検査の登録から外す。
- 申し送り（Z4）: formal-rules.md「範囲条件に置く名前の条件」の一覧を 01-12 の範囲条件と 07-04「01-12 との対応」へ写す。`coreNames` の整形式・未使用の `conFields` の条件を型付けから導いたとは書かず、内部名の非衝突を支える字句規則は対象外として区別する。実装メソッドの実名一致は `ImplDecl.WellTyped` の射影だけからは得られないが、N12〜N16 の実名付き入力と `checkImpl_contracts`・`checkProgram_contracts` が検査成功から保証するため、この保証を checker の範囲として記録する。`CallOk.recordFields_source` の値の配置の保証と、定義・具体例で確かめる評価順の範囲も区別して写す。
- 完了の条件・検査: K、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`formal/` で `lake build`、`scripts/check-formal.sh` の六つの入口と全件。進行・保存・エフェクト健全性・性質 1・checker と網羅性の健全性が通る。
- 依存: N34 の全件比較と切り替え patch のレビュー完了。
- 注意: テストを弱めない。名前空間の移動は機械的な差分として確認し、独自の仕様修正を混ぜない。正式の定義と写しを別々の取り込みに分けない。段階 A の Core は残す。

### N34b 一時モデル・旧書き出し器・旧形式の削除

- 目的: 未参照の移行用経路を消し、最終形式だけを残す。
- 触るファイル: Named の旧登録・残る一時ファイル、旧形式の Rust exporter・旧独立入力、スクリプトと記録、関連するドキュメントの最終記述。
- 手順: N34a で参照を外した旧入口・型表・corpus 7・網羅性 1 の出力と分岐を削除する。Named の重複・移行専用の import と登録がゼロであることを rg と対象一覧で確認する。最終の件数と定理対応を確定する。
- 完了の条件・検査: K、`cargo test -p benitoite --test desugar_export`、`cargo test -p benitoite --test coverage_export`、`formal/` で `lake build`、`scripts/check-formal.sh`。六つの正式入口と全件の比較が通る。
- 依存: N34a。
- 注意: テストを弱めない。範囲内入力を削除せず、旧形式だけの独立した検査も必要な契約を新形式で保ってから消す。最小実行版の Core は残す。

### N35 版の記録・language 宣言・移行案内

- 目的: 一回の公開へ向けて互換性の境界と文書を揃える。
- 触るファイル: Cargo.toml・Cargo.lock の版の欄、`src/modules/package.rs` の BREAKING_CHANGES と関係するテスト、現行リファレンスの版、testdata・examples・docs・tools・Rust 文字列・生成器の現行 language 宣言、版検査の入力と期待値、公開の説明の準備文書。
- 手順: 設計者が決めた版で変更を一件記録する。E0907・E0908、language なしの新規則、旧版の案内を確認する。N1 の宣言一覧から、通常入力の旧版（testdata の 0.0.3 は grep で 46 ファイル候補）を決めた版へ更新する。未来の版・古い版そのものを検査するケースは目的ごとに変更し、E0907・E0908 と境界の期待を厳密に確認する。通常入力の観測結果と診断が版エラーに置き換わっていないことを再検査する。訳は N35a へ分ける。公開の説明をレビュー可能にし、タグと公開は行わない。
- 完了の条件・検査: K、`cargo test -p benitoite --lib modules::`、`cargo test -p benitoite --test package_command`、`cargo test -p benitoite --test golden`、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_docs`。版の表と文書が一致し、Skill に訳を混ぜない。
- 依存: N34b、設計者による版番号の決定。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。0.0.5 を未承認の既定値にしない。版が未決なら宣言の更新 patch と説明を先に完成し、版の適用を残る作業として明記する。

### N35a 最終の英語版から日本語訳を更新

- 目的: 最終の仕様・版・移行の案内を設計者の読む訳へ反映する。
- 触るファイル: `docs/ja/reference/`, `docs/ja/skill/`、訳の確認表。
- 手順: N35 の英語の最終版から訳し直す。名前・版・診断・例を英語と照合し、Skill の配布ディレクトリには訳を含めない。
- 完了の条件・検査: K、`cargo test -p benitoite --test reference_examples`、`cargo test -p benitoite --test skill_docs`、リンクとコード例の英日照合。
- 依存: N35。版が未決なら版に依存しない訳だけ先に準備し、確定後に適用・照合する。
- 注意: テストを弱めない。最小実行版の文書と過去の記録は変えない。英語を正とする。

### N36 全体の検査と公開前のレビュー

- 目的: 二段を一つの公開として完了できることを確認する。
- 触るファイル: 改造ディレクトリの結果・レビュー記録。修正が必要なら対応する実装・文書だけを変更する。
- 手順: manifest の変更・保留・除外を確定する。定理対応と差分の全範囲、暫定経路・名前空間の削除、Q と R の反映をレビューする。各作業の結果と未測定の事項を記す。
- 完了の条件・検査: K、`formal/` で `lake build`、`scripts/check-formal.sh`、`scripts/check.sh --full --dry-run` と `scripts/check.sh --full`。全体の検査は長いテストと release のスタックの検査を含むため、選択と時間を先に報告する。想定は数分〜数十分であり、手元の表示と直近の実績を優先する。
- 依存: N35a。
- 注意: テストを弱めない。既存の assert を消さず、期待値を緩めない。残る失敗を除外して完了にしない。修正後は関係する検査を再実行する。公開・TODO 更新・保管・コミットは今回の文書作成では行わない。

## 最終の成果物と今回との区別

実装の記録は、この改造ディレクトリに作業別の結果・テストの関門の回答・移行の確認表・形式化の定理の対応表・レビューの所見を置く。大きな生の出力はリポジトリ外へ置き、再現コマンドと要点を記録する。作業を取り込む際のコミットは、後の実装依頼に従って `git-workflow` を読む。今回はコミットしない。

N36 の完了後、設計者の公開の指示に従って一回だけリリースする。版番号の決定、TODO-247 を閉じる docs/todo の更新、改造ディレクトリの `git mv` による保管、タグとアーカイブは、それぞれの権限とリポジトリの手順に従う。これらを文書作成だけの今回の作業に混ぜない。N35 が版の決定を待つ場合も、N36 の版に依存しない検査と差分の確認は先に進められるが、公開前の全体検査は最終の版と訳でやり直す。
