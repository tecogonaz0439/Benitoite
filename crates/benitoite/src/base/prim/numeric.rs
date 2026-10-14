//! 幅付きの数の検査付き算術。定数評価と実行時の演算で、値の表現によらず計算を共有する
//! （設計書 02-05「定数の検査と評価」）。

/// 数の算術。整数の除算は零へ切り捨てる。
#[derive(Clone, Copy)]
pub(crate) enum ArithmeticOp {
    Add,
    Subtract,
    Multiply,
    Divide,
    Modulo,
}

/// 整数の演算で停止する条件。
#[derive(Clone, Copy)]
pub(crate) enum ArithmeticError {
    Overflow,
    DivisionByZero,
}

/// 各幅の Rust の検査付き演算を、言語の値の表現から分離する。
pub(crate) trait CheckedInteger: Copy + PartialEq {
    const ZERO: Self;
    fn add(self, rhs: Self) -> Option<Self>;
    fn subtract(self, rhs: Self) -> Option<Self>;
    fn multiply(self, rhs: Self) -> Option<Self>;
    fn divide(self, rhs: Self) -> Option<Self>;
    fn modulo(self, rhs: Self) -> Option<Self>;
}

macro_rules! checked_integer {
    ($($ty:ty),+ $(,)?) => {
        $(impl CheckedInteger for $ty {
            const ZERO: Self = 0;
            fn add(self, rhs: Self) -> Option<Self> { self.checked_add(rhs) }
            fn subtract(self, rhs: Self) -> Option<Self> { self.checked_sub(rhs) }
            fn multiply(self, rhs: Self) -> Option<Self> { self.checked_mul(rhs) }
            fn divide(self, rhs: Self) -> Option<Self> { self.checked_div(rhs) }
            fn modulo(self, rhs: Self) -> Option<Self> { self.checked_rem(rhs) }
        })+
    };
}
checked_integer!(i8, i16, i32, u16, u32, u64);

/// 同じ幅の整数を計算し、あふれと除数零を区別する。
pub(crate) fn integer_binary<T: CheckedInteger>(
    op: ArithmeticOp,
    a: T,
    b: T,
) -> Result<T, ArithmeticError> {
    if matches!(op, ArithmeticOp::Divide | ArithmeticOp::Modulo) && b == T::ZERO {
        return Err(ArithmeticError::DivisionByZero);
    }
    let value = match op {
        ArithmeticOp::Add => a.add(b),
        ArithmeticOp::Subtract => a.subtract(b),
        ArithmeticOp::Multiply => a.multiply(b),
        ArithmeticOp::Divide => a.divide(b),
        // 除数が零でない checked_rem の失敗は MIN mod -1 だけであり、言語では零となる。
        // 商を先に作ると、この剰余まであふれとして拒否してしまう。
        ArithmeticOp::Modulo => Some(a.modulo(b).unwrap_or(T::ZERO)),
    };
    value.ok_or(ArithmeticError::Overflow)
}

/// 符号付きの幅だけに単項の負号を提供する。
pub(crate) trait CheckedSignedInteger: CheckedInteger {
    fn negate(self) -> Option<Self>;
}

macro_rules! checked_signed_integer {
    ($($ty:ty),+ $(,)?) => {
        $(impl CheckedSignedInteger for $ty {
            fn negate(self) -> Option<Self> { self.checked_neg() }
        })+
    };
}
checked_signed_integer!(i8, i16, i32);

/// 符号付き最小値の負号を、折り返さずあふれとして返す。
pub(crate) fn integer_negate<T: CheckedSignedInteger>(a: T) -> Result<T, ArithmeticError> {
    a.negate().ok_or(ArithmeticError::Overflow)
}

/// 演算ごとに binary32 の結果を作る。無限大と NaN は停止条件にしない。
pub(crate) fn float32_binary(op: ArithmeticOp, a: f32, b: f32) -> Option<f32> {
    Some(match op {
        ArithmeticOp::Add => a + b,
        ArithmeticOp::Subtract => a - b,
        ArithmeticOp::Multiply => a * b,
        ArithmeticOp::Divide => a / b,
        ArithmeticOp::Modulo => return None,
    })
}
