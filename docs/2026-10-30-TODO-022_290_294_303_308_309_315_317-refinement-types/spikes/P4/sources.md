# 読んだ元と写しの境界

対象の HEAD は `80e8127a4f7edff946529153b2002666cc35edc1`。本番 `formal/` と HEAD のソースの差分は読み取り専用の `git diff --exit-code HEAD -- formal` で0件と確認した。git の書き込み操作は行っていない。

| 入力 | 参照した位置 | P4 での扱い |
|---|---|---|
| `spikes/prompts/P-common.md` | 全文 | 出力範囲・時間・検査・公理の制約 |
| 改造の `reviews/RV-P3.md` | S1、M1〜M5、本番に残る命題1〜10 | 評価する問いと残る義務 |
| `spikes/P3/P3b-Nat.lean` | 14〜260行 | Nat/自己束縛/upSub、Ty.WF・Ty.Le.substAt/shift のアダプタ。P4 は観測の項と述語を新規定義した |
| `spikes/P3/P3b-Derivations.lean` | 13〜139、145〜230、700〜934行 | 部分的な観測・四種の像・導出の相互帰納の形。意味の Γ と World/Ty.Mem は写していない |
| `spikes/P3/M6Body.lean` | 17〜40、149〜173行 | 三条件と証明書から葉へ渡す接続の問い。P1.TyLe への証明を P4 の結果として引用していない |
| `spikes/P2/lean/P2.lean` | 全562行 | `P2.lean` へ内容をそのまま複写。P2 の検査器と健全性を再コンパイルして import。新しい公理や意味の含意の登録口は追加していない |
| `formal/Benitoite/Release/Types.lean` | 42〜70行 | 本番 Ty・Eff を import |
| `formal/Benitoite/Release/TypeBounds.lean` | Ty.WF、215〜220行の移動の補題など | RefTy.WF と移動で使用 |
| `formal/Benitoite/Release/Lemmas/Basic.lean` | 62〜109行 | 旧部分型の反射・推移・逆転・substAt・shift を使用 |
| `formal/Benitoite/Release/Syntax.lean` | 234〜269行 | 本番 Val と checkedRequest の保持値を使用 |
| `formal/Benitoite/Release/Typing.lean` | 523〜591行 | Native の通常の型付けの証拠と各具体例で使用 |
| `formal/Benitoite/Release/ModelHttp.lean` | 56〜57、85〜96、188〜190、622〜633、642〜813行 | 名目の ClientRequest、URL 射影、現行 valueRun の groundVal の分岐、実例の値と型付けを使用 |
| `docs/design/00-overview/00-01-goals.md` | 全文 | 保証の範囲と自作する対象を確認 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「要求を持たない V-Checked」の決定（287行付近） | RequestIn の新条件を既存保証の穴として扱わず、0.0.14 で改める決定として整理 |

`Logic.lean` の Value は、本番の閉じた値の不変な観測に必要な構造の写しである。`Production.observe` が本番 Val から写す。実行の遷移、閉包の呼出し、セルの内容は解釈しない。閉包は元の Val を不透明なコードとして保持し、未対応の値も元の Val を保持する。異なる閉包や未対応の値を一つのダミー値へまとめていない。

`Context.lean` の RefTy は最外の篩のアダプタである。`Derivations.lean` は入れ子の篩・型/行/範囲/値の像を扱う別の構文の型判断である。`adapter_le` で両者の葉と部分型の接続を示したが、全本番型の表現の同値や bind の全面的な可換性を示したわけではない。`TyQ.native` は本番の閉じた型を置くための枝であり、開いた型の変数を持つ native を θ.types で置換できるとは主張しない。開いた像の代表は TyQ.var と EffQ.row を使う。
