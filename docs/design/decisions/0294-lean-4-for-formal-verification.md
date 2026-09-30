# 0294. 形式検証の段階 2 に Lean 4 を使い、リポジトリの `formal/` に置く

- 状態: 採択
- 日付: 2026-09-30
- 関連章: [形式意味論と検証](../07-quality/07-04-formal-semantics.md)
- 関連する未決事項: [OPEN-069](../open-issues.md#open-069)

## 背景

形式検証の段階 2 を、初回リリース版の実装と並行して始めることにした（[ADR 0293](0293-formal-verification-stage-2-alongside-first-release.md)）。使う証明支援系と、形式化の置き場所と検査の方法を決める必要がある。

[設計メモ](../sources/fp-language-design.md) 25.3 は、候補として Coq（Rocq）、Agda、Lean 4、F*、K Framework、Iris、TLA+ を挙げた。対象はコア計算の型付けと抽象機械の性質（進行と保存、エフェクトの健全性）であり、並行処理は対象にしない（ADR 0293 の決定 4）。したがって、並行を扱う Iris と TLA+、書き換え論理で意味論を書く K Framework は、今回の対象に合わない。

2026-09-30 に、次の事実を一次資料で確かめた。

- Lean 4 は Apache-2.0 で提供される（GitHub の `leanprover/lean4`）。言語リファレンス（4.35.0-rc3 の版）は、Lean を「interactive theorem prover based on dependent type theory」であり「also a pure functional programming language」であると書き、参照カウントに基づく実行時の仕組みを持つと書く。ビルドの道具 Lake は「The Lean build tool, used to incrementally invoke `lean` and other tools while tracking dependencies」であり、ツールチェーンは elan が必要に応じて導入する。
- Rocq Prover は「formerly known as the Coq Proof Assistant」であり、LGPL-2.1 で提供される。証明した関数を OCaml・Haskell・Scheme のプログラムとして取り出せる（extraction）。
- Agda は「a dependently typed programming language / interactive theorem prover」であり、ライセンスの文面は MIT のものである。

## 決定

1. 段階 2 の証明支援系には Lean 4 を使う。
2. 形式化は、リポジトリの根の `formal/` に、Lake のプロジェクトとして置く。処理系の Cargo のワークスペースには含めない。使う Lean の版は、プロジェクトの `lean-toolchain` で固定する。
3. 形式化の検査は `lake build` で行う。完了条件の共通の検査（`scripts/check.sh`）には含めない。
4. 作業の途中では、証明を省く `sorry` を書いてよい。段階 A と段階 B は、それぞれの対象の定理に `sorry` が残らず、仮定として置く公理が[形式意味論と検証](../07-quality/07-04-formal-semantics.md)の「形式化で仮定するもの」に挙げたものだけになったときに完了とする。
5. 外部のライブラリ（Mathlib など）には、初めは依存しない。依存を加えるときは ADR に記録する。

## 検討した代替案

- **Rocq**: プログラミング言語の意味論の形式化に長く使われ、教材（Software Foundations）と、並行分離論理の Iris がある。extraction で証明した関数をプログラムとして取り出せる。Lean を選んだのは、Lean が関数型のプログラミング言語でもあり、取り出しの段を挟まずに定義をそのまま実行できるからである。抽象機械の定義を小さなプログラムで実行し、01-12 の規則の書き写しの誤りを証明の前に見つけられる。設計者の学ぶ対象（関数型プログラミング）とも重なる。ライセンスは開発に使う道具のものであり、処理系の配布物には含めないので、選択の理由にしていない。
- **Agda**: 設計メモは、パターンマッチによる定義が簡約規則と自然に対応することを挙げた。しかし、証明を組み立てる自動化（タクティク）の機能が Lean と Rocq より小さい【要検証】と見込み、継続とストアの型付けのように場合の数が多い証明には向かないと判断した。
- **F\***: 設計メモは、SMT ソルバによる自動証明と、実装の検証まで見据える場合の候補として挙げた。処理系の実装の正しさは対象にしない（ADR 0293 の決定 4）ので、この利点を使わない。
- **形式化を処理系のクレートの中に置く、または別のリポジトリに置く**: 形式化は 01-12 の規則の写しであり、規則を直す ADR と同じコミットで直せるように、設計書と同じリポジトリに置く（[ADR 0040](0040-single-repository.md)）。Lean のツールチェーンは処理系のビルドに要らないので、Cargo のワークスペースと完了条件の検査からは外す。`fuzz/` を nightly の Rust を使うためにワークスペースから外したのと同じ扱いである。

## 帰結

- 形式化の作業を始めるときに、`formal/` を作り、AGENTS.md のディレクトリ構成の表に加える。
- Lean のツールチェーンの導入には、ネットワークが要る。ネットワークを使えないサンドボックスで起動する実装担当に形式化の作業を割り当てるときは、先にツールチェーンを導入しておく。
- 束縛する変数の表現などの形式化の表現は、段階 A の作業で選ぶ（[OPEN-069](../open-issues.md#open-069)）。
