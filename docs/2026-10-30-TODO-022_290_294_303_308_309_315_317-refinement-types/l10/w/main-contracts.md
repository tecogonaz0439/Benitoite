# 主な契約と既存読者の不変の確認

指定 B_WORK は `d3a22dfb5dff5525888e4332e4bb978a4961074c`。開始時のファイルの SHA-256 と作業末の内容を比較した。git は使っていない。前提・結論の変更や、既存の導出の場合の除外はない。

| ファイル（formal/Benitoite/Release/Refinement/ 以下） | 開始時と末尾で同じ SHA-256 |
|---|---|
| `SubstTyping.lean` | `a9aaae2821909d19f2ae17a111820819490cb0e91f6eb19fc107d9fca40f91e9` |
| `TypingShift.lean` | `3c7b01371af2e7c79134ea61366e6b6202a326fa920ab8cfe3b3f4d75b3b33e4` |
| `TypeShiftTyping.lean` | `ff010182529add97563b87fb771d4c1b0a5bae184c2689efd4810415726205a5` |
| `Narrowing.lean` | `8c77b2076e5cd4c03506f433b8547527cd2488bf6346a009b7c25f24fd119519` |
| `Typing.lean` | `31d39d5fe06513d04f3fa0b1c2c72e2764e67cf529ab442c5ccd1f21ac19b643` |
| `Le.lean` | `78aa058f7d83bb7c86c7f50f1501a6c11d3c2603661430b8b5e01e1396f8511c` |
| `Patterns.lean` | `8cfe43476d71d18bacf53f6cb91f642f77197e4b2302027af1ec1820a2e9db2f` |
| `StateTyping.lean` | `9013eeb2017b040ee639abc873bf0ff29abc8e1ef59ddfe00ad76f749f47bb31` |
| `ValueMeaningInhabits.lean` | `d742e0f49ec631361dfc678839bebf0a4a739ff764ae01615e5617ba8b8a7031` |

型付け相互群は76規則、四本の移送の304枝は既存のままである。subst_under_none は既存の subst の系を含めて別に公理依存を確認した。LeQ/TelLe/TelClosure/TypeArgsLe の22規則と、網羅性の群Xの読者を既定importから除外していない。今回の新規の証明の枝数を304と記録しない。
