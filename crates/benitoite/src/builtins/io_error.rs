//! IoError.message と IO 失敗の共有文言（設計書 01-07「IO の失敗」）。

use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::value::Value;

/// テストと本番のハンドラ表で共有する IO 失敗の文言。
pub mod text {
    /// ファイルがないときの文言。
    pub const MSG_NOT_FOUND: &str = "No such file or directory (os error 2)";
    /// ファイルの内容が正しい UTF-8 でないときの文言。
    pub const MSG_INVALID_UTF8: &str = "file is not valid UTF-8";
}

/// IoError の文言を文字列として返す。
///
/// IO 失敗を値として扱うため、エラーの理由をそのまま読み取れるようにする。
pub fn message(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    let Some(message) = args.first().and_then(Value::as_io_error) else {
        return Err(invalid_arguments());
    };
    Ok(heap.string(message))
}

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("IoError.message received invalid arguments"))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // IoError.message が IO 失敗の文言を変えずに返すことを公開関数で確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::runtime::heap::Heap;

    use super::message;

    #[test]
    fn message_returns_the_io_error_text() {
        let mut heap = Heap::new();
        let error = heap.io_error(String::from("file could not be read"));
        let message = message(&mut heap, &[error]).unwrap();

        assert_eq!(message.as_str(), Some("file could not be read"));
    }
}
