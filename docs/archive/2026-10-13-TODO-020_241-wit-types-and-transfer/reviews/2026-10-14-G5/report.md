# Z2・P19〜P23（境界の照合と動的な変換）のレビュー

2026-10-14、Opus 5.5。範囲は `git diff 974c77fe 7f12443b -- crates`（生成物を除く）。cargo は走らせていない。

High はない。Z2 は G3 の M1・M3・L1 と G4 の High・Medium をすべて直した。数の幅の照合は幅と符号の組を一つずつ列挙し、食い違いを黙って受け付けない。flags は構成子の数 1〜32 と引数なしを確かめ、map の鍵は Bool・各幅の整数・Char・String に限り、重複した鍵は後の値を残す。総称の展開は明示のスタックと予算で辿り、有限の入れ子を通して循環を拒む。外部の型は合成の型の中まで辿る。転送の予算は新しい形でも検査と統計で同じ量を数え、確保は予算の検査の後に行う。弱めたテストはない。

## Medium

1. `diag/codes.rs` の E1010 の `types` の注記の、渡せる型の一覧が古い（新しい数の型、Map、flags としての `Set[D]`、tuple に写す一構成子の data がない）。一覧に加え、gen_skill で作り直す。

## Low

1. `external/expansion.rs` の `check_dependencies`: `checked` を `walk` ごとに作り直すので、宣言の依存の走査が引数ごとに繰り返され、予算にも数えない。検査全体で共有するか、量を予算に数える。
2. `external/types.rs` の `plan` の `Visit::Leave`: 子が足りないときに黙って短い列を返し、続く Record の `zip` も切り詰める。不足したら `unsupported` を返す。
3. `expansion.rs` の `ExpansionError::Recursive`: 循環した宣言ではなく入口の型を示す。循環した宣言の名前を注記に添える。
4. `types.rs` の `declaration()` は、新しい合成の型に案内を出さない。設計どおりなら 03-10 に書く。

## P24〜P29 への注意

- `WitPlan::Tuple`（Pair・Triple）は言語へ戻すとき長さによらず `tags::PAIR` で値を作り、タグを持たない。ConstructorTuple はタグを持つ。転送形式で一つの表として扱う前に、Pair と Triple のタグの決め方を確かめる。
- `WitPlan::Flags.cases` は WIT の順で並ぶので、添字をビットの位置に使える。
- map の鍵の幅は数の幅どおりに配置する。
- 動的な経路には構築量という別の量がないので、P32 で二つの経路の量を比べる前提にしない。
