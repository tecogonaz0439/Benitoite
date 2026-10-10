# 0241. CLI のコマンドの名前を `benitoite`、スクリプトの拡張子を `.bnt` に確定し、短い別名のコマンドを設けない

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [CLI](../06-tooling/06-01-cli.md), [Agent Skills 対応](../06-tooling/06-06-agent-skills.md), [ロードマップ](../00-overview/00-03-roadmap.md), [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md), [処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)
- 関連する未決事項: [OPEN-011](../open-issues.md#open-011)

## 背景

言語の名前は Benitoite に確定した（[ADR 0132](0132-language-name-benitoite.md)）。CLI のコマンドの名前 `benitoite` とスクリプトのファイルの拡張子 `.bnt` は仮の決定のまま、最小実行版の処理系とテストに使ってきた（[OPEN-011](../open-issues.md#open-011)）。OPEN-011 は、確定する前に、名前・コマンドの名前・拡張子がほかのプログラミング言語、パッケージの名前、コマンドと重なっていないかを改めて調べるとしていた。

2026-09-29 に次のことを調べた。

- `benitoite` という名前のパッケージは、crates.io、npm、PyPI、Homebrew のどれにも登録されていない。各所の API に名前で問い合わせると、HTTP 404 が返った。
- GitHub には `benitoite` という名前のリポジトリが 19 ある。目立つものは Bluesky のクライアントの試作（[wiredsis/benitoite](https://github.com/wiredsis/benitoite)。Rust、AGPL-3.0、スター 2、2024-11 から更新がない）で、ほかは個人のリポジトリである。広く使われているプログラミング言語やコマンドはない。
- `.bnt` は、GitHub Linguist の言語の一覧（[languages.yml](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml)）に登録されていない。
- ファイルの拡張子を集めたサイトは、`.bnt` を Nintendo の機器のシステムのデータや、ゲーム Entropia Universe のデータの拡張子として挙げている（[NirSoft](http://extension.nirsoft.net/bnt)、[FILExt](https://filext.com/file-extension/BNT)）。どれもバイナリの形式であり、テキストのソースではない。

## 決定

1. CLI のコマンドの名前を `benitoite` に確定する。
2. スクリプトのファイルの拡張子を `.bnt` に確定する。
3. 短い別名のコマンド（`bnt` など）は設けない。シェバンの行も `benitoite` を使う（[ADR 0135](0135-shebang-line-and-implicit-run.md)）。
4. 同梱の Agent Skill の名前は、コマンドの名前と同じ `benitoite` のままとする（[ADR 0229](0229-bundled-skill-contents-and-japanese-translations.md)）。

## 検討した代替案

- **別名のコマンド `bnt` も配る**: 対話的に打つときの文字数が減る。しかし、同じ役割のコマンドが二つになり（原則 5）、LLM の書くスクリプト・シェバン・文書でどちらを使うかがぶれる。npm には `bnt` という名前のパッケージが既にあり、名前の衝突も避けられない。利用者が短く打ちたいときは、シェルの別名で足りる。

## 帰結

- 最小実行版の処理系とテストは、仮の名前のまま実装した（[ロードマップ](../00-overview/00-03-roadmap.md)）。名前を確定したので、処理系・テスト・文書の名前を置き換える作業は要らない。
- `.bnt` をバイナリの形式として扱う道具とは、拡張子が重なる。テキストのソースとバイナリのデータは中身で見分けられ、利用者がそれらの道具と同じ場所で Benitoite を使うことは少ないと見込む。
- 本 ADR で OPEN-011 は決着する。コードネーム（`San Benito`、メジャーバージョン 2 の候補 `Itoigawa`・`Okutama`）は [ADR 0090](0090-version-numbers-and-codenames.md) で決めたとおりである。
