//! 大きさを確かめる構築（設計書 02-09「一つの操作で作る値の大きさの上限」、ADR 0049）。

use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop};

/// 上限を確かめた長さ（文字列と `Bytes` はバイト数、リストは要素の数）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct CheckedLen {
    len: u32,
}

impl CheckedLen {
    /// 文字列と `Bytes` の大きさを確かめる。`function` は報告に使う関数の名前。
    pub fn bytes(len: u64, function: &'static str) -> Result<CheckedLen, Stop> {
        Self::check(len, MAX_STRING_BYTES, SizeUnit::Bytes, function)
    }

    /// リストの長さを確かめる。
    pub fn elements(len: u64, function: &'static str) -> Result<CheckedLen, Stop> {
        Self::check(len, MAX_LIST_LEN, SizeUnit::Elements, function)
    }

    pub fn get(self) -> u32 {
        self.len
    }

    fn check(
        len: u64,
        limit: u64,
        unit: SizeUnit,
        function: &'static str,
    ) -> Result<CheckedLen, Stop> {
        let too_large = Stop::Resource(ResourceError::ValueTooLarge {
            function,
            size: len,
            unit,
            limit,
        });
        if len > limit {
            return Err(too_large);
        }
        match u32::try_from(len) {
            Ok(len) => Ok(CheckedLen { len }),
            Err(_) => Err(too_large),
        }
    }
}

/// 上限を確かめながら文字列を作る場所。`ValueCtx::alloc_str_buf` で文字列の値にする。
#[derive(Debug)]
pub struct StrBuf {
    buf: String,
    function: &'static str,
}

impl StrBuf {
    pub fn new(function: &'static str) -> StrBuf {
        StrBuf {
            buf: String::new(),
            function,
        }
    }

    /// 加えた後の大きさが上限を超えるなら、加えずに資源の不足を返す。
    pub fn push_str(&mut self, s: &str) -> Result<(), Stop> {
        let new_len = u64::try_from(self.buf.len())
            .ok()
            .and_then(|n| n.checked_add(u64::try_from(s.len()).ok()?))
            .unwrap_or(u64::MAX);
        CheckedLen::bytes(new_len, self.function)?;
        self.buf.push_str(s);
        Ok(())
    }

    pub fn push_char(&mut self, c: char) -> Result<(), Stop> {
        let mut tmp = [0u8; 4];
        self.push_str(c.encode_utf8(&mut tmp))
    }

    pub fn as_str(&self) -> &str {
        &self.buf
    }

    pub fn function(&self) -> &'static str {
        self.function
    }

    pub(super) fn into_string(self) -> String {
        self.buf
    }
}
