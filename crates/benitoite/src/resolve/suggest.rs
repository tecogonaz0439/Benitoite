//! 綴りの近い名前の候補（設計書 02-04「誤りと修正案」）。

/// 候補にする編集距離の上限。
const MAX_DISTANCE: usize = 2;
/// 示す候補の数の上限。
const MAX_CANDIDATES: usize = 3;

/// `name` から編集距離が 2 以下の名前を、距離の小さい順（同じ距離なら辞書式の順）に最大 3 つ選び、
/// `` `a`, `b` `` の形につなげる。候補がなければ `None`。`name` 自身は候補にしない。
pub(super) fn candidates<'a>(
    name: &str,
    pool: impl IntoIterator<Item = &'a str>,
) -> Option<String> {
    let mut scored: Vec<(usize, &str)> = pool
        .into_iter()
        .filter(|c| *c != name)
        .filter_map(|c| {
            let d = levenshtein(name, c);
            (d <= MAX_DISTANCE).then_some((d, c))
        })
        .collect();
    scored.sort_unstable();
    scored.dedup();
    let picked: Vec<String> = scored
        .iter()
        .take(MAX_CANDIDATES)
        .map(|(_, c)| format!("`{c}`"))
        .collect();
    (!picked.is_empty()).then(|| picked.join(", "))
}

/// 文字（Unicode のスカラー値）を単位とするレーベンシュタイン距離。
/// 1 行分の表だけを持つ動的計画法で求める。
fn levenshtein(a: &str, b: &str) -> usize {
    let b: Vec<char> = b.chars().collect();
    let mut prev: Vec<usize> = (0..=b.len()).collect();
    let mut cur: Vec<usize> = Vec::with_capacity(b.len().saturating_add(1));
    for (i, ca) in a.chars().enumerate() {
        cur.clear();
        cur.push(i.saturating_add(1));
        for (j, cb) in b.iter().enumerate() {
            let diag = prev.get(j).copied().unwrap_or(usize::MAX);
            let up = prev.get(j.saturating_add(1)).copied().unwrap_or(usize::MAX);
            let left = cur.get(j).copied().unwrap_or(usize::MAX);
            let cost = usize::from(ca != *cb);
            let best = diag
                .saturating_add(cost)
                .min(up.saturating_add(1))
                .min(left.saturating_add(1));
            cur.push(best);
        }
        std::mem::swap(&mut prev, &mut cur);
    }
    prev.last().copied().unwrap_or(0)
}
