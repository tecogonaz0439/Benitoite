//! Lean の自然数符号に従う交換原子の順序（設計書 07-04「交換の形式の版」）。

use serde_json::Value;
use std::cmp::Ordering;

// Cantor の対は IPv6 の 128 ビットからも幅を増すため、固定幅整数へ丸めない。
// 基数 2^32 の下位桁から保持し、交換の整列だけに必要な演算を使う。
#[derive(Clone, Debug, PartialEq, Eq)]
struct Nat(Vec<u32>);

impl Nat {
    fn new(mut n: u128) -> Self {
        let mut digits = Vec::new();
        while n != 0 {
            digits.push(u32::try_from(n & u128::from(u32::MAX)).unwrap());
            n >>= 32;
        }
        Self(digits)
    }

    fn normalize(&mut self) {
        while self.0.last() == Some(&0) {
            self.0.pop();
        }
    }

    fn add(&self, other: &Self) -> Self {
        let mut result = Vec::new();
        let mut carry = 0u64;
        for i in 0..self.0.len().max(other.0.len()) {
            let n = u64::from(*self.0.get(i).unwrap_or(&0))
                + u64::from(*other.0.get(i).unwrap_or(&0))
                + carry;
            result.push(u32::try_from(n & u64::from(u32::MAX)).unwrap());
            carry = n >> 32;
        }
        if carry != 0 {
            result.push(u32::try_from(carry).unwrap());
        }
        Self(result)
    }

    fn mul(&self, other: &Self) -> Self {
        let mut result = vec![0u32; self.0.len() + other.0.len()];
        for (i, &a) in self.0.iter().enumerate() {
            let mut carry = 0u64;
            for (j, &b) in other.0.iter().enumerate() {
                let n = u64::from(a) * u64::from(b) + u64::from(result[i + j]) + carry;
                result[i + j] = u32::try_from(n & u64::from(u32::MAX)).unwrap();
                carry = n >> 32;
            }
            result[i + other.0.len()] = u32::try_from(carry).unwrap();
        }
        let mut result = Self(result);
        result.normalize();
        result
    }

    fn half(&mut self) {
        let mut carry = 0u32;
        for digit in self.0.iter_mut().rev() {
            let next = *digit & 1;
            *digit = (*digit >> 1) | (carry << 31);
            carry = next;
        }
        self.normalize();
    }

    fn affine(&self, multiplier: u32, offset: u32) -> Self {
        self.mul(&Self::new(u128::from(multiplier)))
            .add(&Self::new(u128::from(offset)))
    }
}

impl Ord for Nat {
    fn cmp(&self, other: &Self) -> Ordering {
        self.0
            .len()
            .cmp(&other.0.len())
            .then_with(|| self.0.iter().rev().cmp(other.0.iter().rev()))
    }
}

impl PartialOrd for Nat {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

// 以下は Release/Order/Range.lean と Order/Atoms.lean の自然数符号。
fn pair(a: &Nat, b: &Nat) -> Nat {
    let sum = a.add(b);
    let mut triangle = sum.mul(&sum.affine(1, 1));
    triangle.half();
    triangle.add(a)
}

fn string(s: &str) -> Nat {
    s.chars().rev().fold(Nat::new(0), |tail, c| {
        tail.affine(1_114_113, u32::from(c) + 1)
    })
}

fn word(parts: &Value) -> Nat {
    parts
        .as_array()
        .unwrap()
        .iter()
        .rev()
        .fold(Nat::new(0), |tail, s| {
            pair(&string(s.as_str().unwrap()), &tail).affine(1, 1)
        })
}

fn number(value: &Value) -> Nat {
    Nat::new(
        value
            .as_str()
            .map_or_else(|| value.to_string(), str::to_owned)
            .parse()
            .unwrap(),
    )
}

fn family(value: &Value) -> Nat {
    Nat::new(match value.as_str().unwrap() {
        "v4" => 0,
        "v6" => 1,
        _ => panic!("unknown IP family"),
    })
}

fn host(value: &Value) -> Nat {
    if let Some(name) = value.get("name") {
        for (tag, offset) in [("exact", 0), ("one", 1), ("many", 2)] {
            if let Some(parts) = name.get(tag) {
                return word(parts).affine(3, offset).affine(2, 0);
            }
        }
        panic!("unknown host name pattern");
    }
    let ip = &value["ip"];
    let pattern = if let Some(a) = ip.get("exact") {
        pair(&family(&a["family"]), &number(&a["bits"])).affine(2, 0)
    } else if let Some(c) = ip.get("cidr") {
        pair(
            &family(&c["family"]),
            &pair(&number(&c["network"]), &number(&c["prefixLen"])),
        )
        .affine(2, 1)
    } else {
        panic!("unknown IP pattern");
    };
    pattern.affine(2, 1)
}

fn range(value: &Value) -> Nat {
    if value == "top" {
        return Nat::new(0);
    }
    if let Some(path) = value.get("path") {
        for (tag, offset) in [("exact", 0), ("tree", 1)] {
            if let Some(parts) = path.get(tag) {
                return word(parts).affine(2, offset).affine(4, 1);
            }
        }
        panic!("unknown path pattern");
    }
    if let Some(h) = value.get("host") {
        return host(h).affine(4, 2);
    }
    if let Some(e) = value.get("endpoint") {
        let ports = pair(&number(&e["ports"]["lo"]), &number(&e["ports"]["hi"]));
        return pair(&host(&e["host"]), &ports).affine(4, 3);
    }
    panic!("unknown range");
}

fn index(value: &Value) -> Nat {
    if let Some(fixed) = value.get("fixed") {
        range(fixed).affine(2, 0)
    } else {
        number(value.get("rvar").expect("range index")).affine(2, 1)
    }
}

fn code(atom: &Value) -> Nat {
    if let Some(name) = atom.get("name") {
        pair(
            &string(name["value"].as_str().unwrap()),
            &index(&name["ix"]),
        )
        .affine(2, 0)
    } else {
        number(&atom["rho"]["index"]).affine(2, 1)
    }
}

/// 名前と行の原子を、Lean の任意精度の自然数符号の昇順へそろえる。
pub(super) fn sort(atoms: &mut [Value]) {
    if atoms.len() > 1 {
        atoms.sort_by_cached_key(code);
    }
}
