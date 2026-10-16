# 実装プラン

## 目的と実行の単位

[design.md](design.md) と [decisions.md](decisions.md) に従い、準備 → 段 1 A → 段 2 D → 段 3 B2 → 移行・版・公開の整合の順で実装する計画である。今回の依頼では実装しない。Codex がメインの作業ディレクトリで一作業ずつ進め、各作業の後に san_benito へ取り込める状態にする。並行のエージェントへの分担や worktree の作業を前提にしない。

一作業の実装・差分確認は 30〜60 分を目安とする。ビルド・差分検査・所定のレビューの待ち時間は別である。ID は P（準備）、A、D、B、M を使い、後のレビューの修正のための Z は割り当てない。証明の試作前なので、目安を超える見込みの作業は枝番を付けた未接続の補助・補題の追加に分ける。クレートのコンパイル、関係する既存の検査、lake build を通せない中間状態では取り込まない。D2・D6・B10・B10a は元の ID を親の完了確認として残し、実装は枝番で行う。R13 の回答 B に対応する A4 を加え、以下は実装 48 作業と親の完了確認 4 件であり、親を独立の実装作業として数えない。G3 と G5 も親のまとまりを保ち、枝のレビューへ分ける。

作業の記録には、目的、実際に触ったファイル、test-audit の関門への回答、実行したコマンドと結果、仕様上の診断変更、保留・残る危険を記す。通常の検査が必要な manifest・独立入力は tests または formal/tests に置き、この改造ディレクトリや archive へ依存させない。

## 共通の関門 K

全作業で次を完了条件とする。各作業の「K」にこれらのコマンドを含めて記す。

1. `cargo test -p benitoite --lib`、`cargo clippy --workspace --all-targets`、`cargo fmt --all --check`、`git diff --check` が通る。文書・Lean だけの作業も、取り込み時に同じ構成で確認する。直前の検査後に Rust と入力の差がない場合、その同一ツリーでの結果を引用できる。
2. テストを弱めない。**既存の assert を消さない、期待値を緩めない**。skip/ignore・時間制限・対象外理由・対象内件数の下方修正で通さない。裸の try の成功・失敗の検査を減らさない。
3. テストを加える・変える前に test-audit の四問へ答える。主となる公開境界と捕まえる退行を記す。既存の表を拡張できる場合は別の重複テストを増やさない。退行の修正では修正前に意図した失敗を確認する。
4. 診断の仕様変更は、旧→新のコード・主文・help・主/副位置・終了状態・理由・元の誤りの検査の維持先を対応表へ残す。仕様上変わる期待値を厳密な新しい値へ合わせることと、比較を緩めることを区別する。golden を一括再生成しない。
5. 構文・型・脱糖・網羅性の内側に触る作業は、先行する Lean の定義と必要な証明・所定のレビューを済ませる。formal を変えた作業では `formal/` で `lake build`、`bash scripts/check-formal.sh` を通す。六入口の件数・対象外理由・破損入力の拒否を記録し、新しい axiom/sorry/admit/native_decide・定理の弱化を認めない。
6. 構文の章・標準ライブラリ・診断の表を変えたら、同じ作業で `cargo run -p benitoite --example gen_skill` を実行し、`cargo test -p benitoite --test skill_docs` を通す。生成物を手で直さない。仕様と 08-04 の例を変えたら `cargo test -p benitoite --test spec_examples`、英語リファレンスなら `--test reference_examples`、手書き Skill の例なら `--test skill_examples` も通す。
7. 取り込む前に `bash scripts/check.sh --base <直前の取り込み> --dry-run` を確認し、何を走らせるか設計者へ知らせる。選ばれた検査を実行する。段の終わりには下表の `--only` も必ず実行する。runtime/vm の変更で自動選択が long を含む場合は、先に約 15 分追加と報告する。軽い検査への切り替えを無断で行わない。分類不能の終了状態 3 は AGENTS.md に従って設計者へ実際のファイルと選択肢を示す。
8. 型と受け渡しの変更は design.md の変更表に限る。現在の仕様の章には実装済みの内容だけを反映する。Lean の先行変更と 01-12 の写し・07-04 は同じ変更で揃え、処理系がまだ使わない先行モデルであることを明記する。処理系へ接続した作業でこの注記を外す。

`--only rust` は単体テストだけではなく、mark-sweep/heap-verify の全体と gc-stress の lib/tests、lint、Skill の再生成を含む。長い ignore テスト・release_stack・Miri を含まないという意味で段末の軽い検査とする。実績がなければ数分〜十数分を見込み、dry-run と直近の実績で知らせる。重い形式化検査や全ターゲット検査とは並行させず、ランダム差分の既存の時間制限を守る。

## 作業とレビューの順序

記載順を実行順とし、依存欄は直接の前提を示す。それ以前の取り込みと必要なレビューも済んでいるものとする。Lean の定義・言明は、07-04 に従ってレビューを経て設計者と合意する。後続の大きいレビュー群まで規則のレビューを先送りしない。レビューは Codex の自己確認と具体的な差分・記録を前提にし、今回の文書作成から別のエージェントや外部の LLM を起動する権限は推測しない。

| レビュー | 作業（数） | 焦点と次へ進む条件 |
|---|---|---|
| G1 | P1・P2・A1〜A4（6） | 基準、R2 と型の変更範囲、35 語、名前の拒否、return の一般の改行規則・診断・24 行の移行・形式化の対象外、既存の整形 |
| G2 | D1・D2a〜D2c・D3・D4（6） | Coverage・表層の受理条件・証明・交換形式。D2 の完了を確認し、Rust の意味変更の前に定義と言明を確定 |
| G3a（G3 前半） | D5・D6a〜D6c（4） | view と診断、版の固定値、属性の受理。D6 の完了と parser 受理時からの判定を確認 |
| G3b（G3 後半） | D7〜D9（3） | 四型の指定と生成、入れ子・bind・選ばれない分岐の実行、全ターゲットと六入口。G3 を完了 |
| G4 | B1〜B5（5） | die の表層・型・脱糖・辞書・checker。定理の前提と結論、対象外の境界 |
| G5a（G5 前半） | B6〜B9・B10-1（5） | A4 の一般規則で終わる or return、報告の型、IR・liveness・VM/Direct。die は本番で未受理 |
| G5b（G5 後半） | B10-2・B10-3・B10a-1〜B10a-3（5） | Request の所有、Show、die の型・脱糖・交換を cfg(test) の入力でも確認。B10/B10a と G5 を完了 |
| G6 | B11〜B14（4） | die の一体接続、ハンドラ・タスク・解放・報告・test runner、文書、段末検査 |
| G7 | M1〜M5（5） | 移行器、現行の全サンプル、生成物、裸の検査の保持、移行の確認表 |
| G8 | M6・M6a・M7〜M9（5） | E0908 と TODO-252、R13 を含む 0.0.6 の移行と固定ハッシュ、日本語訳、公開前の検査と残件 |

| 段の終わり | `check.sh --only` で実行する名前 | 追加で実行するもの |
|---|---|---|
| A4 | `rust,spec_examples,reference_examples,skill,spec_coverage` | 既定構成と gc-mark-sweep,heap-verify の workspace all-targets（ignore を含めない）、移行した wit-transfer 6 ファイルの静的検査 |
| D9 | `rust,default_lib,spec_examples,skill,spec_coverage,formal` | 両構成の workspace all-targets、check-formal の六入口 |
| B14 | `rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,formal` | 両構成の workspace all-targets、check-formal の六入口 |
| M5 | `rust,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python` | 移行器の自己検査、skill_examples。skill_eval は自己検査だけ |
| M9 | 先に `rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python,formal,licenses` | 最終ツリーの check-formal、その後リリース前の `--full` |

両構成の all-targets は `cargo test --workspace --all-targets` と `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` を指す。前回 G8a で tests/runtime_builtins.rs の旧入力が通常の個別検査では漏れたため、各段で一度ずつ実行する。check.sh の python は現状 tools の固定の glob だけなので、M1/M2 で構文検査の glob・変更分類・自己検査の呼び出しへ新しい道具を登録する。それまでの各枝でも自己検査を明示的に実行する。

## 準備

### P1 基準と対象一覧の確定

