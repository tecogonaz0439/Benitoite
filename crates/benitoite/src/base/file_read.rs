//! CLI とモジュール読込が共有する、普通のファイルの上限付き読み込み
//! （設計書 02-04「モジュールの探し方」、06-01「`fmt` のコマンドライン（初回リリース版）」、
//! 06-06「Skill の導入（初回リリース版）」）。

use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

use rustix::fs::{Mode, OFlags};

mod text {
    pub(super) const NOT_REGULAR: &str = "not a regular file";
}

/// 普通のファイルを、上限を超えたか判定するための 1 バイトを含めて読む。
/// 上限の超過の報告は呼び出し側が行う。`no_follow` なら末尾のシンボリックリンクも拒む。
pub(crate) fn read_regular_file(path: &Path, limit: usize, no_follow: bool) -> io::Result<Vec<u8>> {
    let mut flags = OFlags::RDONLY | OFlags::NONBLOCK | OFlags::CLOEXEC;
    if no_follow {
        flags |= OFlags::NOFOLLOW;
    }
    // 開く前に種類を検査すると、検査後に FIFO へ差し替えられて open が停止しうる。
    // NONBLOCK で開いた記述子を検査してから読み、デバイスやディレクトリも拒む。
    let file = File::from(rustix::fs::open(path, flags, Mode::empty())?);
    if !file.metadata()?.is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            text::NOT_REGULAR,
        ));
    }
    read_limited(file, limit)
}

fn read_limited(reader: impl Read, limit: usize) -> io::Result<Vec<u8>> {
    let cap = u64::try_from(limit)
        .ok()
        .and_then(|n| n.checked_add(1))
        .unwrap_or(u64::MAX);
    let mut bytes = Vec::new();
    reader.take(cap).read_to_end(&mut bytes)?;
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装の規約「`#[allow]` を書いてよい箇所」）。
    #![allow(clippy::unwrap_used)]

    use super::*;
    use std::io::Cursor;

    // 関門: 上限の判定用の 1 バイトより後は読まない（読み手の位置を独立に観測する）。
    #[test]
    fn reads_at_most_one_byte_past_the_limit() {
        for (limit, expected) in [(0, 1), (3, 4), (7, 8), (8, 8)] {
            let mut input = Cursor::new(b"12345678");
            let bytes = read_limited(&mut input, limit).unwrap();
            assert_eq!(bytes.len(), expected);
            assert_eq!(input.position(), u64::try_from(expected).unwrap());
        }
    }
}
