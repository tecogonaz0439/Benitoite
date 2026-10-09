//! テストの確認の操作の登録（設計書 06-04「期待の確認」、実装プラン 10-18「組み込みの関数の表の部分」）。
//! `Assert.Check` はテストの実行器が VM の中で処理するため、表の関数としては呼ばれない。
//! この本体に達した場合は処理系の不具合である。

use crate::builtins::iface::{BuiltinDecl, IoReply, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// `Benitoite.Assert.equal` の登録。確認は VM の中で処理する（実装プラン 10-18「Assert.Check の処理」）。
    name = "Benitoite.Assert.equal",
    io fn equal(ctx, actual: Value<'e>, expected: Value<'e>) -> IoReply<'e> {
        let _ = (ctx, actual, expected);
        Err(Stop::Internal(String::from("Assert operation reached the handler table")))
    }
}

builtin! {
    /// `Benitoite.Assert.notEqual` の登録。確認は VM の中で処理する（実装プラン 10-18「Assert.Check の処理」）。
    name = "Benitoite.Assert.notEqual",
    io fn not_equal(ctx, actual: Value<'e>, expected: Value<'e>) -> IoReply<'e> {
        let _ = (ctx, actual, expected);
        Err(Stop::Internal(String::from("Assert operation reached the handler table")))
    }
}

builtin! {
    /// `Benitoite.Assert.isTrue` の登録。確認は VM の中で処理する（実装プラン 10-18「Assert.Check の処理」）。
    name = "Benitoite.Assert.isTrue",
    io fn is_true(ctx, condition: Value<'e>, message: Value<'e>) -> IoReply<'e> {
        let _ = (ctx, condition, message);
        Err(Stop::Internal(String::from("Assert operation reached the handler table")))
    }
}

builtin! {
    /// `Benitoite.Assert.fail` の登録。確認は VM の中で処理する（実装プラン 10-18「Assert.Check の処理」）。
    name = "Benitoite.Assert.fail",
    io fn fail(ctx, message: Value<'e>) -> IoReply<'e> {
        let _ = (ctx, message);
        Err(Stop::Internal(String::from("Assert operation reached the handler table")))
    }
}

/// 表の部分。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[equal::DECL, not_equal::DECL, is_true::DECL, fail::DECL];

#[cfg(test)]
mod tests {
    use crate::pipeline::{CheckOptions, check_text};

    #[test]
    fn assert_effect_and_equal_call_typecheck_without_main() {
        // 表だけの照合では確かめられない、prelude の操作の解決と @test のエフェクトの
        // 接続を公開の検査の入口で確かめる（実装プラン D00「受け入れテスト」）。
        let result = check_text(
            "assert.bnt",
            b"@test\nfunction equalValues() -> Unit uses Assert.Check\n  checkEqual()\nend function\n\nfunction checkEqual() -> Unit uses Assert.Check\n  Assert.equal(1, 1)\nend function\n",
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
        assert!(result.program.is_some(), "{:?}", result.diagnostics);
    }
}
