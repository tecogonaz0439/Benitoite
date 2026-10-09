# AGENTS.md

このリポジトリで作業するコーディングエージェント（Claude Code、Codex、OpenCode など）向けの指示である。

## プロジェクトの概要

Rust で実装する関数型スクリプト言語のリポジトリである。設計書、実装プラン、処理系のソースコードを、すべてこのリポジトリに置く（`docs/design/decisions/0040-single-repository.md`）。最小実行版の設計書と実装プランによる実装を終え、現在は `docs/design/` の設計書を正式版に仕上げる段階にある。処理系のソースコードは `crates/benitoite/` に置き、完了条件の共通の検査は `scripts/check.sh` で行う。言語の名称は `Benitoite`（ベニトアイト）とする（`docs/design/decisions/0132-language-name-benitoite.md`）。CLI のコマンドの名前は `benitoite`、スクリプトの拡張子は `.bnt` とする（`docs/design/decisions/0241-command-name-and-extension.md`）。リポジトリの名前の `Zozooo` は、以前の仮称である。

処理系は LLM が実装する。設計書の作成から実装プランの作成までを Claude Code が担い、初期実装は LLM が実装プランに従って行う。最小実行版では、Claude Code がオーケストレータとして作業を配り、難しい作業を Claude Opus 5.5 のサブエージェントに、それ以外を Codex（GPT-6-Luna）に割り当てる。実装の確認はオーケストレータが行い、Opus が実装した作業は Codex も確かめる（`docs/design/decisions/0084-implementer-assignment-for-minimal.md`、`docs/design/decisions/0085-review-assignment-for-minimal.md`）。初回リリース版では、難易度によらず Codex（GPT-6.1-Sol）が実装し、オーケストレータがすべての作業を確かめる（`docs/design/decisions/0308-implementation-by-codex-sol.md`）。実装プランは、設計書と実装プランだけを読めば実装できる粒度で書く。処理系は Rust で書く。

言語の主な目的は二つある。表向きの目的は、Perl の精神を受け継ぎ、利用者が「怠惰・短気・傲慢」のままで使えるスクリプト言語を作ることである（Agent Skills から実行できることは、その手段として位置付ける）。実質的な目的は、設計者自身が、関数型プログラミング（型システム・エフェクト・永続データ構造など）と言語処理系（解析器・仮想機械・ランタイムなど）を学ぶことである。設計者は処理系を手で実装せず、LLM が書いた実装を読み、必要なときに LLM へ実装の理由を質問して学ぶ。二つが衝突したときの判断基準は `docs/design/00-overview/00-01-goals.md` に定める。

## コンセプト（判断の拠り所）

言語仕様・処理系の設計を議論するとき、判断に迷ったら、次のコンセプトに立ち返って選択肢を評価する。仕様や設計の判断を伴う作業を始める前に、`docs/design/00-overview/00-01-goals.md` を読む。この節は同章の要約であり、食い違うときは同章を正とする。同章を変えたら、この節も合わせて更新する。

- **標語**: 怠惰・短気・傲慢を再び（Laziness, Impatience, and Hubris — Again）
- **方向**: 利用者は怠惰・短気・傲慢のままで、言語の詳細を学ばずに、LLM によるスクリプトの作成・修正を通じて作業を自動化できる。利用者は作業と許可する操作を決め、処理系は型とエフェクトの規則への適合を検査し、LLM はコードの作成・修正と診断の説明を担う。
- **保証の範囲**: 静的検査が保証するのは、型とエフェクトの規則への適合だけである。意図との一致、外部操作の成功、停止性は保証しない。エフェクトの静的な追跡と、実行時の権限制御は区別する。実行時の権限制御と OS のサンドボックスは、初回リリース版の後にサーバモードとあわせて提供する。それまでの版は静的検査だけを保証し、隔離はハーネスや OS に委ねる。権限制御を持たない版も、保証の範囲を示して利用者に提供してよい。
- **利用者**: プログラマに限らない。主な接点は、実行前の権限（エフェクト）の確認と実行後の結果の確認。コードに直接触るのは、文字列の書式など表面の小さな修正に限られる。
- **書き手**: 主に LLM。診断の第一の読み手は LLM、権限の説明と実行結果の第一の読み手は人間。
- **設計原則**（衝突したら番号の小さい方を優先）:
  1. 静的に検出できる誤りを実行前に報告する
  2. 変更後も契約を検査し、契約と権限の変更を見落とさせない
  3. 利用者が許可する操作と実行結果を理解でき、直接編集する箇所を壊しにくくする
  4. 記述量の少なさより、検査と診断の明確さを優先する
  5. 同じ役割の構文を、必要な理由なく増やさない
  6. 簡単なことは簡単に、難しいことも可能に
