//! 純粋な生成器と実行ごとの隠れた乱数の共通の計算（設計書 03-07「Random」）。

/// 純粋な生成器と実行開始時の種の設定は、同じ展開手順を使う（設計書 03-07「Random」）。
pub(crate) fn seeded_state(mut seed: u64) -> [u64; 4] {
    std::array::from_fn(|_| {
        seed = seed.wrapping_add(0x9e3779b97f4a7c15);
        let mut value = seed;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
        value ^ (value >> 31)
    })
}
/// 生成する列を変えずに、両方の生成器で同じ一歩を使う（設計書 03-07「Random」）。
pub(crate) fn next(state: &mut [u64; 4]) -> u64 {
    let [a, b, c, d] = *state;
    let value = b.wrapping_mul(5).rotate_left(7).wrapping_mul(9);
    *state = [
        a ^ d ^ b,
        b ^ c ^ a,
        c ^ a ^ b.wrapping_shl(17),
        (d ^ b).rotate_left(45),
    ];
    value
}