- 目的: Q12 の範囲と Q6 の手本の線引きを固定する。
- 触るファイル: 今回の改造ディレクトリの基準・作業記録・移行候補の確認表。処理系は変更しない。
- 手順: HEAD・dirty 状態・study の入力ハッシュを照合する。四失敗型と String/不透明型の除外、既存の照合 6 件、追加分岐 0 件を再確認する。手本・標準ライブラリの実装（IO/File.bnt、Network/Http.bnt の裸の try は M4 で return）・検査・記法・歴史資料・生成元を分けた入力一覧と、裸の try の検査の基準を作る。前回 G1〜G8b の漏れをこの計画の関門に対応付ける。
- 完了の条件・検査: K。study の二つの Python を `python3 -B` で読み取り実行し、件数とハッシュの差を説明する。全サンプルと全ターゲットの入力を調べる対象一覧がある。
- 依存: 後の実装開始の指示。

### P2 型・依存・診断・形式化の事前確認

- 目的: 途中でインターフェースの変更範囲や import 循環が未決にならないようにする。
- 触るファイル: 改造ディレクトリの型の変更表・定理対応表・診断対応表。
- 手順: design の変更表を実際の構築箇所・呼び出し元へ対応付ける。Trait と IO.Process の内部依存、および四つの Show 実装の import を調べ、既存の暗黙の prelude と循環しない接続を具体的なモジュール列で示す。E0258/9・E0511・E0817 の未使用を再確認し、D/B の Lean の規則・言明の差分案を用意する。R2 を含む設計と型の変更範囲を実装開始時のレビュー対象にする。
- 完了の条件・検査: K。依存グラフ・型変更の全使用箇所・六入口・新コードの登録先が特定され、未記載の公開シグネチャ変更がない。
- 依存: P1。

## 段 1 A

### A1 die の字句と名前の拒否

- 目的: die を一語だけ予約し、既存の識別子の使用を保つ。
- 触るファイル: `src/syntax/{token,lexer,newline,lambda_bounds}.rs`、`syntax/lexer/tests.rs`、`syntax/parser/{mod,text,items,decls,types,exprs}.rs` と式・型・ラベルの入口、既存の lexer/parser テスト。
- 手順: TokenKind::KwDie と keyword/表示を追加する。`git grep -n KwTry -- crates/benitoite` の全件を下の確認表へ対応付ける。KwDie は newline::is_keyword に入れ、continues_after には入れない。語の近接・大文字・他言語風の案内の対照を既存表で検査する。処置を受理せず、help でも未受理の or die を勧めない。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --test golden`。変数・ラベル・ドットの後の die は E0216、extensible と既存の非予約語は名前として使える。非網羅の matches! の確認漏れがない。
- 依存: P2。

A1 の確認表は基準コミットの全 14 件である。開始時の再検索で増えた箇所も分類する。

| KwTry の箇所 | KwDie について行う確認 |
|---|---|
| syntax/token.rs:53、lexer.rs:785、lexer/tests.rs:933 | トークン・綴り・既存の語の表を追加 |
| newline.rs:161、224 | is_keyword に追加、continues_after には追加しない。KwReturn の一般規則の変更は A4 |
| lambda_bounds.rs:224 | 語と物理行の境界の分類に追加 |
| parser/decls.rs:138、types.rs:58、exprs.rs:297 | 名前/不適切な開始字句の非網羅の matches! を確認 |
| parser/text.rs:46、124 | 表示と keyword の綴りに追加 |
| parser/exprs.rs:80、246、effects.rs:427 | try の式・脱出の専用入口。単独の die の受理は追加しない |

### A2 整形と既存の診断の確認

- 目的: 予約語を含む誤入力と、有効な既存入力の整形の契約を確認する。
- 触るファイル: 必要な場合だけ formatter の roles/walk.rs・verify.rs と `tests/fmt_command.rs`、E0216 の既存表。新しいキーワード表や処置用の印字は加えない。
- 手順: formatter は parser の AST を使い、現状は独立のキーワード表を持たないことを確認する。予約語を名前にした入力の診断、Boolean or、識別子 fn の整形と再解析・冪等性を既存表で確認する。差分が不要ならその根拠と既存の検査結果を記録して完了とする。処置と説明の印字は B6/B10a-1 が担当する。
- 完了の条件・検査: K、`cargo test -p benitoite --lib cli::tools::formatter`、`cargo test -p benitoite --test fmt_command --test golden`。新たな診断の文言を変えた場合だけ gen_skill/skill_docs も行う。
- 依存: A1。

### A3 語の文書と生成物

- 目的: A の実装済みの規則と文書を揃え、統合入力の漏れを早く検出する。
- 触るファイル: 01-01・01-02 の語の説明、02-03、02-10、07-04 の字句の対象外、Skill の手書きの案内と生成物、作業記録。
- 手順: 35 語と文脈で読む語を反映する。新しい try が使えるとは書かない。残る B/D の文書案は改造のディレクトリに置く。return の一般の改行規則は A4 で実装と同時に反映する。
- 完了の条件・検査: K、`cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples`。語の分類と生成物が一致する。段末の検査と G1 の完了は A4 に置く。
- 依存: A2。

### A4 return の一般の改行規則・診断・既存入力の移行

- 目的: R13 の回答 B を普通の return から適用し、後の or return も同じ規則で終えられるようにする。
- 触るファイル: `syntax/newline.rs` と既存の表、`syntax/parser/exprs.rs` の parse_return と既存の構文検査、diag/codes.rs の E0201、formatter の既存の検査、design の 24 行を持つ `tools/bench/wit-transfer/` の 6 ファイル。01-01「改行による区切り」、01-02 の文・return・優先順位、02-03・02-10・06-03・07-04、英語リファレンス、Skill の SKILL.md・common-mistakes.md、`cli/tools/skill/generate.rs` と生成物、移行・診断の記録。
- 手順: 開始時に design の追加調査と P1 の全入力一覧を照合する。continues_after から KwReturn を外し、return 直後の改行は次行の continues_before と括弧内の改行省略に優先して NEWLINE にする。直前が or かによる分岐は加えない。parse_return は値を必須とするまま、直後が NEWLINE の E0201 に return_value_line の help と return の補足の位置を加え、次行を値に取り込まない。同じ行で値を書き始めた後の演算子・括弧・then の継続は保つ。24 行を `return if …` へ寄せる修正も同じ取り込みで行い、戻り値・uses・仕事量を変えない。newline の旧い正の入力 1 件を文末を期待する側へ移し、formatter の既存の負の入力は拒否を保つ。形式化の対象外として 07-04 に独立した行を追加する。Lean の型・脱糖・01-12 の規則は変えない。受理した規則と E0201 の案内を文書・Skill の生成元へ反映する。CHANGELOG と E0908 の本登録は M6/M7 に引き継ぐ。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --lib cli::tools::formatter`、`cargo test -p benitoite --test golden --test fmt_command --test spec_examples --test reference_examples --test skill_docs --test skill_examples`、gen_skill。下の表を既存の主となる検査で確認する。上表 A4 の段末の `check.sh --only`、両構成の all-targets、6 ファイルそれぞれの `benitoite check` を通す。外部の Wasm に依存する静的検査は `tools/bench/README.md` の WIT の受け渡しの入力の準備を先に確認し、性能測定や例の実行は行わない。G1 の差分・24 行と検査 1 件の対応表・結果を揃える。
- 依存: A3。

| A4 の改行の入力 | 確かめること |
|---|---|
| 普通の `return` の次行に値、演算子 `+`・`|>`、`(` | 文末にする。次行から値を始めず E0201 と同じ行の案内。コメント・空行・LF/CRLF、括弧の内外を対照にする |
| `return x +` の次行の値、`return (` の括弧内、`return f(` の引数、`return if condition then` の次行の分岐 | 値を同じ行で始めた後の従来の継続と、再解析・二度目の整形の一致を保つ |
| 値を書き始めた後のオペランド不足、既存の短い lambda の行越え | 別の誤りに return_value_line の help を付けない。既存の拒否・短い lambda の条件を維持する |

## 段 2 D（Lean を先行）

### D1 Coverage view と将来の形の準備

- 目的: 既存の定理を保ちながら将来の形の判定を定義する。
- 触るファイル: `formal/Benitoite/Release/Coverage.lean`、`CoverageShow.lean`、必要な補助補題、01-12・02-05 の手順の写し、07-04、定理対応表。
- 手順: 所定の規則・言明のレビューを先に行う。view、新しい Shape.future d と CoverageWitness.future d を含む shapes の補助、既知の構成子を失わない補題、将来の形の表示と DataName ごとの型名/record の表示表を追加する。既存の other と ConName ごとの表示表を維持する。まだ既存の呼び出しを切り替えず、既定の閉じた入力と同じ結果になることを示す。定義を先行追加した範囲と未接続を写しへ明記する。
- 完了の条件・検査: K、`formal/` で `lake build`、`bash scripts/check-formal.sh`。元の CtorsComplete と健全性の言明を保存し、将来の形を Wild のみで覆う独立例がある。
- 依存: A4 と G1。

