# 0131. 実行を始めるスクリプトのディレクトリを取得する関数と、それを基準にする権限の宣言の書き方を加える

- 状態: 採択（決定 2 と 3 を [0147](0147-remove-permission-declaration-syntax.md) で廃止した）
- 日付: 2026-09-28
- 関連章: [エフェクト](../01-spec/01-07-effects.md), [構文](../01-spec/01-02-syntax.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [セキュリティモデル](../07-quality/07-01-security-model.md), [Agent Skills](../06-tooling/06-06-agent-skills.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-032](../open-issues.md#open-032)

## 背景

ファイルの操作と、`permissions` の宣言のパスの相対パスは、処理系を起動したときの作業ディレクトリを基準にする（[ADR 0071](0071-permission-declaration-and-runtime-denial.md)、[エフェクト](../01-spec/01-07-effects.md)）。一方、import は根のディレクトリからの名前で取り込み、作業ディレクトリに依存しない（[ADR 0126](0126-import-by-module-name.md)）。

Agent Skills のスクリプトは、どの作業ディレクトリから起動されるかが決まらない（[ADR 0127](0127-directory-run-and-root.md)）。Skill は、スクリプトと一緒に `assets/` などのファイルを配る。いまの仕様では、スクリプトと同じ場所のファイルを指す方法がない。Perl の `FindBin`、Node の `import.meta.dirname`、PowerShell の `$PSScriptRoot` は、スクリプトのディレクトリを得る手段である。

## 決定

1. `Benitoite.IO.Process` に、実行を始めるスクリプトのディレクトリの絶対パスを返す関数 `Process.scriptDirectory()` を加える。エフェクトは `Process.Environment` とし、権限の宣言は要らない。
2. `permissions` の宣言のパスの権限（`read`・`write`・`run` のうち `/` を含むもの）に、基準を示す語 `script` を書ける。`read script "assets"` は、実行を始めるスクリプトのディレクトリからの相対パス `assets` を表す。`script` を書かない宣言は、これまでどおり作業ディレクトリを基準にする。
3. `script` は、`permissions` の宣言の中でだけ意味を持つ語とし、キーワードにしない。

## 検討した代替案

- **文字列の接頭辞で基準を示す（`read "script:assets"`）**: 構文は変わらない。しかし、パスの一部と接頭辞を字面で見分けられず、`script:` で始まる名前のファイルを書けなくなる。
- **宣言のパスをすべてスクリプトのディレクトリ基準に改める**: import と基準が揃う。しかし、利用者がその場で渡すファイル（作業ディレクトリの `./out` など）を許可するには、作業ディレクトリを基準にする書き方が要る。
- **関数だけを加え、権限の宣言は変えない**: `read "*"` のように広く許可しない限り、スクリプトのディレクトリのファイルを読めない。広く許可すると、権限の宣言で読める範囲を示す意味が薄れる。

## 帰結

- Skill のスクリプトは、`read script "assets"` と宣言し、`Process.scriptDirectory()` で作ったパスで同梱のファイルを読める。
- 実行時の判定は、`script` を付けた宣言のパスを、実行を始めるスクリプトのディレクトリを基準に絶対パスにしてから行う。照合の規則は、作業ディレクトリを基準にする宣言と同じである。
- パスを組み立てる関数（ディレクトリとファイルの名前をつなぐものなど）は、標準ライブラリの `Path` などとして [OPEN-035](../open-issues.md#open-035) で定める。