- **構文の基準**: LLM による生成・修正の成功率（期待結果の達成まで含める）と、人間による読みやすさ。設計者の好みは基準にしない。
- **学び方**: 設計者は処理系を手で実装しない。設計書を作る過程と、LLM が書いた実装を読み、実装の理由を LLM に質問することで学ぶ。
- **目的の衝突**: 言語の中核（型システム・エフェクト・コレクション）と言語処理系の主要部（解析器・中間表現・バイトコード・VM）は自作し（既存の OSS を使わずにこのプロジェクトで作る。実装は LLM が行う）、それ以外の基盤は既存の OSS を使う。提供時期と衝突したら範囲と時期で調整し、宣言済みの保証は弱めない。

## ディレクトリ構成

| パス | 内容 | 扱い |
|---|---|---|
| `reference/` | ユーザーが会話ごとに置く参照用ファイル。会話が終わると削除されることがある | 読み取り専用。編集しない。設計書からリンクしない |
| `docs/design/sources/` | 設計書から参照する資料の保存先（`reference/` からのコピー） | 読み取り専用。編集しない |
| `docs/design/sources/fp-language-design.md` | 設計メモ。論点ごとの決定・方針・未決事項の記録 | |
| `docs/design/` | 設計書本体。最小実行版の設計書を引き継ぎ、正式版の設計書に仕上げる | 主な作業対象 |
| `docs/design/README.md` | 設計書の目次・凡例・各章の状態 | 章を追加・改名したら更新する |
| `docs/design/01-spec/` | 言語仕様（規範）。処理系の実装方式に依存しない | |
| `docs/design/02-impl/` 以降 | 処理系設計、相互運用と標準ライブラリ、拡張、配布、ツール、品質、付録 | |
| `docs/design/open-issues.md` | 未決・要検証事項の一覧（`OPEN-nnn`） | |
| `docs/design/decisions/` | 設計判断の記録（ADR）。1判断1ファイル | |
| `docs/implement/` | 初回リリース版の実装プラン（`00-common/`・`10-interfaces/`・`20-tasks/`・`90-after-completion.md`。`docs/design/decisions/0253-first-release-plan-location-and-units.md`） | 作成中。実装を終えたら `docs/archive/` へ移す |
| `docs/archive/` | 過去の文書の保管場所。最小実行版の設計書の写し（`2026-09-27-design-initial/`）と、最小実行版の実装プランと実装の結果（`2026-09-27-implement-initial/`） | 読み取り専用。過去の文書や処理系の作成・改造の経緯を調べるときだけ読む。現在の作業の根拠にしない。設計書の章からリンクしない（ADR が経緯として参照するのはよい） |
| `docs/reference/` | 利用者向けの英語の文書。初回リリース版の言語リファレンス（`benitoite.md`）と導入の手順（`install.md`）、最小実行版の言語リファレンス（`benitoite-minimal.md`） | `benitoite.md` のコードの例は `crates/benitoite/tests/reference_examples.rs` が検査する |
| `docs/ja/` | 日本語の訳。言語リファレンス・導入の手順（`reference/`）と、同梱の Agent Skill の `SKILL.md` と手で書く参照の文書（`skill/`）の訳。設計者が読むためのもので、英語の版を正とする | 英語の版を変えたら、リリースのときに訳し直す。Skill のディレクトリに含めない |
| `crates/benitoite/` | 処理系のクレート（lib と bin）。`src/`（ソース）、`tests/`（統合テストとゴールデンテストの実行器）、`testdata/`（ゴールデンテスト）、`examples/`（開発用の例） | モジュールの構成は実装プランの `00-common/00-01-repository-layout.md` |
| `crates/benitoite/skill/` | 同梱の Agent Skill（`SKILL.md` と `references/`）。実行ファイルに埋め込む（実装プランの `10-interfaces/10-19-skill-and-distribution.md`） | `references/` の文法・診断・標準ライブラリの文書は生成物であり、手で直さず `cargo run -p benitoite --example gen_skill` で作り直す。構文の章・標準ライブラリのソース・診断の表を変えたら、同じ変更で作り直す |
| `tools/syntax-measure/` | 構文の案ごとに、LLM が書いたスクリプトの構文の誤りの率を測る道具（Python。OPEN-012・ADR 0246 の第一段階）。生の記録はリポジトリの外に置く | 使い方は `tools/syntax-measure/README.md`。LLM を呼ぶ測定は設計者の了承を得てから行う |
| `tools/skill-eval/` | 同梱の Agent Skill を、約 10 の課題とハーネス（Claude Code・Codex CLI・OpenCode）で評価する道具（Python。06-06「Skill の評価」、ADR 0232。OPEN-012 の第二段階にも使う）。記録は `results/`、生の記録はリポジトリの外に置く | 使い方は `tools/skill-eval/README.md`、手順はスキル `skill-eval`。LLM を呼ぶ評価は設計者の了承を得てから行う |
| `tools/spec-coverage/` | ゴールデンテストが言語仕様のどの節を確かめているかを集計する道具（Python） | |
| `tools/bench/` | ベンチマークと測定の道具、測定記録（`results/`） | 測定はスキル `benchmark` に従う |
| `assets/brand/` | ロゴ・アイコン・ワードマークの画像（SVG と PNG）と、作り直す道具（`make_logos.py`）。キャラクターの案 A・B・C の画像は `mascots/`。将来の Web サイトや README に貼るためのもの（`reference/Benitoite-brand/` と `reference/benitoite-mascots/` からの写し。色と書体は `README.md`、キャラクターの案は `mascots/README-ja.txt`） | 画像を手で直さず、`make_logos.py` で作り直す |
| `fuzz/` | cargo-fuzz のクレート（nightly の Rust を使うので、ワークスペースに含めない） | `scripts/fuzz-short.sh` で実行する |
| `formal/` | 形式検証の段階 2 の Lean 4 のプロジェクト。コア計算（`docs/design/01-spec/01-12-core-calculus.md`）の形式化した規則の正と、進行と保存・エフェクトの健全性の定理（`docs/design/07-quality/07-04-formal-semantics.md`、ADR 0293〜0295、ADR 0307） | `formal/` で `lake build` を実行する。`scripts/check.sh` には含めない。形式化した規則を変えるときは、ADR を添えて Lean の定義と 01-12 の写しを同じ変更で直し、`lake build` が `sorry` なしで通ることを確かめる |
| `scripts/` | `check.sh`（完了条件の共通の検査）、`check-heap.sh`（nightly の Rust が要る検査と時間のかかる検査）、`fuzz-seed.sh`・`fuzz-short.sh`（fuzzing） | 作業を取り込む前に `check.sh` を通す。`runtime::heap` を変える作業では `check-heap.sh` も実行する |
| `.claude/skills/` | プロジェクト固有のスキル（`git-workflow`、`test-audit`、`benchmark`、`skill-eval`） | `.agents/skills/` にシンボリックリンクを置く |
| `.claude/agents/` | 実装を担うサブエージェントの定義（`impl-medium`、`impl-low`） | オーケストレータが起動する（実装プランの `00-common/00-03-workflow.md`） |