### D2 網羅性の全検査と健全性の接続（親の完了確認）

D2a〜D2c の後に、網羅性・束縛・到達可能性が本体ごとの view を共有することを確認する。実装は以下の枝だけで行う。K・lake build・check-formal が通り、CtorsComplete と現在の値についての健全性・型保存の結論を維持すれば D2 を完了する。

### D2a Release の view 付き判定と健全性

- 目的: Surface の宣言表を変える前に、view 付き useful/checkMatch を証明する。
- 触るファイル: Release/Coverage.lean、Lemmas/CoverageRuntime.lean、必要な Release の補助補題、01-12・02-05・07-04。
- 手順: D1 の future の準備を使い useful/checkMatch/irrefutable と到達可能性を view 付きにする。既存の入口には閉じた view のラッパーを残し、Surface/Exchange はまだ旧入口でビルドできるようにする。将来の形の受理条件から、現在の値についての網羅性と到達不能の健全性を導く。予算の契約と既知の構成子を失わない条件を保つ。
- 完了の条件・検査: K、lake build、check-formal。view 付きの checkMatch_exhaustive_sound・irrefutable_sound・checkMatch_unreachable_sound と閉じた view の一致が通る。
- 依存: D1。

### D2b Declarations とソース照合の checker

- 目的: 既定の閉じた view を保ち、match/bind の追加条件を表層へ接続する。
- 触るファイル: Surface/{Syntax,Typing,Check,CheckPatterns,CheckPredicates,CheckLemmas,CheckTablesSound}.lean、CheckSound* と関係する補題、01-12・02-05・07-04。
- 手順: Declarations に既定値が閉じた view を加え、Exchange.Convert の既存の構築を壊さない。matchExhaustive/bindingExhaustive と型付け規則を view 付きにし、exhaustive_sound などから現在のコアの Exhaustive を導く。recordUpdateExhaustive/tryResultExhaustive/tryOptionExhaustive と getter の合成照合は閉じた view を明示する。patternProgram・関数/操作/型クラスの射影が view に依存しない補題を先に揃え、CheckLemmas/CheckTablesSound と checker の健全性へ使う。
- 完了の条件・検査: K、lake build、check-formal。閉じた既定で既存の Program/Exchange が通り、view 付きの match/bind と閉じた合成照合の独立例が区別される。
- 依存: D2a。

### D2c Program の本体ごとの宣言表と型保存

- 目的: 同じ型を作者/外部の複数の本体から検査できるようにする。
- 触るファイル: Surface/Syntax.lean の Program/declarations、Lemmas/Program.lean・Theorems.lean、CheckProgramSound.lean・CheckTablesSound.lean・CheckLemmas.lean と declarations を参照する全ファイル、01-12・07-04。
- 手順: `rg -n '\bdeclarations\b' formal/Benitoite/Surface` の参照一覧を記録し、Program の関数/実装メソッドごとの view と declarationsFor に切り替える。D2b の view に依存しない射影の補題を型保存・checker へ接続する。declarations は閉じた互換入口として維持し、D3 前の Exchange は閉じた既定で読む。
- 完了の条件・検査: K、lake build、check-formal。desugar_typed・プログラム全体の checker の前提と結論を保ち、同じ宣言で作者/外部を切り替えた例が通る。D2 の完了を確認する。60 分を超える見込みの証明は補題の枝番を追加する。
- 依存: D2b。

### D3 corpus 9 と型表・網羅性 3 の入口

- 目的: 属性と照合元の情報を独立した Lean の検査へ渡す。
- 触るファイル: `formal/Benitoite/Exchange/{Syntax,Convert,CheckInput}.lean`、CoverageDiff/CoverageProgramDiff、DesugarDiff/BuiltinCheck/SurfaceCheck の六入口、formal/tests/{test_width_exchange.py,test_named_exchange.py,width-exchange.json,named-exchange/} の固定入力・独立検査、必要な lake 登録、01-12・07-04。
- 手順: 新版の必須欄（DataName ごとの typeName/isRecord も含む）と旧版の閉じた既定を実装する。通常の width/named の固定入力は 9/3/3 へ更新する。旧版の閉じた正常入力は互換入口の正の検査、旧版に属性/view/型表示の新版の欄を混ぜた入力は独立した負の検査として残す。版が古いことだけを拒否理由にしない。作者/外部、入れ子、record、属性だけの型、指定を改ざんした入力を追加する。六入口が同じ view を読むことを確認し、新しい Python の検査を check-formal.sh からも走るようにする。旧版へ属性を付けた入力を黙って通さない。
- 完了の条件・検査: K、lake build、check-formal、交換形式の独立した正負の検査。既存の corpus 8 を壊さず、corpus 9 の同じ入力を全入口で比較できる。
- 依存: D2c と D2 の完了。

### D4 D の定義・言明と公理依存の確認

- 目的: Rust を変える前に形式化の契約を確定する。
- 触るファイル: 改造ディレクトリのレビュー記録・前提/結論/対象範囲の対応表。必要な修正は D1〜D3 のファイルに限る。
- 手順: 定義と言明を所定のレビューへ出す。view を渡す場所、record の合成照合とソース照合、将来の値を実行時へ追加していないことを確認する。変更した定義・定理と交換の定義も公理依存を調べ、古い保証との差を示す。
- 完了の条件・検査: K、lake build、check-formal。G2 を完了し、未解決の規則の指摘がなく、D5 以降の前提として使用できる。
- 依存: D3。

### D5 Rust の型表とパッケージの比較

- 目的: 属性を解釈する前に情報の通り道を用意する。
- 触るファイル: `src/types/mod.rs`、`typeck/decls.rs` とその子、`resolve/collect.rs` と出力の型・共通の比較、`ir/check.rs`、`ir/decision.rs`、types/mod.rs と typeck/patterns.rs 内を含む全 AdtDef の構築箇所、test/example/exporter、context.rs と Body::new の呼び出し元（traits/solve.rs も含む）。
- 手順: AdtDef.extensible を false で追加し、全構築箇所を更新する。same_package の判断を共通化し、現在の公開範囲の判定も同じ関数を使う。Body::new に本体の ModuleId を渡して保持し、内側の lambda/guard/lazy へ引き継ぐ（R12）。CoverageView の生成の補助を追加するが、属性の受理はまだ始めない。
- 完了の条件・検査: K、`cargo test -p benitoite --lib resolve::`、`cargo test -p benitoite --test package_command --test golden --test desugar_export`。既存の visibility と型表が同じ結果で通る。
- 依存: D4 と G2。

### D6 属性・Coverage・Rust の交換出力の一体接続（親の完了確認）

D6a〜D6c で判定・交換・受理を順に完成させる。属性を受理する取り込みから判定を必ず適用し、K・lake build・check-formal と六入口を通す。G3a で D6 の完了を確認してから D7 へ進む。

### D6a Rust の view・将来の形・診断

