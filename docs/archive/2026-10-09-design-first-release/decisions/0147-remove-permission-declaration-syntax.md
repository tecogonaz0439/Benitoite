# 0147. 権限の宣言の構文（`permissions`）を削除し、実行時の権限制御の方式を改めて決める

- 状態: 採択（決定 3 の権限の種類を [0184](0184-permissions-granted-per-builtin-effect.md) でエフェクトの単位に改めた）
- 日付: 2026-09-28
- 関連章: [字句構造](../01-spec/01-01-lexical.md), [構文](../01-spec/01-02-syntax.md), [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md), [エフェクト](../01-spec/01-07-effects.md), [評価意味論](../01-spec/01-08-evaluation.md), [エラー処理](../01-spec/01-09-errors.md), [コア計算と脱糖](../01-spec/01-12-core-calculus.md), [IO のモジュール](../03-interop/03-07-io-modules.md), [ネットワークのモジュール](../03-interop/03-09-network.md), [CLI](../06-tooling/06-01-cli.md), [利用者プログラムのテスト](../06-tooling/06-04-test-runner.md), [セキュリティモデル](../07-quality/07-01-security-model.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045)（本 ADR で決着）, [OPEN-052](../open-issues.md#open-052), [OPEN-015](../open-issues.md#open-015), [OPEN-037](../open-issues.md#open-037)

## 背景

初回リリース版では、実行を始めるモジュールに `permissions ... end permissions` の宣言を書き、処理系は宣言にない操作を実行時に拒否することにしていた（[ADR 0071](0071-permission-declaration-and-runtime-denial.md)）。宣言のパスの照合（[ADR 0072](0072-permission-path-matching.md)）、コマンドの照合（[ADR 0073](0073-run-permission-command-matching.md)）、宣言にない種類の権限を実行の前に誤りとする検査（[ADR 0074](0074-static-permission-check-by-name-reference.md)）、スクリプトのディレクトリを基準にする語 `script`（[ADR 0131](0131-script-directory-and-permission-base.md)）も、この宣言を前提にしていた。ネットワークの操作の権限の書き方は [OPEN-045](../open-issues.md#open-045) に残していた。

設計者は、権限の制御を、ソースコードに書く静的な宣言ではなく、処理系の側で実行時に動的に行う方式に改めることを検討している。方式は、セキュリティの検討とあわせて決める。ネットワークの権限の書き方を宣言の構文に加える前に、構文を削除する。

## 決定

1. 権限の宣言の構文を削除する。`permissions ... end permissions` の宣言、文法の規則 `PermDecl` と `Perm`、宣言の中の語 `script` を設けない。`permissions` はキーワードにしない。
2. 宣言を前提にした次の規則を削除する。
   - 宣言は実行を始めるモジュールにだけ書けること、宣言を置く位置（[ADR 0071](0071-permission-declaration-and-runtime-denial.md) の決定 1）
   - 要する種類の権限が宣言にないプログラムを、実行の前に誤りとすること（ADR 0071 の決定 3、[ADR 0074](0074-static-permission-check-by-name-reference.md) の決定 3・4）
   - 宣言の相対パスを、スクリプトのディレクトリから辿る書き方（[ADR 0131](0131-script-directory-and-permission-base.md) の決定 2・3）
3. 次の規則は、宣言の構文によらないので残す。ただし、許可の与え方を決めるときに見直すので、【方針】として扱う。
   - 処理系は、許可していない操作を実行時に拒否し、実行時エラー（権限の拒否）とする（ADR 0071 の決定 2）。
   - 権限の種類（`read`・`write`・`run`・`shell`・`environment`・`exit`）と、各関数が要する権限の種類（ADR 0074 の決定 1）。
   - 実行の前に、権限を要する関数を名前で参照しているかで、プログラムが要する権限の種類を判定すること（ADR 0074 の決定 2）。判定の結果は、実行前の権限の表示に使う。
   - 許可したパスと操作の対象のパスの照合（[ADR 0072](0072-permission-path-matching.md)）と、許可したコマンドの照合（[ADR 0073](0073-run-permission-command-matching.md)）。
   - `Process.scriptDirectory()`（ADR 0131 の決定 1）。
4. 実行時の権限制御の方式（許可をソースコードの外でどう与えるか、許可の単位を権限の種類とエフェクトのどちらにするか、ネットワークの操作の権限など）は、新しい未決事項 [OPEN-052](../open-issues.md#open-052) で決める。[OPEN-045](../open-issues.md#open-045) の残りの論点は OPEN-052 に移す。

## 検討した代替案

- **宣言の構文を残し、ネットワークの権限を加える**: [OPEN-045](../open-issues.md#open-045) をそのまま進められる。しかし、実行時の動的な制御に改めるなら、加えた構文はまた削除することになる。構文を削除すると、スクリプトは許可の内容を持たないので、利用者は実行するたびに許可を与える手順が要る。この手順は OPEN-052 で方式とあわせて決める。
- **方式が決まるまで、宣言の構文を【未決】として残す**: 削除の判断を先に延ばせる。しかし、LLM が生成するスクリプトと例に、なくなる見込みの構文が残る。例と文法の検査の道具も、構文を読み続けることになる。

## 帰結

- [OPEN-045](../open-issues.md#open-045) を決着とし、ネットワークの操作の権限の論点を [OPEN-052](../open-issues.md#open-052) に移す。
- [ADR 0071](0071-permission-declaration-and-runtime-denial.md)・[0072](0072-permission-path-matching.md)・[0073](0073-run-permission-command-matching.md)・[0074](0074-static-permission-check-by-name-reference.md)・[0131](0131-script-directory-and-permission-base.md) の一部を本 ADR で改める。宣言の構文を前提にした [ADR 0055](0055-top-level-functions-and-types-only.md)・[0101](0101-unabbreviated-names.md)・[0108](0108-keyword-blocks-closed-by-end.md)・[0120](0120-test-functions-and-assert-effect.md)・[0127](0127-directory-run-and-root.md)・[0135](0135-shebang-line-and-implicit-run.md) の記述も、本 ADR で改める。
- 初回リリース版のスクリプトは、権限の宣言を書かない。ファイルを読むスクリプトに宣言が要るという、最小実行版との非互換（ADR 0074 の決定 4）はなくなる。
- 許可の与え方が決まるまで、初回リリース版の実行時の権限制御は、拒否の規則と照合の規則だけが【方針】として決まった状態になる。
- テストの実行で実際に行う IO に与える許可（[ADR 0120](0120-test-functions-and-assert-effect.md) の決定 5）と、実行時の権限制御を OS のサンドボックスでも強制する方式（[OPEN-037](../open-issues.md#open-037)）は、OPEN-052 の方式に合わせて決める。