## 設計書の規約

### ファイル名と章番号

- 部のディレクトリは `NN-<名前>/`、章のファイルは `NN-MM-<名前>.md` とする（例: 第1部第2章は `01-spec/01-02-syntax.md`）。`<名前>` は英小文字とハイフンで書く。
- `decisions/` と `open-issues.md` は章ではないので、章番号を付けない。ADR のファイル名は `NNNN-<名前>.md` とする。
- 章を追加・改名・移動したら、`docs/design/README.md` の目次と、その章を参照している全リンクを更新する。

### 章ファイルの構成

各章は次の形をとる。見出しを削除・改名しない。

```markdown
# <章題>

- 状態: 未着手 | 草稿 | 確定
- 関連ADR: 
- 未決事項: OPEN-nnn へのリンク
- 移行元: 設計メモの節番号

## 目的と範囲
## 前提
## 仕様
## 未決事項
```

状態を変えたら、`docs/design/README.md` の目次の状態欄も同じ値に変える。

### 決定の書き方

- 本文には現在の決定だけを書く。判断の理由、検討した代替案、却下した理由は ADR に書き、本文からは ADR 番号で参照する。
- 決定の確度は、設計メモと同じ凡例で示す: 【決定】合意済み／【方針】暫定の既定路線／【未決】選択肢を検討中／【要検証】試作・実測・一次資料による確認が必要。
- 設計メモで【決定】となっている事項も、設計書へ移すときは【方針】とする。設計メモの決定を見直しの対象外として扱わない。設計書で【決定】を付けるのは、設計書の上で改めて合意し、ADR を採択した事項に限る。
- 未決・要検証の事項は `open-issues.md` に `OPEN-nnn` として登録し、本文ではその ID を参照する。本文の中だけで未決事項を管理しない。
- 決着した未決事項は、ADR を作成してから `open-issues.md` の種別を「決着」に改め、ADR 番号を記す。
- `01-spec/` には、処理系の実装方式（VM、トランスパイル、WASM など）に依存する記述を入れない。そうした記述は `02-impl/` に置く。