- 目的: 属性未受理のまま新しい網羅性を独立入力で検査する。
- 触るファイル: typeck/{patterns,pattern_ext}.rs と子、CoverageView の型と生成元、diag/codes.rs、tests/coverage_export.rs と公開の check_match/check_binding の全呼び出し元、02-05・01-12・07-04、Skill の生成物。
- 手順: Shape::Future(BindingId) と型名/record の表示、型の出どころを保持する反例を追加し、check_match/check_binding/covering と E0602/E0608 の全経路へ view を渡す。extensible=true を直接設定した型表で作者/外部・record・入れ子と help/副位置を検査する。coverage_export の 1 万件の乱択に extensible と view を加え、入れ子の将来の形も比較する。D3 の Lean との比較は網羅性 3 の独立入力で行い、通常の Rust の書き出しの版は D6b まで維持する。
- 完了の条件・検査: K、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test coverage_export --test golden`、lake build、check-formal、gen_skill/skill_docs。反例の表示文字列から型を逆解析せず、既存の Other の表示を保つ。
- 依存: D5。

### D6b Rust の corpus 9・型表 3・網羅性 3 の出力

- 目的: ソースで属性を受理する前に、通常の全出力と版の照合を揃える。
- 触るファイル: tests/desugar_export.rs の corpus の版、tests/desugar_export/{exchange,named}.rs、tests/coverage_export.rs、tests/desugar_export/{check_named.py,exchange-manifest.json}、必要な formal/tests の版照合、01-12・07-04。
- 手順: Rust の版 8/2/2 を 9/3/3 へ切り替え、check_named.py の width の版と出力文、manifest の namedVersions を同時に更新する。DataName ごとの表示名/record の印と view を全出力に加える。9/3/3 の必須欄として、型の `package`・`builtin`、`SurfaceDef` と定数の `package`、各網羅性 case/match/binding の `package` を出す。package は本体の宣言側のモジュールから求める（定数の使用側から求めない）。builtin は標準ライブラリの解決済み BindingId から Result を `"result"`、Option を `"option"`、ほかを `"ordinary"` とし、表示名から推測しない。corpus の dataTypes と型表の dataDecls は同じ宣言順から出す。coverageView は型の識別名 DataTypeInfo.name の一覧とし、extensible かつ本体と所属が異なる全型を含める。Lean の再計算との一致を要求する。外部の IOErrorKind 等を view から落とした入力、作者側へ余分に足した入力、Result・Option を extensible=true に変えた入力、所属・builtin の欠落、空/不足の dataTypes（desugarDiff を含む）、関数/メソッドの view の重複を負の入力に加え、意図した理由の拒否を確かめる。定数は外部参照可能だが match を書けないため、E_Const が使用側の view で検査する形式化との差を写しに明記する。外部パッケージの関数が IOErrorKind を照合し、直接設定した拡張指定が書き出した view に含まれる正の入力も加える。ソース由来の extensible は常に false とし、直接型表を作る乱択/独立入力では true も出す。D3 で更新した width/named の固定入力・新旧版の正負の検査と全六入口を照合する。
- 完了の条件・検査: K、`cargo test -p benitoite --test coverage_export --test desugar_export`、lake build、check-formal。check_named.py と manifest を含め版の決め打ちが現在の正常出力と一致し、旧版の負の検査の目的も保つ。
- 依存: D6a。

### D6c 属性の受理・E0817・仕様の接続

- 目的: 完成した判定へ属性を一度に接続する。
- 触るファイル: syntax/parser/items.rs と属性の検査、typeck/decls.rs、diag/codes.rs、testdata の属性の正負、01-02・01-05・02-05・01-12・07-04、Skill の生成物。
- 手順: @extensible と E0817 を加え、同じ取り込みで AdtDef と view へ指定を反映する。構成子の前の属性は解析せず E0201 を維持する（R11）。属性だけの宣言、data/record、引数/重複/位置、作者/外部の入力を確認し、受理した時点から新しい判定と全交換出力を使う。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test golden --test coverage_export --test desugar_export`、lake build、check-formal、gen_skill/skill_docs/spec_examples。新しい属性だけの入力も六入口へ残し、D6 と G3a を完了する。
- 依存: D6b。

### D7 四つの失敗型と表示用の宣言

- 目的: 設計者が指定した標準の全失敗型を拡張可能にする。
- 触るファイル: `prelude/stdlib/{IOErrorKind,NetworkErrorKind,Json,Csv}.bnt`、該当する API の設計書、`cli/tools/skill/{generate,tests}.rs`、06-06 の宣言抽出規則と生成物、組み込みソースの副位置を確認する golden。
- 手順: 四宣言へ属性を付ける。ParseError の record・getter・構築と更新の契約を維持する。既存照合の追加分岐 0 件という調査を実装で再確認し、必要なものが見つかれば本体を人が判断する。Result/Option や不透明型を変更しない。decl_head は public より前の @extensible だけを追加出力し、@builtin など他の属性は出さない。06-06 と生成器の検査を同時に直す。E0601/E0607 が標準ライブラリの宣言を副位置に持つ golden を各コードについて文章/JSON で確認する。
- 完了の条件・検査: K、`cargo test -p benitoite --test l21_json --test l23_csv --test l32_http_client --test package_command --test golden --test skill_docs`、gen_skill、spec_examples、check-formal。既存の結果・欄・WIT の対応は同じ。
- 依存: D6c、D6 と G3a の完了。

### D8 入れ子・束縛・到達可能性の検査の完成

- 目的: 最上位の match だけの実装になる漏れを防ぐ。
- 触るファイル: typeck の既存テスト、`testdata/` の型・名前・package・パターンのケース、coverage_export の独立入力、必要な D の本体修正。
- 手順: 同パッケージ/外部、別名型、Result.Error 内、リスト・record の欄、guard、選択肢、単一構成子の bind を表で確認する。record の getter/update を対照に置く。other の到達可能性と本物の重複、予算打ち切りも既存の主となる検査で確認する。新しい診断の副位置を厳密に比較する。全既知構成子 + case other を含むプログラムを golden で実行し、ir/decision.rs の count==0 の枝の省略、liveness、VM/refinterp、desugarDiff まで通ることを確認する。
- 完了の条件・検査: K、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test golden --test coverage_export --test desugar_export --test random_programs`、lake build、check-formal。属性により別の理由で拒否されて元の誤りが隠れたケースがない。
- 依存: D7。

### D9 D の文書・全ターゲット・段末検査

- 目的: D を単独で取り込める完成状態にする。
- 触るファイル: design の文書表の D に関係する章、英語リファレンス・Skill と生成物、段末の結果・照合一覧。
- 手順: 四型・R2 の record の制限・互換性・WIT の別契約を説明する。段末の全検査を一つずつ実行し、既存入力の診断・対象内件数・対象外理由を照合する。未接続の先行モデルという注記を外す。
- 完了の条件・検査: K、上表 D9 の `check.sh --only`、両構成の workspace all-targets、check-formal、`cargo test -p benitoite --test reference_examples --test skill_examples --test skill_docs --test spec_examples`。G3b と G3 全体の記録を揃える。
- 依存: D8。

## 段 3 B2（Lean を先行）

### B1 Lean の die の構文と脱糖の定義

- 目的: 新しい場合を直接モデルへ加え、既存の保証をビルドできる状態で保つ。
- 触るファイル: Surface/Syntax・Desugar・WellFormed と全構文を辿る関数、Scoped/ShiftClean/SubstClean などの補助、01-12・07-04。
- 手順: 所定の定義・言明のレビューを先に行う。Result/Option の新しい場合と、入力・説明・辞書・exit の参照、R3 の失敗側の展開を定義する。構文の全走査を実際の展開で実装する。この作業では新しい型付け規則と checker の受理をまだ加えない。既存の型の付いた入力についての証明は維持し、未受理の枝を todo やダミーのコアで埋めない。
- 完了の条件・検査: K、lake build、check-formal。既存の全場合と新しい脱糖の定義の独立例が通る。書き出し器と Rust は従来どおり。
- 依存: D9 と G3。

### B2 die の型規則と性質 1

- 目的: 型・エフェクトと脱糖の型保存を証明してから処理系へ使う。
- 触るファイル: Surface/Typing、Lemmas/ReturnTry・Typing・Scoped*・Invariants・Extensions*、Theorems、01-12・07-04。
- 手順: 純粋な説明と Show、任意の R、T と Process.Exit の規則を追加する。同じ作業で新しい場合の型保存と必要な範囲・置換の補題を完成させる。Return の既存の規則は変えない。説明式の R=None と継続の隠蔽、lambda の新しい境界も確認する。
- 完了の条件・検査: K、lake build、check-formal。desugar_typed・surface_effect_soundness と従来の最終定理の前提/結論を維持する。Show がない型の伝播を拒否する条件は加えない。
- 依存: B1。

### B3 die の表層検査と健全性

- 目的: Rust が渡す型と辞書を Lean の checker 自身で確認する。
- 触るファイル: Surface/Check・CheckPredicates・CheckSoundControl・CheckInduction・CheckProgramSound と関係する補題、CheckExamples/Counterexamples、01-12・07-04。
- 手順: B2 の条件を判定し、checker の成功から型付けを導く。説明が不純、表示の型/辞書が違う、exit のエフェクトがない入力を個別に拒否する。プログラム全体と信頼表付きの保証、実装メソッドの名前一致の結論を維持する。
- 完了の条件・検査: K、lake build、check-formal。成功とそれぞれ一条件だけ壊した入力で意図した拒否を確認する。R の一致を die に要求しない。
- 依存: B2。

### B4 corpus 10 と六入口の接続

- 目的: 新しい try の情報を交換で失わせない。
- 触るファイル: Exchange/Syntax・Convert・CheckInput・Builtins、全 Expr の lambdaEffects などの走査、六つの Main と SurfaceCheck/All、formal/tests/{test_width_exchange.py,test_named_exchange.py,width-exchange.json,named-exchange/} の JSON・交換形式の検査、01-12・07-04。
- 手順: 処置・辞書・説明・exit の参照を必須として読める corpus 10 を加える。corpus 9 は die のない旧入力だけ受理する。裸と明示 return の同じ規則への変換、新しい try だけの独立入力、局所名と標準束縛の衝突、Show の辞書名の保持を確認する。新しい自己検査を check-formal に接続する。test_width_exchange.py の正常入力の corpus は 10、型表/網羅性は 3 に更新する。test_named_exchange.py の旧版 7/1 への書き換えは、新版専用の欄を旧版に入れた拒否の検査として明示し、単なる旧版拒否の検査にしない。named-exchange の正常な固定入力は 10/3/3、旧版の閉じた正の入力は互換入口として別に保つ。
- 完了の条件・検査: K、lake build、check-formal。六入口の独立した正負の比較、必須欄欠落と旧版の拒否が通る。
- 依存: B3。

### B5 B2 の定義・言明と対象範囲の確認

- 目的: 実行の実装へ進む前に証明の保証の範囲を確定する。
- 触るファイル: レビュー記録・定理対応表・必要な B1〜B4 の修正。
- 手順: 所定のレビューで E と Show、R と T、失敗側の評価順の定義、既存 exit への対応を確認する。型保存と実行順・報告の一回性を混同していないか確かめる。全定義と定理の公理依存も検査する。01-12 の元の規則をその場で直し、矛盾する旧い規則を末尾の追記で上書きしない。
- 完了の条件・検査: K、lake build、check-formal。G4 を完了し、Rust の die を対象外にする必要がない。
- 依存: B4。

### B6 明示 return の AST・一般の改行規則との接続と全走査

- 目的: 裸の try を保ったまま、明示 return を複数行でも正しく受理する。
- 触るファイル: syntax/ast.rs・parser/{exprs,effects}.rs・newline.rs、下の Try の確認表の全ファイル、formatter の役割/印字/検証、02-03・01-01・01-02・01-09、Skill 生成物。
- 手順: TryAction の ImplicitReturn/Return と TryExpr.action を追加し、従来の構築箇所は ImplicitReturn にする。Die の場合は B10a-1 で加える（R14）。or return の後も A4 の return の一般規則で改行を文末にし、or 専用の例外は追加しない（R13 の回答 B）。処置は parse_return を呼ばず値を要求しないため、A4 の値欠落の E0201/help を出さない。次行の演算子を取り込まないこと、通常の値を同じ行で始めた return と or の前後の継続を保つことを確認する。die は continues_after に加えず、Die と説明の閉じ括弧の文末は B10a-1/B11 で確認する。全構築・走査を確認表に対応付け、value/action を明示的に分解する。本番用の E0258/9 の help はこの時点で使える return だけを案内し、die の案内は B11 の受理と同時に有効にする。全 Expr の列挙だけの箇所も、走査・拒否・終端の分類を記録する。裸/明示の formatter の保持を接続する。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test fmt_command --test golden --test desugar_export`、gen_skill/spec_examples、check-formal。裸と明示 return の型・コア・実行が同じ。次の改行表の正負が受理と同時に通る。
- 依存: B5 と G4、return の一般規則は A4 と G1 で完了済み。

