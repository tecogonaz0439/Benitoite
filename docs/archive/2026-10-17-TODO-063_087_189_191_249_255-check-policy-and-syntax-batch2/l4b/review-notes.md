# RV2最終レビューへの照合資料

実装担当Codexの自己点検である。planのレビュー担当Opusの最終判断を代行しない。開始版はaffb710656ee011d1a49dd75f993d536dfd237c6である。

## 定義・言明・仮定

| 確認事項 | 正式なLeanと写し | 自己点検 |
|---|---|---|
| 固定全順序、有限支持上の比較・正規化 | Release/Order/Atoms・Types、Finite、Normalize。01-12「構文」、07-04「01-12との対応」 | 比較成功からの等号と支持条件、正規化の冪等性・Legacyでの恒等性を保つ。交換はEff.normWithへ接続し、Fail内部の支持も収集する |
| 同時代入と一般の合成 | TypeComposition・TypeSubstLemmas・TypeScopedSubst・FiniteSupport | L4bはこれらを変更しない。交換の型と効果を相互再帰させ、型の内部のFailにも同じ変換を適用する |
| Qcallee/Qcaller、署名からのQ | NoFail・Admissible、Surface/NoFailCheck | 新しい信頼するQを追加しない。effParamsのBoolはsignatureQと照合し、本文から不足分を補わない |
| Failの捕捉・K1・保存継続・解放 | Release/Typing・PresFailureと既存Theorems。01-12「形式化した型付き失敗の捕捉」 | 型の一致を仮定せず、L2b/cの証明を保つ。L4bで主定理・型付け・実行規則を変更していない |
| 表層の具体化後の単一Fail、EとrigidなT | Surface/SingleFail・SingleFailCheck・CheckControl・CheckSoundControl。01-12「型付きの失敗の表層検査」 | 交換で複数Failを一律に拒否しない。独立入力では読者の受理と、表層の許容効果での拒否を分けて検査する |
| 辞書の所属、全呼び出しと値化 | Surface/Syntax・Lemmas/Dict・Lemmas/Typing。01-12「形式化した操作の制約と節の辞書」 | DictEv.clauseの所属・制約番号・深さを交換する。通常節の公開arityとコアの合計arityを区別し、直接の頭と値化で潜在効果を照合する |
| 文字全域、将来の構成子、補題Uと系 | Release/Coverage・CoverageExtension・CoverageRuntime。01-12の網羅性の写し | L4aの証明を変更しない。Character全域を独立したcoverage入力で受理し、既存の全corpusとの比較は、文字の判定と表示の不一致を検出したため停止条件に該当する |
| 六入口と旧版互換 | Exchange/Version・Convert・CheckInput、六入口のMain/Walk | corpus8/9/10と他形式2/3を維持し、11/4だけに新欄を許す。lakefileの既定対象を減らしていない |

L4bのLeanの差分は交換と六入口だけである。Core・Release・Surfaceの型付け、主要定理・健全性11件の証明、Builtins.Assumptionsに差分はない。01-12・07-04の既存の「交換には未接続」という説明を、Leanの読者の接続とRustの未接続を区別する文へそろえた。01-12の規則・見出し・コード例は変えていない。

formal/README.mdにある30件の `#print axioms` の確認は [axioms-final.log](axioms-final.log) に残す。標準のpropext・Classical.choice・Quot.sound以外の公理とsorryAxはない。最初に根からlakeを呼んだ確認はツールチェーンの選択前にOperation not permittedとなり、formal/を作業ディレクトリにした確認で成功した。証明に変更を加えて通したものではない。

## 独立レビューへ渡すもの

交換の具体的な必須欄とO2/F3の受け渡しは [exchange-contract.md](exchange-contract.md)、実行した検査と旧出力の件数は [results.md](results.md) に集める。RV2の初回指摘とL2a後の指摘、R14・R21・R24以降の了承済みの具体化を、実際の定義・言明・写しに照合して最終レビューを閉じる担当は取りまとめである。L4bの実装者の自己点検と、独立レビューを区別する。

旧出力の全比較は終了1だった。文字の網羅性の不一致に加え、表層のハンドラ12件とroutingManifestの差も未解決であり、RV2の閉鎖条件を満たしていない。詳細と再現資料はresults.mdに記録した。