### 参照資料の保存

`reference/` のファイルは会話が終わるごとに削除されることがある。設計書から参照する資料は次のように扱う。

- 設計書から `reference/` 内のファイルを参照する必要が生じたら、そのファイルを `docs/design/sources/` にコピーし、設計書からはコピーを相対リンクで参照する。`reference/` へのリンクを設計書に残さない。
- コピー済みのファイルが `reference/` で更新されていたら、`docs/design/sources/` のコピーも更新する。
- `docs/design/sources/` のファイルは資料の写しとして扱い、内容を編集しない。
- 設計書の最終版を発行するとき（すべての未決事項が決着した時点）は、設計書から設計メモ（`docs/design/sources/fp-language-design.md`）へのリンクを外す。それまでは、各章の「移行元」などから設計メモへリンクしてよい。

### 事実と出典

- 外部の事実（Rust のバージョンごとの挙動、ライブラリの仕様、OS の制約、製品情報など）は、一次資料で確認したものだけを断定の形で書く。確認していないものには【要検証】を付ける。
- 設計メモで【要検証】や「未確認」となっている事項を、確認せずに断定へ書き換えない。

## 文章の規範

設計書は日本語の常体（「である」調）で書く。文章の規範は、スキル `japanese-tech-writing` に従う。設計書を執筆・推敲・レビューするときは、先にこのスキルを読み込む。

用語は `docs/design/00-overview/00-04-glossary.md` の定義に揃え、章をまたいで同じ概念に別の語を使わない。

## レビューの観点

設計書のレビューを依頼されたら、文章の好みよりも次の点を優先して確認する。

1. **章どうしの整合**: 同じ概念の定義・分類・用語が章をまたいで一致しているか。特に、`01-spec/` と `02-impl/`、`01-spec/01-07-effects.md` と `07-quality/07-01-security-model.md` の間の記述。
2. **設計メモとの対応**: 設計メモの決定事項が、落ちたり意味を変えたりせずに移されているか。意図的に変えた場合は ADR に記録されているか。
3. **未決事項の管理**: 本文の【未決】【要検証】に対応する `OPEN-nnn` があり、`open-issues.md` の関連章と本文の側が一致しているか。
4. **論証の正しさ**: 主張が挙げた根拠で支えられているか。断定しすぎていないか。前方参照した論点が実際に回収されているか。
5. **仕様としての十分さ**（`01-spec/`）: 実装者がこの記述だけで判断できるか。規範的な記述（しなければならない／してもよい）と説明とが区別されているか。
6. **リンクと目次**: 相対リンクが切れていないか。`README.md` の目次・状態が各章と一致しているか。