| 改行の入力 | 確かめること |
|---|---|
| `bind x <- try r or return` の次に bind/式/括弧で始まる式 | 次の文を取り込まない。空行の有無・LF/CRLF を対照にする |
| try の入力と or の間、or と return の間の改行・コメント | 未完の処置を継続し、return の後だけ文が終わる |
| 通常の `return` の次の行の値 / 値を同じ行で始めた複数行の return | 前者は A4 の E0201、後者は従来の継続を保つ |
| 括弧内の `try r or return` の直後の改行 | A4 の一般規則で文末。コンマ/閉じ括弧は処置と同じ行に置く。`or return,` の後の改行や、return 直後以外の通常の括弧内の改行省略は保つ |
| 同じ行の `or return extra` | E0258。次の文へ逃がさない |
| `or die` の次の行の `(`、短い lambda 内の改行 | B10a-1 のテスト入口と B11 の本番入口で、説明へ取り込まないことと E0254 を確認 |

B6 の Try の確認表は `git grep -n -E 'Expr::Try|TryExpr' -- crates/benitoite` の基準時点の全件を以下のファイル単位でまとめたものである。開始時と Die の追加時に再検索し、全位置へ対応を残す。

| ファイル・箇所 | 担当する確認 |
|---|---|
| syntax/ast.rs、parser/{effects,exprs,mod,traits}.rs | 構築、id/span、再帰する走査と文脈の拒否を区別 |
| resolve/walk.rs、formatter/roles/walk.rs、runtime/assert.rs | value と action を分解。Die を追加する B10a-1 で説明も走査 |
| typeck/{consts,generate,infer,tests}.rs、effects/{mod,tail,tests}.rs、traits/tests.rs | 制約・到達・const の拒否・テストの走査。tail の escape は Return=true、Die は value/message を辿り、tail_expr は false |
| ir/desugar/{effects,exprs}.rs、tests/desugar_export/exchange.rs | Return の意味を維持。Die の生成は B10a-2、出力は B10a-3 |
| tests/random_programs/shrink.rs | 入力と説明の縮小候補を落とさない |
| examples/named_arguments_inventory.rs、examples/named_inventory/index.rs | 説明の中の関数の契約・参照も収集する |

B10a-1 はこの全表を再点検して Die の説明を接続する。const の許可判定は従来どおり全 try を拒否し、参照の収集や式の訪問では説明も辿る。欄追加だけでコンパイラが漏れを知らせるとは仮定しない。

### B7 or の境界・改行・診断・整形

