//! 取り込みのない Fuzzy のコンポーネント。
//! 文字列は Unicode のスカラー値で比べる。

wit_bindgen::generate!({
    world: "fuzzy",
    path: "../wit",
});

struct Component;

impl Guest for Component {
    /// 編集距離を、Unicode のスカラー値（Rust の char）を単位に数える。
    /// Benitoite の String.characters と同じ単位なので、Benitoite の版と同じ結果になる。
    fn distance(a: String, b: String) -> i64 {
        let a: Vec<char> = a.chars().collect();
        let b: Vec<char> = b.chars().collect();
        let mut previous: Vec<usize> = (0..=b.len()).collect();
        let mut current = vec![0usize; b.len() + 1];
        for (i, ca) in a.iter().enumerate() {
            current[0] = i + 1;
            for (j, cb) in b.iter().enumerate() {
                let cost = usize::from(ca != cb);
                current[j + 1] = (previous[j + 1] + 1)
                    .min(current[j] + 1)
                    .min(previous[j] + cost);
            }
            std::mem::swap(&mut previous, &mut current);
        }
        // 文字列の長さは i64 に収まるので、変換は失敗しない。
        i64::try_from(previous[b.len()]).unwrap_or(i64::MAX)
    }
}

export!(Component);