指摘には、ファイルパスと見出し（または行番号）、問題点、修正案を添える。レビューだけを依頼された場合は、ファイルを書き換えない。

## ユーザーへの報告

- 作業の最後の報告は日本語で書く。途中経過のメッセージは英語でもよい。

## Git の運用

- コミット時はスキル `git-workflow`（`.claude/skills/git-workflow/SKILL.md`）に従う。

## テストの運用

- 処理系のテストを書く・変える・見直すときは、スキル `test-audit`（`.claude/skills/test-audit/SKILL.md`）に従う。テストの設計の原則は `docs/design/07-quality/07-03-compiler-testing.md` の「テストの設計の原則」で定める。
- 言語仕様と付録 08-04 の例の検査は、`crates/benitoite/tests/spec_examples.rs` にある。構文の章や例を変えたら、リポジトリの根で `cargo test --test spec_examples` を実行する。

## 性能の測定

- 処理系の性能を測るときは、スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）に従う。道具は `tools/bench/` にある。

## 実装の規約

本節は初回リリース版の実装プランの [00-02「文章で守る規約」](docs/implement/00-common/00-02-conventions.md#文章で守る規約)を写したものであり、食い違ったときは 00-02 を正とする。lint の水準は `Cargo.toml` の `[workspace.lints]` が定める。

### 型とシグネチャを変えない

`10-interfaces/` の `file=` のコードと `sig=` のシグネチャは、変えずに中身を書く。欄や引数を加える・変える・消す必要が生じたら、実装を進めずに報告する（[作業の進め方](docs/implement/00-common/00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。非公開の補助の関数と型は、自由に加えてよい。

### `todo!()` の仮置き

C01・C02 は、`docs/implement/tools/extract_interfaces.py place` でインターフェースを置く。道具は、`sig=` の関数の宣言を、本体が `todo!()` の関数（`todo!()` の仮置き）として書き、仮置きを置いたファイルの先頭（`//!` の行の後）に次の許可とコメントを置く。置いた直後のクレートがコンパイルでき、`scripts/check.sh` を通るようにするためである（C01・C02 の後も、どの取り込みの後もクレートがコンパイルできる。[作業の進め方](docs/implement/00-common/00-03-workflow.md)の「最小実行版の実装からの移行」）。10-12 の組み込みの関数の「仮の本体」（名前・権限・引数の数だけが正しく、呼ばれたら処理系の不具合を返す関数）とは別のものである。

```rust
// 仮置きのための許可: 道具が置いた `todo!()` の仮置きのために、lint の clippy::todo と、仮置きが
// 使わない引数への unused_variables を許す。このファイルの `todo!()` をすべて本体に書き換えた
// 作業が、このコメントと次の属性を消す（実装プラン 00-02「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::todo, unused_variables)]
```

- 作業は、受け持つ関数の `todo!()` を本体に書き換える。完了のときに、受け持つ関数に `todo!()` を残さない。
- 作業を終えるときにファイルに `todo!()` が一つも残っていなければ、その作業が許可とコメントを消す。一つのファイルの関数を複数の作業が受け持つとき（10-08 の `runtime/heap/ctx.rs` など）は、最後に `todo!()` を書き換えた作業が消す。`todo!()` のないファイルに許可が残っていると、`scripts/check.sh` が失敗する（「完了条件の共通の検査」の「仮置きの許可の残り」）。
- 仮置きの許可を、道具が置いたファイル以外に書き足さない。作業が新しく書くコードで `todo!()` を使わない。
- U1・U2 の作業をすべて終えた時点で、`src/` に `todo!()` と仮置きの許可は残らない（[すべての作業を終えた後に行うこと](docs/implement/90-after-completion.md)）。U1・U2 の完了の確認（90-after-completion）で、残っている仮置きのファイルと、それを受け持つ作業を調べる。

### 失敗を panic で表さない

- 言語の規則で定めた失敗（除算の 0、IO の失敗など）は、`Stop` か `Err` の値として返す（[ランタイム](docs/design/02-impl/02-09-runtime.md)の「panic 境界」）。
- 型検査を通ったプログラムでは起きないはずの状態（表を引いて結果がない、値の種類が違う）は、脱糖とコード生成では `InternalError`、実行中は `Stop::Internal` として返す。
- 振り分けのループの範囲の確かめは、読み込みのときの検証器を通したプログラムでも省かず、すべて実行中に行う（[ADR 0315](docs/design/decisions/0315-keep-dispatch-range-checks.md)）。検証器（`bytecode::verify`）は、テストでコード生成の出力を確かめる道具であり、本番の読み込みの経路（`pipeline`、`runtime::run`、CLI）からは呼ばない。
- `unwrap`・`expect`・添字（`v[i]`）は lint で禁じている。`get` と `?`、`let ... else` で書く。

### `unsafe` の書き方

- `unsafe` を書いてよいのは、`runtime::heap` の内部の層だけである（[リポジトリとクレートの配置](docs/implement/00-common/00-01-repository-layout.md)の「`unsafe` を書いてよいモジュール」）。処理系の本体の外の例外として、テストのバイナリ `tests/call_allocations.rs` の確保を数える確保器にだけ書いてよい（後述の「`#[allow]` を書いてよい箇所」）。
- `unsafe` のブロックは、操作を一つだけ含め、直前に `// SAFETY:` のコメントで、その操作が前提とする不変条件と、それがなぜ成り立つかを書く（lint が形だけを確かめ、中身は確認の観点で読む）。
- 内部の層の各ファイルの先頭の `//!` のコメントに、そのファイルが守る不変条件の一覧を書く。`// SAFETY:` のコメントは、その一覧の項目を名指しして引く。
- `unsafe fn` を公開の層に出さない。内部の層の `unsafe fn` には、呼び出し側が守る条件を `/// # Safety` の節で書く。

### 回収しない区間と値の扱い

言語の値は `Value<'epoch>` の形で扱う（[ADR 0260](docs/design/decisions/0260-heap-and-unsafe-boundary.md) の決定 3・4）。`'epoch` は回収しない区間の寿命であり、区間の中の処理は `NoGcCtx<'epoch>` を受け取る。

- `Value<'epoch>` を、区間より長く生きる場所（構造体の欄、`static`、作業用のスレッドへ渡す値）に置かない。型の上でも置けないように作ってあり、置こうとするとコンパイルの誤りになる。
- 安全点を越えて使う値は、安全点へ戻る前に VM の保存領域（レジスタ、枠、根の保存領域）に置く。保存領域から読み直した値は、新しい区間の `Value<'epoch>` になる。
- `NoGcCtx<'epoch>` は回収の機能を持たない。回収を行えるのは、VM が安全点で呼ぶ関数だけである。
- 別の実行のヒープの値を混ぜない。混ぜられないように型の印か検査付きの参照で作ってある（ADR 0260 の決定 5）。
- 書き込みの障壁を差し込む位置（セルの書き込み、`Lazy` の結果の書き込み、タスクの結果の書き込み、継続の状態の変更）は、公開の層の決まった関数だけで書く（[ADR 0259](docs/design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 7）。対象の中身を直接書き換える関数を、公開の層に加えない。

### 言語の値を作る経路

言語の値のヒープの対象は、`runtime::heap` の公開の層の関数（`NoGcCtx` が持つ関数）だけで作る。対象を指す値は、`runtime::heap` の外から作れないようにしてある。最小実行版の「`runtime::heap::Heap` の関数だけで作る」（[ADR 0078](docs/design/decisions/0078-reference-counting-in-minimal.md)）を、この形に改める。

### 組み込みの関数の書き方

組み込みの関数は、型付きの形で書く（[ADR 0261](docs/design/decisions/0261-typed-builtin-interface.md)）。詳細は 10-11 で凍結する。

- 実装者は、名前と型の付いた引数を受け取る関数と、その宣言だけを書く。引数の読み出しと登録の表は、`macro_rules!` による宣言のマクロが宣言から作る。内部の共通の形（`Ctx` と引数を受け取り、応答か停止を返す関数）を直接書かない。
- 関数は、権限に合った文脈を受け取る。純粋な関数は、時計・乱数・リソースに触れず、待つ・タスクの起動・終了を返せない文脈を受け取る。
- 値を作る関数は、確保の前に大きさを確かめる（[ADR 0049](docs/design/decisions/0049-size-limit-for-built-values.md)）。確かめた長さを受け取る確保の関数か、上限付きの構築器を使う。外部のバイト列から文字列の値を作るときは、UTF-8 を確かめる文字列の値の API を通す。
- 作業用のスレッドに渡す仕事と結果は `Send + 'static` の型にし、言語の値を含めない。完了を言語の値に変える処理は、環境を捕えない `fn` ポインタで書く。待つ間に要る言語の値は、閉包に捕えず、枠のレジスタに残す。
- 完了の保存、起動する関数の登録、取り消しとの競合、リソースの返却は、共通の部分が行う。個々の組み込みの関数に書かない（[ADR 0266](docs/design/decisions/0266-task-and-resource-state-machines.md)）。

### 大域の状態

処理系のどの段も、`static mut`・`thread_local!`・`OnceLock` などの大域の可変状態を持たない（[ADR 0015](docs/design/decisions/0015-shared-program-per-execution-state.md)）。例外は次の四つだけである。

- panic hook の記録（02-09「panic 境界」がスレッドローカルな記憶域を指定した。`runtime/panic.rs`）。
- 解放の回数の計数（07-02「確保と解放」）。機能 `alloc-stats` を有効にしたビルドでだけ、`thread_local!` の計数器で数える。既定のビルドには含めない。
- 初回リリース版の中断の印（ADR 0163。`crates/benitoite/src/runtime/run/interrupt.rs`）。`SIGINT`・`SIGTERM` を受けたことを、プロセス全体で一つの原子的な真偽値で表す。印を書くのはシグナルの登録の仕組みだけ、読むのは VM の実行の区切りだけである。
- ヒープの番号を割り当てる計数器（プロセスで一つの `AtomicU32`）。`Heap::new` だけが増やす（[ADR 0281](docs/design/decisions/0281-heap-number-in-slot-and-contract-safety.md)、10-08「根の保存領域」）。

ヒープは実行ごとに持ち、大域の確保器の状態を作らない。回収の要求と予算は実行ごとの状態に置く。

### 再帰の深さ

最小実行版の規約のとおりとする。

- AST と、AST から作る中間表現を辿る処理は、再帰で書いてよい。
- 実行時の値を辿る処理（構造の `==`、マーク、参照カウントの解放の連鎖、到達可能性の計算、リストの走査）は、明示の積み重ね（`Vec`）で書く。
- 言語の関数の呼び出しで Rust の関数を入れ子に呼ばない（[ADR 0016](docs/design/decisions/0016-calls-off-go-stack.md)）。VM と参照インタプリタの両方に適用する。
- 処理系のテストは、深い入れ子と長いリストの場合を含める。スレッドのスタックの大きさを変えてテストを通すことはしない。

### 数値の変換

`as` による数値の変換は、値が収まることが明らかな箇所（命令の符号化など）に限る。そのほかは `u32::try_from` などを使い、失敗を処理系の不具合として扱う。

### `#[allow]` を書いてよい箇所

lint を個別に許す `#[allow(...)]` は、次の箇所だけに書き、許す理由をコメントで書く。最小実行版の表からの変更は、`runtime::heap` の内部の層の行と `todo!()` の仮置きの行を加え、`src/lib.rs` の行を作業の途中の間だけに限ったことである。

| 箇所 | 許す lint | 理由 |
|---|---|---|
| `src/runtime/heap/` の内部の層のファイル（10-08 がファイルを指定する） | `unsafe_code` | 確保器と生のポインタを扱う（ADR 0260）。公開の層のファイルには書かない |
| `src/lib.rs` | `dead_code` | 作業の途中では、後の作業が使う欄が読まれない。C01 で置き、U1・U2 を終えた後に外す（90-after-completion の「移行の締めの残り」） |
| `docs/implement/tools/extract_interfaces.py place` が `todo!()` の仮置きを置いたファイルの先頭（道具が置く。前述の「`todo!()` の仮置き」） | `clippy::todo`・`unused_variables` | 後の作業が本体を書くまで、置いた直後のクレートをコンパイルでき lint を通るようにする。そのファイルの `todo!()` をすべて書き換えた作業が消す |
| テストのモジュール（`#[cfg(test)] mod tests`）と `tests/` の各ファイル | `clippy::unwrap_used`・`clippy::expect_used`・`clippy::panic`・`clippy::indexing_slicing`・`clippy::arithmetic_side_effects` | テストの失敗は panic で表す |
| `tests/call_allocations.rs`（R15 の、普通の呼び出しと戻りで確保がないことを確かめるテスト） | `unsafe_code` | 確保を数える `#[global_allocator]` は `unsafe impl GlobalAlloc` を要する。中身は `std::alloc::System` へ委ねて数えるだけとする（[ADR 0313](docs/design/decisions/0313-vm-performance-recovery-before-stage-2.md) の決定 5） |
| `src/cli/`、IO 実行器、`src/runtime/run.rs` の第 1 段の IoServices を包む型（R26 が IO 実行器へ移す）の `BENITOITE_DEV_PANIC` の処理 | `clippy::panic` | 処理系の不具合の報告をテストするために、意図して panic を起こす |
| `src/bytecode/program.rs` の `assert_shareable` | `dead_code` | 呼ばれない関数で、型の性質をコンパイルの時点で確かめる |

振り分けのループで範囲の確かめを省くための `unsafe` は許さない（[ADR 0315](docs/design/decisions/0315-keep-dispatch-range-checks.md)）。表にない箇所で許す必要が生じたら、作業を止めて報告する。

### 文言

診断・報告の文言は英語で書き、`diag::codes` の表と `cli::text` にまとめる（[ADR 0033](docs/design/decisions/0033-english-diagnostic-messages.md)）。処理を書く関数の中に英語の文を直接書かない。型板に埋める値やほかの報告の文は、それぞれのモジュールの `text` という子のモジュールに定数としてまとめる（最小実行版の規約のとおり）。`Stop::Internal` と `InternalError` の説明の文字列は、処理系の不具合を調べるためのもので、診断の表にも `text` にも載せない。

### コメントと名前

- 識別子は英語で書く。コメントは日本語で書く。コメントは「何をするか」より「なぜそうするか」を書き、根拠になる設計書の章と節を `（設計書 02-08「実行の手順」）` の形で示す。
- 各モジュールの先頭に `//!` のコメントを置き、そのモジュールの役割と、対応する設計書の章を書く。
- 公開の関数と型には `///` のコメントを書く。10-interfaces のコメントはそのまま残す。

## Agent Skills の運用

- プロジェクト固有のスキルの実体は `.claude/skills/<スキル名>/` に置く。
- スキルを新しく作成したら、`.agents/skills/<スキル名>` に実体を指すシンボリックリンクを作成する。相対パスで作成する（例: `ln -s ../../.claude/skills/<スキル名> .agents/skills/<スキル名>`）。
- スキルを改名・削除したら、対応するシンボリックリンクも改名・削除する。

## してはならないこと

- `reference/` と `docs/design/sources/` 以下のファイルを編集しない。
- 依頼されていない章の本文を書かない。
- 確認していない外部の事実を、出典のある事実であるかのように書かない。