- 目的: 明示処置で外側の式とブロックの境界を奪わない。
- 触るファイル: `syntax/parser/{exprs,mod,text}.rs`、newline/lambda_bounds、formatter/verify、diag/codes、parser/formatter の既存の表、fmt の golden、01-02・06-03、生成物。
- 手順: 同じ深さの停止条件、内側の try の優先、明示形の後の E0258/9 を完成する。or return の境界と診断を完成し、die の AST とテスト時の解析は B10a-1 に置く。本番の受理は B11 まで止める。then/do/case/end、内側の guard、括弧とコンマ、Boolean or、CRLF・補間・短い lambda の物理行を確認する。E0254 の help を別の未完の演算子の誤りへ付けない。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --lib cli::tools::formatter`、`cargo test -p benitoite --test fmt_command --test golden --test spec_examples --test skill_docs`、check-formal。再解析と冪等性が通り、外側の or の処置を E0259 にしない。
- 依存: B6。

### B8 終了結果・CLI・test runner の報告の型

- 目的: die の情報を保持・表示する受け渡しを先に用意する。
- 触るファイル: runtime/run の RunEnd、vm の停止結果・要求、runtime/report、diag の ReportKind・render と text、cli/mod、test_runner/mod・report、全 RunEnd の構築箇所、06-01・06-04。
- 手順: DieFailure と任意の結果欄を追加し、現在の経路は None を入れる。CLI と test runner の描画・JSON を追加する。main_error と通常の exit、Internal/Interrupt、flush と解放の補足の分類を維持する。構造化した DieFailure を報告の描画入口へ直接渡す lib の検査で文章/JSON・任意の説明を確かめる（R14）。CLI の共有の描画処理は die→reports の順にする（R18）。この段階で本物のソースの die を CLI/test runner から検査したとは記録せず、受理からの一貫した検査は B11/B12 に置く。
- 完了の条件・検査: K、`cargo test -p benitoite --lib runtime::report`、`cargo test -p benitoite --test cli_process --test test_command`、関係する runtime/run の lib テスト。既存の報告と終了状態の期待がすべて維持される。
- 依存: B7。

### B9 内部の報告引数を IR とバイトコードへ保持

- 目的: 原因と説明がレジスタ割当や GC の生存判定で失われないようにする。
- 触るファイル: core_ir/lower_ir、IR check・lowering と置換/変数列挙、bytecode/program・codegen・liveness・verify・disasm、refinterp の App の入口、必要な各層の既存テスト、02-06・02-07。
- 手順: App の任意の exit_report と命令位置の表を追加する。通常の App は None とし、標準 exit かつ code=1 の String の参照だけを許す。値の使用、レジスタ・捕捉・命令の対応と検証を接続する。refinterp も同じ情報を扱える準備をする。
- 完了の条件・検査: K、`cargo test -p benitoite --lib bytecode::`、`cargo test -p benitoite --test desugar_export --test random_programs`、lake build、check-formal。通常の bytecode と全件の意味は同じ。内部情報を持つ独立した正負の IR/bytecode で型・範囲・生存を確認する。
- 依存: B8。

### B10 VM/IO の呼び出し単位の保持と Show 実装（親の完了確認）

B10-1〜B10-3 で実行の所有と四型の Show を分ける。通常の exit と既存の表示を保ち、K・check-formal と両 IO 方式の対照を通して B10 を完了する。TryInfo・型の解決順・脱糖の持ち主は B10a の枝とし、ここでは実装しない。

### B10-1 VM/Direct と参照インタプリタの保持

- 目的: 既定の終了へ進む呼び出しにだけ所有した報告を付ける。
- 触るファイル: vm/{dispatch,handlers,state} と停止結果、Direct の実行、refinterp、02-08・02-11。
- 手順: B9 の内部の引数を、言語のハンドラで処理されず既定の exit へ進む時点で所有した String にする。通常の公開引数は code 一つのまま、処理・再開・破棄のときは報告を持ち越さない。Direct と refinterp の独立した内部 IR/bytecode の入力で確認する。Request の新しい報告付き入力は B10-2 まで検査対象にせず、未接続なら内部エラーで拒否して通常の Request を保つ。本番 parser はまだ die を受理しない。
- 完了の条件・検査: K、vm/refinterp の関係する lib テスト、`cargo test -p benitoite --test runtime_builtins --test random_programs`、check-formal。Direct と refinterp の所有・ハンドラ処理後の破棄・後の独立 exit の対照が通る。G5a を完了する。
- 依存: B9。

### B10-2 Request/IO と停止結果への採用

- 目的: 非同期の要求・取り消し・競合停止でも別の終了へ理由を混ぜない。
- 触るファイル: runtime/io・sched・run、要求/応答と停止の採用箇所、VM の Request の引き渡し、02-08・02-11。
- 手順: RequestId ごとに所有した報告を保持し、完了・取り消しとともに解放する。採用した Exit だけへ移し、Internal/Interrupt や競合した別の終了へ転記しない。B10-1 の Request の暫定拒否を除き、Direct と同じ意味に揃える。大域の一時情報とヒープ外の Value は使わない。
- 完了の条件・検査: K、関係する vm/runtime の lib テスト、`cargo test -p benitoite --test runtime_builtins --test random_programs`、check-formal。両 IO 方式で報告付き/通常の exit、処理・再入・取り消し・停止の採用の対照が通る。
- 依存: B10-1 と G5a。

### B10-3 四型の標準 Show と依存

- 目的: 標準の失敗値を直接表示できるようにする。
- 触るファイル: stdlib/{IOError,NetworkError,Json,Csv}.bnt、modules の必要な依存の接続、03-06・03-07・03-08、Skill の生成物、作業記録。
- 手順: 四型のモジュール内で Trait.Show を実装し、message を返す。実装の引数名 x・孤児規則・循環の拒否を保つ。IOError/NetworkError の prelude から Trait が常時読み込まれる影響は benchmark スキルに従い、同じ最小の起動/検査入力で変更前後を短く測り記録する。die の構文からの内部依存の検出は B10a-1 の担当とする。
- 完了の条件・検査: K、`cargo test -p benitoite --test runtime_builtins --test l21_json --test l23_csv --test golden`、gen_skill/skill_docs、check-formal。四型の表示と import 依存が通り、起動の測定条件と結果を記録し B10 を完了する。
- 依存: B10-2。

### B10a die の型・辞書・脱糖と交換出力の準備（親の完了確認）

B10a-1〜B10a-3 で本番受理前に各分岐を完成させる。cfg(test) の入口以外は die を作らず、CLI の受理は B11 に限定する（R14）。型検査・脱糖・交換の実装の持ち主を以下の枝に分け、すべての証拠と G5b が揃ってから B10a/G5 を完了する。

### B10a-1 die の AST・テスト入口・型と辞書

この枝は formatter の役割・印字・検証と typeck/test_support.rs も更新する。die と説明を保持し、テスト時の共通の parser で再解析・冪等性を確かめる。未接続の交換出力も Die を明示的に拒否し、B10a-3 でその暫定処理を除く。Return として出力したり説明を黙って落としたりしない。

先行する lib の検査では、通常の読み込みで標準モジュールを揃えた LoadOutput に対し、対象ソースを同じ SourceMap/IdGen へ登録して cfg(test) の入口で解析し、対象 AST を差し替えて公開の resolve/typecheck/desugar を呼ぶ。準備用の fixture の import と die による内部依存の自動追加を混同しない。内部依存の抽出・循環の共通の処理は解析済み AST から検査し、import のない本番ソースの一貫した読み込みは B11 で確認する。テスト専用の本番のローダ API は増やさない。

- 目的: die の型と説明の検査を本番の構文解放前に検証する。
- 触るファイル: syntax/ast.rs、parser/{mod,effects,exprs,text}.rs と test_support、B6 の Try の全確認表、modules の内部依存/cycle、resolve/walk、typeck/{mod,context,infer,effects,special,traits,solve} と子、diag/codes.rs、02-03〜02-05、Skill の生成物。
- 手順: TryAction::Die を加え、B6 の確認表にある全走査で value/message を辿る。処置の解析本体は共通とし、本番では Die を拒否、cfg(test) のクレート内部の補助だけ受理できるようにする。新しい本番フラグ/公開 API は加えない。modules の内部依存と循環、説明の名前解決を接続し、TryInfo の Return/Die・入力の確定→Show 制約→辞書→確定表の順を実装する。説明の純粋性を E0511、直接の return/try を EscapeContext::InDieMessage と E0218、resume を継続を隠した型文脈と E0509 で検査し、両者へ die_message の help を加える（R15）。Return の全構築箇所も更新する。脱糖の未接続の Die だけは InternalError で拒否し、B10a-2 で除く。
- 完了の条件・検査: K、`cargo test -p benitoite --lib syntax::`、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test golden --test fmt_command`、gen_skill/skill_docs、lake build、check-formal。cfg(test) の parser から resolve/typeck を通す lib の入力で Result/Option・任意の戻り値・Show の有無・uses・純粋性・escape・名前の衝突を確認する。const の拒否と tail の区別も確認する。本番入口の拒否と Return の意味を保つ。
- 依存: B10-3 と B10 の完了。

### B10a-2 die の脱糖と内部 IR への接続

- 目的: 型付き Die から、失敗側だけで説明→Show→exit を生成する。
- 触るファイル: ir/desugar/{effects,exprs}.rs・IR check、必要な refinterp の接続、lib の脱糖/コアの検査、02-06。
- 手順: B10a-1 の暫定の InternalError を除き、確定した TryInfo を使って B9 の exit_report 付き App を生成する。説明・Show の各 let を失敗側に一つだけ作り、成功側で呼ばない。型・辞書の解決は B10a-1 の責務として再実装しない。cfg(test) の同じ解析入口から型・脱糖・core check を通し、独立の期待コアと比較する。
- 完了の条件・検査: K、該当する ir/refinterp の lib テスト、`cargo test -p benitoite --test desugar_export --test random_programs --test golden`、lake build、check-formal。lib では Die の Result/Option の型・評価順・一回性を直接確認し、通常の統合入力では既存の Return を維持する。
- 依存: B10a-1。

### B10a-3 corpus 10 の書き出しと独立入力

- 目的: 本番受理前に型付き Die の交換情報を検査可能にする。
- 触るファイル: tests/desugar_export.rs と tests/desugar_export/{exchange,named}.rs・check_named.py、exchange-manifest.json、tests/coverage_export.rs の corpus を含む出力、formal/tests の独立入力、01-12・07-04。
- 手順: Return/Die・辞書・説明・exit を出力し、通常の全出力の corpus を 10 へ切り替える。型表/網羅性は 3 を保ち、manifest の namedVersions、check_named.py の width の版と出力文を揃える。本番 parser がまだ作らない Die は、B4 の独立した JSON と cfg(test) の型/コアの観測を照合する。integration test のために本番の parser に裏口を作らない。ソース→Rust 出力→Lean の一貫した Die の比較は B11 で初めて確認する。
- 完了の条件・検査: K、`cargo test -p benitoite --test desugar_export --test coverage_export --test golden`、lake build、check-formal。Rust の書き出しのテストまたは `test_try_exchange.py` で、die の `dict` のクラスの識別名と `showMethod` が、stdlib の型表の `Trait.Show` とそのメソッドの BindingId から作った識別名に一致し、`exit` が組み込みの表の `Process.exit` であることを照合する（G4 の L5）。六入口の通常出力と独立した Die の正負の入力が通り、B10a/G5b と G5 を完了する。
- 依存: B10a-2。

