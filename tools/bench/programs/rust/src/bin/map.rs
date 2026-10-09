//! Map と Set の更新と探索を比べる（設計書 07-02「初回リリース版の完了時の測定」）。

use std::collections::{BTreeMap, BTreeSet};

fn main() {
    let count: usize = std::env::args().nth(1).unwrap().parse().unwrap();
    let mut seed = 1_i64;
    let keys: Vec<_> = (0..count)
        .map(|_| {
            seed = (seed * 48271 + 11) % 2147483647;
            seed
        })
        .collect();
    let mut m = BTreeMap::new();
    let mut s = BTreeSet::new();
    for &key in &keys {
        m.insert(key, key);
    }
    for &key in &keys {
        s.insert(key);
    }
    let map_found = keys.iter().filter(|key| m.get(key).is_some()).count();
    let set_found = keys.iter().filter(|key| s.contains(key)).count();
    for key in keys.iter().step_by(2) {
        m.remove(key);
        s.remove(key);
    }
    println!("{}\n{}\n{}\n{}", m.len(), s.len(), map_found, set_found);
}
