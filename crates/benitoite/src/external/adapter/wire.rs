//! 補助コードとホストの転送形式の版・ヘッダ・詰め物を定める（設計書 03-10「型の対応」）。
//! 固定部と参照先の位置は、ヘッダを含むバイト列の先頭から数える。

/// 版を識別する固定の四バイト。
pub(crate) const MAGIC: &[u8; 4] = b"BNTW";
/// 相対位置と長さが u32 の転送形式。
pub(crate) const VERSION: u32 = 1;
/// 根の固定部が始まる位置。最大の整列である八バイトの倍数である。
pub(crate) const HEADER_SIZE: u32 = 32;
/// ヘッダの欄の位置と幅。数はすべてリトルエンディアンである。
pub(crate) const MAGIC_OFFSET: u32 = 0;
pub(crate) const VERSION_OFFSET: u32 = 4;
pub(crate) const LENGTH_OFFSET: u32 = 8;
pub(crate) const ROOTS_OFFSET: u32 = 12;
pub(crate) const TRANSFER_OFFSET: u32 = 16;
pub(crate) const CONSTRUCTION_OFFSET: u32 = 24;
pub(crate) const U32_SIZE: u32 = 4;
pub(crate) const U64_SIZE: u32 = 8;
/// string・list・map の相対位置と長さの欄の間隔。
pub(crate) const REFERENCE_LENGTH_OFFSET: u32 = U32_SIZE;
/// 言語の値の一出現の論理上の構築量。ヒープの確保量とは区別する。
pub(crate) const VALUE_BYTES: u64 = 16;

/// 転送の資源上限と、内部の形式の不整合を区別する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum WireError {
    TransferLimit,
    ConstructionLimit,
    Memory32,
    Internal(&'static str),
}

/// 根全体の長さ・個数と、ホストが指定した二つの予算。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Header {
    pub length: u32,
    pub roots: u32,
    pub limit: u64,
}

impl Header {
    /// 零で初期化した出力へヘッダを書く。
    pub(crate) fn write(self, bytes: &mut [u8]) -> Result<(), WireError> {
        put(bytes, MAGIC_OFFSET, MAGIC)?;
        put(bytes, VERSION_OFFSET, &VERSION.to_le_bytes())?;
        put(bytes, LENGTH_OFFSET, &self.length.to_le_bytes())?;
        put(bytes, ROOTS_OFFSET, &self.roots.to_le_bytes())?;
        put(bytes, TRANSFER_OFFSET, &self.limit.to_le_bytes())?;
        put(bytes, CONSTRUCTION_OFFSET, &self.limit.to_le_bytes())
    }

    /// 版・長さ・根の数・両予算を信用せず、ホストの指定値と照合する。
    pub(crate) fn read(bytes: &[u8], roots: u32, limit: u64) -> Result<Self, WireError> {
        let word = |offset| -> Result<u32, WireError> {
            Ok(u32::from_le_bytes(
                range(bytes, offset, U32_SIZE)?
                    .try_into()
                    .map_err(|_| mismatch())?,
            ))
        };
        let budget = |offset| -> Result<u64, WireError> {
            Ok(u64::from_le_bytes(
                range(bytes, offset, U64_SIZE)?
                    .try_into()
                    .map_err(|_| mismatch())?,
            ))
        };
        let length = word(LENGTH_OFFSET)?;
        if range(bytes, MAGIC_OFFSET, U32_SIZE)? != MAGIC
            || word(VERSION_OFFSET)? != VERSION
            || word(ROOTS_OFFSET)? != roots
            || usize::try_from(length).map_err(|_| mismatch())? != bytes.len()
            || length < HEADER_SIZE
            || budget(TRANSFER_OFFSET)? != limit
            || budget(CONSTRUCTION_OFFSET)? != limit
        {
            return Err(mismatch());
        }
        if u64::from(length) > limit {
            return Err(WireError::TransferLimit);
        }
        Ok(Self {
            length,
            roots,
            limit,
        })
    }
}

/// 詰め物と非選択領域は、幅によらずすべて零でなければならない。
pub(crate) fn require_zero(bytes: &[u8]) -> Result<(), WireError> {
    if bytes.iter().any(|&byte| byte != 0) {
        Err(mismatch())
    } else {
        Ok(())
    }
}

/// 相対位置の範囲と加算を検査してから読む。
pub(crate) fn range(bytes: &[u8], offset: u32, length: u32) -> Result<&[u8], WireError> {
    let end = offset.checked_add(length).ok_or(WireError::Memory32)?;
    bytes
        .get(
            usize::try_from(offset).map_err(|_| mismatch())?
                ..usize::try_from(end).map_err(|_| mismatch())?,
        )
        .ok_or_else(mismatch)
}

/// 相対位置の範囲と加算を検査してから書く。
pub(crate) fn put(bytes: &mut [u8], offset: u32, value: &[u8]) -> Result<(), WireError> {
    let length = u32::try_from(value.len()).map_err(|_| WireError::Memory32)?;
    let end = offset.checked_add(length).ok_or(WireError::Memory32)?;
    bytes
        .get_mut(
            usize::try_from(offset).map_err(|_| mismatch())?
                ..usize::try_from(end).map_err(|_| mismatch())?,
        )
        .ok_or_else(mismatch)?
        .copy_from_slice(value);
    Ok(())
}

fn mismatch() -> WireError {
    WireError::Internal("adapter wire format mismatch")
}

/// 幅の決まった欄を範囲の検査付きで読む。
pub(crate) fn word<const N: usize>(bytes: &[u8], offset: u32) -> Result<[u8; N], WireError> {
    range(bytes, offset, u32::try_from(N).map_err(|_| mismatch())?)?
        .try_into()
        .map_err(|_| mismatch())
}

/// 判別子と flags は配置表が指定した幅で読む。
pub(crate) fn discriminant(bytes: &[u8], offset: u32, size: u32) -> Result<u32, WireError> {
    match size {
        1 => Ok(u32::from(u8::from_le_bytes(word(bytes, offset)?))),
        2 => Ok(u32::from(u16::from_le_bytes(word(bytes, offset)?))),
        4 => Ok(u32::from_le_bytes(word(bytes, offset)?)),
        _ => Err(mismatch()),
    }
}