### B11 die の本番受理と全経路の一体接続

- 目的: 完成した型・脱糖・実行を、ソースの本番の受理から確認する。
- 触るファイル: parser の処置の受理、diag/codes.rs の E0501 と既存のエフェクト不足の報告箇所、ソースからの golden/CLI/test runner/六入口の比較入力、01-02・01-06〜01-09・02-04〜02-06・07-04、Skill の生成物。
- 手順: B10a-1 の共通の parser の Die の受理を本番でも有効にし、E0201/E0258/9 の help に die の案内を追加する。TryInfo・辞書の解決・IR の生成は B10a の完成した実装を使い、再実装しない。E0501 の die の help は uses Process.Exit と `import Benitoite.Unofficial.IO.Process` の両方を案内する。既に別名で import している場合はその別名を使う。B8 の報告と B10 の実行を本物のソース入力で確認し、corpus 10 のソース→Rust の型付き表層/コア→Lean の六入口を比較する。受理した規則だけを現行文書へ反映し、テスト入口と本番の差が解消したことを記録する。
- 注意（G5a 指摘7）: `try r or return die` には die を案内する help を加え、parser の診断の表に一行追加する。`[x]`・`-1` と型適用・二項演算の区別は今回変えない。
- 完了の条件・検査: K、`cargo test -p benitoite --lib typeck::`、`cargo test -p benitoite --test golden --test desugar_export --test random_programs --test fmt_command --test cli_process --test test_command`、lake build、check-formal、gen_skill/skill_docs/spec_examples。Result/Option の成功と失敗、任意の戻り値、Show/uses の有無、import の案内、複数行/説明の括弧をソースの公開入口から確認する。
- 依存: B10a-3、B10a と G5 の完了。

### B12 終了・順序・ハンドラ・テスト実行の確認

- 目的: 型保存で扱わない実行上の契約を確かめる。
- 注意（G5a 指摘8・R70）: test runner の文章では die のとき「called `Process.exit` with status 1」の行を省き、die の報告を先に出す。通常の exit と JSON は保ち、本物のソースの統合検査と 06-04 に反映する。
- 触るファイル: runtime/run・vm・refinterp の持ち主の検査、CLI の run/test の統合検査、必要な golden と B11 の修正。
- 手順: 入力一回を State の観測で、成功時の説明/Show の未評価と説明→Show の順を異なる純粋な停止理由の対照で確認する。説明/Show の一回性は、結果だけでは純粋な重複評価を区別できないため、独立した期待コアの失敗側の let の個数・配置でも確認する。String の引用符、None の固定原因、空/無しの説明を比較する。Process.Exit の処理・再開・再入・後の独立 exit、子タスク・解放・flush の失敗・競合停止、二つの IO 方式を確認する。die のテストの後に成功テストが実行され、報告が一度であることを確認する。CLI の文章/JSON で die の後に解放/flush の reports が順に出て、状態 1 が保たれることを本物の実行入力で比較する。
- 完了の条件・検査: K、該当 runtime/vm/refinterp の lib テスト、`cargo test -p benitoite --test golden --test test_command --test random_programs`、check-formal。観測する契約と既存の終了テストとの分担を記録し、新しいフラグや公開 API をテストのためだけに足さない。R14 の cfg(test) のクレート内部の解析補助だけを限定的な例外とし、CLI/test runner の統合検査は本番の入口を使う。
- 依存: B11。

### B13 try・Show・終了の現行文書と生成物

- 目的: 実装した B2 の現在の使い方と保証を揃える。
- 触るファイル: design の B2 の文書表にある全章、英語リファレンスと Skill の手書き文書、gen_skill の生成元と出力。
- 手順: 裸の意味の固定、任意の戻り値・Process.Exit、Show、終了結果、ハンドラの処理、外の保証を説明する。`docs/reference/benitoite.md` の標準クラスの説明に、IOError・NetworkError・Json.ParseError・Csv.ParseError の Show と、各 message の文字列をそのまま返すことを加える。新たに書くサンプルは最初から明示形にする。全既存例の移行は M1〜M5 で一覧に基づいて完成する。先行モデルの注記を外す。
- 完了の条件・検査: K、gen_skill、`cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples`。新しい文法・診断・標準宣言が生成物と一致する。
- 依存: B12。

### B14 B2 の全ターゲットと段末検査

- 目的: 入力の埋め込みや一部の構成だけで起きる失敗を残さない。
- 触るファイル: 段末の記録。失敗があれば持ち主の実装と必要な入力だけ。
- 手順: 上表 B14 の検査を順に行う。RuntimeError や E0908 など別の理由へ付け替わった負の入力を確認する。Rust の通常/生成入力、六入口の対象内件数、報告の所有と生存を照合する。
- 完了の条件・検査: K、上表の `check.sh --only`、両構成の all-targets、check-formal。G6 を完了する。残る失敗を対象外にして進まない。
- 依存: B13。

## 最後の移行・版・公開の整合

### M1 ホスト抽出と安全な適用の再利用

- 目的: 旧い移行基準へ依存せず、確認できる差分を出す共通部分を作る。
- 触るファイル: `tools/source-migrate/`（新設）、`tools/named-arguments-migrate/{extract,migrate,test_migrate}.py` の共通部分を使う接続、新しい道具の README、AGENTS.md のディレクトリ表、scripts/check.sh の Python の構文検査・変更分類・自己検査の実行箇所。
- 手順: ホストの復号・元バイト位置・ハッシュ・全範囲の検証・diff・再適用の機能だけを共通化する。前回の候補の意味判定と BASE は旧入口へ残し、今回へ読ませない。旧 CLI とテストの結果を保つ。source-migrate を AGENTS.md に登録し、check.sh の Python の構文検査の glob と変更分類へ追加する。共通部分の自己検査も通常の検査から呼び、明示的な自己検査のコマンドを README に残す。
- 完了の条件・検査: K、`python3 -B tools/named-arguments-migrate/test_migrate.py` と新しい共通部分の自己検査。既存の assert を残し、入力へ勝手に適用しない。
- 依存: B14 と G6。

### M2 try の候補・確認表・diff の出力

- 目的: Q6 の全サンプルの選択をレビューできる形にする。
- 触るファイル: `tools/try-actions-migrate/`、`crates/benitoite/examples/try_actions_inventory.rs`（新設）、確認用 manifest/review の出力仕様、AGENTS.md のディレクトリ表、scripts/check.sh の Python の構文検査・変更分類・自己検査の実行箇所。
- 手順: AST から Try の範囲と処置を読み、R1 の分類と die/return の提案を出す。複数行・inline・補間・Rust のエスケープを扱う。自動で決められない説明・生成断片・負の入力・契約変更は保留する。適用には確認済み manifest のハッシュを要求する。Kind の分岐の本体と期待値は生成しない。try-actions-migrate も AGENTS.md、check.sh の glob・変更分類・自己検査へ登録する。
- 完了の条件・検査: K、`cargo build -p benitoite --example try_actions_inventory`、`python3 -B tools/try-actions-migrate/test_migrate.py`。本物の parser と道具の入口で正しい operand 末尾、保留、ハッシュ不一致の拒否、再適用の差分なしを確認する。
- 依存: M1。

### M3 設計書・英語リファレンス・Skill の全サンプル

- 目的: 人と LLM が手本として読む文書のソースをすべて明示形にする。
- 触るファイル: docs/design の全章と 08-04、docs/reference、Skill の SKILL.md と手書き references、診断の修正例の生成元、確認済み manifest。
- 手順: 道具の候補と保留を一件ずつ確認して適用する。main/一回限りは die、再利用は return を基本に契約を確認する。使う API の一覧・インラインの実行例・複数行も確認する。構文名の裸の表記と移行前の引用は役割を記録して残す。E0201 question の修正例を R1 の `try parse(text) or return` へ変更し、lexical/unknown_symbol.diag.json と diag/render/help_tests.rs の期待を厳密に揃える。仕様例の検査を通すためにコードブロックを別の言語指定へ逃がさない。
- 完了の条件・検査: K、`cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test golden`、gen_skill。全候補が変更/保持理由/保留へ対応し、現行サンプルの未確認はゼロ。量が多ければ M3a（仕様と付録）・M3b（その他設計書）・M3c（reference/Skill）へ分け、各枝で検査を通す。
- 依存: M2。

