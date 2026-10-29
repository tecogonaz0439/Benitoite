# 試行 T の読者と診断

基準は `bbc22ac0913910d26936f4b2e2def2204da93c4f` である。原子の2構成子へ `Range` を追加し、`Copy` を除いた直後に `cargo check -p benitoite --all-targets` を実行した。終了101、外側10.640秒、補助のRSSは2,076,377,088 bytes（1,980.1875 MiB）である。[全出力](check.log)・[終了と時間](check.json)・[試行差分](representation.patch)を保存した。差分には先行した `host_mask` の修正も含む。

`EffectName::` の探索は src が17ファイル56箇所（55行）、tests が3ファイル6箇所であり、計画のsrc 17ファイル56箇所・tests 3ファイルと一致する。srcの56箇所には説明コメント1箇所を含む。実行するコードは機械34・意味21、testsは機械1・意味5である。機械は明示のTopを渡す変更、意味は比較・分類・表示・出力境界の点検を要する箇所とした。「意味」は言語の規則を変える件数を表さない。

ファイル／宣言ごとの一意数と診断の対応は[分類表](reader-tables.md)に示す。[箇所の記録](name-readers.json)には元の行と分類、[診断の記録](diagnostics.json)にはコード・ファイル・行・列を保存した。同じlibとlib testの診断を重複計上しない一意の診断は70件、位置は68箇所・19ファイルである。名前の字面を持つ一意の宣言はsrc 37（コメントだけの1宣言を含む）、tests 4である。

## 最初の失敗の先にある読者

| 対象 | 初回の検査状況 | 追随後に閉じる範囲 |
|---|---|---|
| srcの本体 | libは42件、lib testは70件の診断で失敗した | 所有権の追随後に現れる誤りと、型が通る共有の読者を点検する |
| `tests/desugar_export/{builtins,exchange}.rs` | lib testもincludeするため、初回に5箇所の診断がある | 独立した統合ターゲットとしての実行は未検査である |
| `tests/declarations.rs` | libで止まり、名前の読者1箇所は初回未検査である | include先のexamplesも追随ビルドで検査する |
| ほかの統合ターゲットとexamples | libで止まったため初回未検査である | 全対象の追随ビルドと作業末の全統合で検査する |
| `examples/derive_inventory/schema.rs`・`try_actions_inventory.rs` | 初回未検査。追随ビルドで2ファイル4パターンの破損が判明した | 旧版の出力を保ち、非Topは明示的に拒否する必要がある。編集範囲を設計者へ確認した |

## 名前の字面だけでは見えない共有の読者

この表は名前の構築箇所へ重ねて数えない。ファイルと宣言の組で一意に列挙する。

| ファイル／宣言 | 分類・点検する契約 |
|---|---|
| `src/types/mod.rs`／`EffectSet::{insert_name,union,is_subset,subst_types}`・`Ty::subst` | 意味。構造の比較と範囲の複写、Failの中の関数型と行を確認する |
| `src/typeck/infer.rs`／`IEffect` | 意味。固定部分はEffectSetの構造をそのまま保持する |
| `src/typeck/context.rs`／`substitute_effect` | 意味。固定した原子を複写し、行の像を構造の和で合成する |
| `src/typeck/solve.rs`／`Elem`・`propagate_effects`・`elements`・`includes`・`insert` | 意味。集合の要素と由来の鍵を範囲ごと保持し、CopyをCloneまたは借用へ変える |
| `src/typeck/solve/effect_key.rs`／`EffectConstraintKey::new` | 意味。固定部分のEq/HashとFailの前置順のキーを確認する |
| `src/typeck/solve/provenance.rs`／`recovered_type`・`record_provenance`等 | 意味。関数型の固定部分を保持し、型を含む部分だけを辿る |
| `src/ir/desugar/decls.rs`／`program` | 意味。操作の原子を範囲ごと複写する |
| `src/ir/desugar/effects.rs`／`subtract` | 意味。原子の構造だけで差を取る |
| `src/ir/decision/arena.rs`／`ty_bytes` | 意味。範囲が所有する要素列と文字列の動的メモリも複写前に数える。初回の診断には現れない |

初回診断は全読者の一覧の代わりにならない。共有の構造を読むだけで変更が不要な宣言も、後続の検査と結果記録の対象に含める。
