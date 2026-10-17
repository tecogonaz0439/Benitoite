# ビルドの情報、Skill の取得と形式化の範囲

## 現在のビルドの情報と依存の基準

`crates/benitoite/Cargo.toml` の版は 0.0.6 であり、現在の CLI は CARGO_PKG_VERSION と Unicode の版だけを表示する。クレートの根に Cargo が自動実行する build.rs はなく、Git のコミットと作業ツリーの状態は埋め込んでいない。`src/runtime/heap/build.rs` はヒープの Rust のモジュールであり、Cargo のビルドスクリプトとは別である。

[03-01「使う Rust のクレート」](../../../design/03-interop/03-01-library-structure.md) は個々の依存とライセンスを定める。Wasmtime の C の補助を唯一の例外としている。docs/todo の TODO-099 はこの基準を一般化するかを残しており、「すべての依存が純粋な Rust」という前提は現在成り立たない。今回の JSON とハッシュには既存の serde_json と sha2 が使える。Git の情報だけのために git2/vergen などを加える必要は薄い。

## 埋め込みの案と、値が分からない場合

クレートの根に小さな build.rs を置き、`cargo::rustc-env` で情報を渡し、実行ファイルのコードがコンパイル時に読む案である。生成ファイルを使うなら OUT_DIR の下だけに書く。Cargo はビルドスクリプトの入力環境を `rerun-if-env-changed`、ファイルを `rerun-if-changed` で追跡できる。根拠は [Cargo の Build Scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html)（2026-10-17 確認）である。

候補は次の三つである。

| 案 | 利点と注意 |
|---|---|
| 明示した環境変数だけ | 再現しやすいが、普通の Git チェックアウトのビルドでも指定しなければ不明になる |
| Git を呼ぶだけ | 手元では便利だが、アーカイブと Git がない環境では分からない。worktree と増分ビルドの再実行を考える必要がある |
| 明示値を優先し、なければ Git を読む | 公開時の固定と手元の使いやすさを両立する。値の由来も出力し、検証失敗を成功へ置き換えない |

三番目を推す。候補の入力名は `BENITOITE_BUILD_COMMIT` と `BENITOITE_BUILD_DIRTY`、dirty は true/false/unknown に限る。commit は Git の完全な識別値を保持し、短縮値やリリースタグから推測しない。明示指定の構文が不正ならビルドを止める。自動取得で Git がない・HEAD がない・状態を調べられない場合は null とし、ビルド自体は続ける。SOURCE_DATE_EPOCH や現在時刻から架空のコミットを作らない。

JSON の build は commit、dirty、target、provenance を持つ案とする。provenance は commit と dirty の欄ごとに environment/git/unknown を持ち、由来が異なる場合も区別する。target は Cargo の TARGET から採る（[ビルドスクリプトへ渡す環境変数](https://doc.rust-lang.org/cargo/reference/environment-variables.html#environment-variables-cargo-sets-for-build-scripts)、2026-10-17 確認）。dirty は「ビルドの情報を採取した時点の、追跡ファイルの変更・ステージ済みの変更・無視されていない未追跡ファイル」の有無と定義する。docs/todo のように無視されているファイルは含めない。commit と dirty はバイナリの内容のハッシュではなく、ビルド中の書き換えまで証明するものでもない。

Git の自動取得では、現在のクレートが属する Benitoite のルートを確認し、アーカイブをたまたま別の Git リポジトリの下に展開した場合に親のコミットを拾わないようにする。worktree の .git がファイルの形でも扱い、HEAD・参照・packed-refs・index と、dirty に含めるソースなどの変更で採取を再実行する必要がある。タグ・コミットだけの変更や未追跡ファイルの追加で古い値を残す実装は不可である。Git の監視の具体的な列と Cargo の再実行の観測は詳しい設計で確定する。

ソースのアーカイブには .git がない。公開時に信頼できる値を明示してビルドしない限り、commit と dirty は null とする。dirty: false は確認できた場合だけ出す。Git がなくてもビルドできることを保ち、新たな実行時依存は設けない。

## Skill の埋め込みの一覧を取得にも使う

[06-06「Agent Skills 対応」](../../../design/06-tooling/06-06-agent-skills.md) と `src/cli/tools/skill/mod.rs`・`bundle.rs` が根拠である。bundle::FILES は `SkillFile { path, text }` の静的な一覧であり、各文書を include_str! で埋め込む。SKILL.md、手書きの references、生成した文法・診断・標準ライブラリ、LICENSE-MIT と LICENSE-APACHE を含む。`files()` はこの一覧を返す。

install は一覧の path を使って配置し、SKILL.md の `{{benitoite-version}}` を処理系の版で置き換える。取得も同じ一覧と置換を使えば、インストール先や HOME を調べずに実行できる。生成した文書を手で直す必要はない。取得用にファイルシステムを探索する案と、もう一つ手書きの一覧を持つ案は採らない。

論理名は FILES の path のまま、`/` 区切りで大文字小文字を区別する。拡張子を省いた別名は加えない。絶対パス・空の成分・`.`・`..`・バックスラッシュ・ドライブ名の形を拒み、一覧にある名前と完全一致した項目だけを返す。利用者の入力を path.join して開く必要はない。リポジトリの不具合で一覧に重複や不正名があれば、形式の保証を破るため処理系の不具合として扱う。

一覧の各項目のバイト数と SHA-256 は、SKILL.md の版の置換後の UTF-8 本文から求める。一つの文書の取得も同じ本文とする。raw の取得では本文だけ、JSON の取得では形式の版と論理名・本文・ハッシュを返す案である。圧縮やまとめたアーカイブは今回加えない。

## 形式化への影響

[07-04「01-12 との対応」](../../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) は、構文・型の規則・脱糖を変えるときに、形式化した範囲の内側なら先に Lean を直すと定める。今回推す案は、既存の Scheme.effects の読み出し、CLI の事前の比較、出力、組み込みの関数の引数の拒否である。言語の構文、型の受理規則、ハンドラの除去、die の脱糖は変えない。

この範囲なら Lean の定義と証明の変更は不要であり、今回 lake build や check-formal は実行しない。後の詳しい設計では CLI の照合とホストの環境構築は証明の対象外であることを記し、07-04 の表へ注記が要るかを確認する。Command の型を変更したり、shell を独立したエフェクトに分けたり、推論の意味を変えたりする方向へ広げた場合は、同じ結論を流用せず形式化との対応を再判定する。