### M4 実行例・例を作るソース・現在の tools

- 目的: 文書以外の手本と生成元の移行漏れをなくす。
- 触るファイル: examples の .bnt と Rust が作る例、tools/bench の現行入力・README、tools/skill-eval の現行参照解・README、その他の手本、stdlib/IO/File.bnt・Network/Http.bnt など再利用するライブラリ実装、manifest。
- 手順: R1 の線引きで処置を適用し、標準ライブラリの裸の try は戻り値・uses・失敗値を保って or return にする。標準ライブラリを変えた同じ作業で gen_skill/skill_docs を通す。ベンチマークは同じ戻り値・仕事量を保つ return を選び、測定結果は改めない。R13 の wit-transfer 24 行の書き直しは A4 で完了済みとして確認し、ここへ先送りしない。skill-eval は参照解の静的検査と自己検査だけを行い、LLM を呼ばない。Rust の test 入力と生成器は一律移行せず、手本として出力するものだけを区別する。
- 完了の条件・検査: K、`cargo test -p benitoite --test golden --test random_programs`、gen_skill/skill_docs、対象を列挙した `benitoite check`、`python3 tools/skill-eval/skill_eval.py --self-test`。副作用を伴う例の実行・性能測定を勝手に始めない。対象一覧と変更理由が一致する。
- 依存: M3。

### M5 生成物・裸の検査の保持・移行の段末検査

- 目的: 全手本の明示化と裸の互換性を同時に確認する。
- 触るファイル: Skill の生成元と生成物・bundle、移行の照合表・診断変更表・作業記録。
- 手順: gen_skill を実行し、二度目の出力が安定することを確認する。P1 の裸の検査の一覧と現在を照合し、入力・assert・観測の保証が減っていないことを示す。手本/記法/移行前/検査/歴史資料の保持理由と全保留を確定する。移行ツールの通常の検査から改造の文書への依存がないことも確認する。
- 完了の条件・検査: K、上表 M5 の `check.sh --only`、`cargo test -p benitoite --test skill_examples --test golden --test desugar_export`、新旧の移行器の自己検査。G7 の確認表を完成する。
- 依存: M4。

### M6 E0908 の変更ごとの help（TODO-252）

- 目的: 複数の破壊的変更を宣言版から漏れなく案内する。
- 触るファイル: `modules/package.rs`、modules/text、diag/codes、modules/tests.rs と modules/package.rs の版検査、testdata/packages/older-language.diag.json、gen_skill の生成物、06-09・02-10、CHANGELOG の準備文。
- 手順: BreakingChange.help を追加し、declared < change <= current の全項目を版順で notes/help へ出す。主文と位置を DiagBuilder で build した後、Diagnostic.notes/helps へ modules::text の項目ごとの文と置換なしの Help を追加する（R17）。共有の引数の上書きによる note/help の繰り返しは使わない。既存の 0.0.5 を保ち、注入した版の表で 0.0.6 を含む境界を検査する。0.0.6 の案内には die の予約・四型の属性に加え、R13 の値を return と同じ行で書き始める移行と、その後の複数行は可能であることを含める。本物の 0.0.6 の登録と crate の版の変更は M7 まで行わない。E0908 の固定 migrate の help と change の note を除き、earliest の説明は主文の最初の版と全項目の案内を区別する文に直す。一件固定の lib/golden の検査を選ばれた項目の全文・順の厳密な比較へ直す。
- 完了の条件・検査: K、`cargo test -p benitoite --lib modules::`、`cargo test -p benitoite --test package_command --test golden --test skill_docs`、gen_skill。0.0.4 以下→2 件、0.0.5→1 件、現在版→0 件、未来→E0907 の境界を、current を注入した既存の検査で厳密に確認する。
- 依存: M5 と G7。

### M6a 版の宣言と固定ハッシュの更新パッチの確認

- 目的: 版を上げる作業の前に、通常入力の全変更をレビューできる形にする。
- 触るファイル: 改造ディレクトリの版の更新 patch・manifest・確認表。通常入力と crate の版はまだ変更しない。
- 手順: P1 の一覧を更新し、Rust の format/concat と tests/runtime_builtins.rs、tools の参照解、package.bnt と依存の控えを分類する。現在のソースに patch を重ねた内容から固定ハッシュの候補を計算し、旧・未来・不正な版とハッシュ不一致を試す入力を別に記す。CHANGELOG の版と診断の案内も patch として揃える。patch の元のハッシュと適用順を固定する。
- 完了の条件・検査: K、入力一覧の全候補が変更/検査として保持/歴史資料へ対応し、未確認の版・固定ハッシュがゼロ。patch は元のバイト内容へ適用でき、M7 で本体の変更とテストを一度に通せる。
- 依存: M6。

### M7 0.0.6 と通常入力・固定ハッシュの同時更新

- 目的: 版を一度だけ上げ、通常入力を版の診断で落とさない。
- 触るファイル: Cargo.toml/Cargo.lock、BREAKING_CHANGES、CHANGELOG、現行の language 宣言、Rust の統合入力と生成器、package.bnt と固定ハッシュ、英語の公開文書、Skill の生成物。
- 手順: P1 の一覧から通常入力の更新 patch と版の検査用に保持する入力の確認表を先に作る。Rust の format/concat、tests/runtime_builtins.rs、依存の参照解も含める。全 patch が確認済みになってから版・変更表・通常入力を同時に適用する。依存の実内容からハッシュを再計算する。0.0.6 の summary/help と CHANGELOG に return 直後の継続の廃止を移行の一項目として加え、A4 の E0201 の案内・24 行の修正との一致を確認する。他の破壊・新しい診断・既存コードの help 変更・裸の固定も同じ節へまとめる。
- 完了の条件・検査: K、`cargo test -p benitoite --lib modules::`、`cargo test -p benitoite --test package_command --test runtime_builtins --test golden --test reference_examples --test skill_docs`、両構成の workspace all-targets、gen_skill、check-formal。旧・新・不正・未来の版とハッシュ不一致の検査の意図を保ち、通常入力は 0.0.6 で元の仕事を検査する。
- 依存: M6a。

### M8 日本語訳と全サンプルの最終照合

- 目的: 最終の英語の版と、設計者が読む訳を揃える。
- 触るファイル: docs/ja/reference、docs/ja/skill、訳とサンプルの照合表。
- 手順: 英語の最終版から訳す。R1 の全サンプルを明示形にし、四型の属性・record の制限・Process.Exit・Show・裸の固定、R13 の値の同じ行での書き始めとその後の複数行の説明を照合する。移行手順は CHANGELOG に集めたままにする。Skill の配布ディレクトリへ訳を入れない。
- 完了の条件・検査: K、`cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples`。英日のコードと見出し・版・リンクを照合し、未確認の現行サンプルがない。
- 依存: M7。

### M9 公開前の最終確認と実装結果

- 目的: 全段を一つの 0.0.6 としてレビューできる状態にする。
- 触るファイル: 改造ディレクトリの結果・レビュー記録。修正が必要なら持ち主の本体・入力・文書だけ。
- 手順: G8 の範囲として Q/R、型変更表、四型と追加照合数、移行・版・診断の対応、英日・生成物、六入口、通常の検査から改造の文書への依存の不存在を確認する。上表の軽い検査を先に行い、最後に公開前の全体検査をする。タグ・公開そのものは行わず、具体的なレビュー対象と残件を報告する。
- 完了の条件・検査: K、上表 M9 の `--only`、lake build、check-formal。`bash scripts/check.sh --full --dry-run` を示し、長いテスト約 15 分・release_stack 約 5 分追加、全体では数分〜数十分という見込みを先に報告して `bash scripts/check.sh --full` を通す。全体検査は最終の版と訳のツリーで行う。失敗を修正したら関係する検査を再実行する。
- 依存: M8。G8 の公開前レビューで必要な修正を解消してから完了とする。

## 実装後の範囲

この計画の完了は、0.0.6 の変更と検査・移行の記録をレビューできる状態にすることである。実際のタグ・公開、docs/todo の項目の更新、改造の保管、git のコミットは、後の実装・公開の指示と各運用規約に従う。今回の詳しい設計の作成中は、これらも Rust/Lean の実装も行わない。
