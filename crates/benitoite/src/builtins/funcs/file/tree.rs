//! 記述子を基準にした木の走査（設計書 03-07「File」）。

use rustix::fd::{BorrowedFd, OwnedFd};
use rustix::fs::{self, AtFlags, Dir, FileType, Mode, OFlags, Stat};
use std::ffi::{OsStr, OsString};
use std::io;
use std::os::unix::ffi::OsStrExt;
use std::path::Path;

// 根は再びパスから開かず、直近の祖先だけを保持する。読み出し用の Dir と、
// 開き直す途中の記述子（最大二つ）、removeTree の根の親を含めても最大 36 個
// である。深さに応じて OS の記述子の上限に近付かない。
pub(super) const MAX_HELD_DIRECTORY_FDS: usize = 32;
const DIRECTORY_FLAGS: OFlags = OFlags::RDONLY
    .union(OFlags::DIRECTORY)
    .union(OFlags::NOFOLLOW)
    .union(OFlags::CLOEXEC);

// 親は名前の解決と unlinkat にだけ使う。読み取り権限まで要求すると、検索・
// 書き込みだけを許す親の下で従来の removeTree が成功する場合を拒否してしまう。
#[cfg(target_os = "linux")]
const PARENT_ACCESS: OFlags = OFlags::PATH;
// macOS SDK の sys/fcntl.h は O_SEARCH = O_EXEC | O_DIRECTORY、
// O_EXEC = 0x40000000 と定める。rustix 1.1.5 にはその名前の定数がない。
#[cfg(target_os = "macos")]
const PARENT_ACCESS: OFlags = OFlags::from_bits_retain(0x4000_0000);
#[cfg(not(any(target_os = "linux", target_os = "macos")))]
const PARENT_ACCESS: OFlags = OFlags::RDONLY;

struct Frame {
    name: OsString,
    identity: Stat,
    fd: Option<OwnedFd>,
    entries: Vec<OsString>,
}

pub(super) struct DirectoryStack {
    frames: Vec<Frame>,
}

fn same_directory(left: &Stat, right: &Stat) -> bool {
    left.st_dev == right.st_dev && left.st_ino == right.st_ino
}

fn changed_directory() -> io::Error {
    io::Error::other(super::text::DIRECTORY_CHANGED)
}

fn entries(fd: &OwnedFd) -> io::Result<Vec<OsString>> {
    let mut names = Vec::new();
    // Dir を読み切って閉じるので、ストリームの記述子は深さごとに保持しない。
    for entry in Dir::read_from(fd)? {
        let entry = entry?;
        let name = entry.file_name().to_bytes();
        if name != b"." && name != b".." {
            names.push(OsStr::from_bytes(name).to_owned());
        }
    }
    Ok(names)
}

fn open_checked(parent: BorrowedFd<'_>, name: &OsStr, identity: &Stat) -> io::Result<OwnedFd> {
    let fd = fs::openat(parent, name, DIRECTORY_FLAGS, Mode::empty())?;
    if !same_directory(&fs::fstat(&fd)?, identity) {
        return Err(changed_directory());
    }
    Ok(fd)
}

impl DirectoryStack {
    pub(super) fn new(fd: OwnedFd) -> io::Result<Self> {
        let identity = fs::fstat(&fd)?;
        let entries = entries(&fd)?;
        Ok(Self {
            frames: vec![Frame {
                name: OsString::new(),
                identity,
                fd: Some(fd),
                entries,
            }],
        })
    }

    pub(super) fn next_name(&mut self) -> Option<OsString> {
        self.frames.last_mut()?.entries.pop()
    }

    pub(super) fn fd(&mut self) -> io::Result<BorrowedFd<'_>> {
        use rustix::fd::AsFd;
        let last = self.frames.last().ok_or_else(changed_directory)?;
        if last.fd.is_none() {
            let anchor = self
                .frames
                .iter()
                .rposition(|frame| frame.fd.is_some())
                .ok_or_else(changed_directory)?;
            let mut frames = self.frames.iter().skip(anchor);
            let parent = frames
                .next()
                .and_then(|frame| frame.fd.as_ref())
                .ok_or_else(changed_directory)?;
            let mut reopened: Option<OwnedFd> = None;
            // 複数の名前を一度に openat に渡すと途中のリンクを辿る。各構成要素を
            // NOFOLLOW で開き、記録した (dev, ino) と比較してから次へ進む。
            for frame in frames {
                let fd = reopened.as_ref().unwrap_or(parent).as_fd();
                reopened = Some(open_checked(fd, &frame.name, &frame.identity)?);
            }
            self.frames.last_mut().ok_or_else(changed_directory)?.fd = reopened;
        }
        self.frames
            .last()
            .and_then(|frame| frame.fd.as_ref())
            .map(AsFd::as_fd)
            .ok_or_else(changed_directory)
    }

    pub(super) fn push(&mut self, name: OsString, identity: Stat) -> io::Result<()> {
        let fd = open_checked(self.fd()?, &name, &identity)?;
        if self
            .frames
            .iter()
            .filter(|frame| frame.fd.is_some())
            .count()
            >= MAX_HELD_DIRECTORY_FDS
        {
            // 根を残し、最も古い祖先を閉じる。現在の親は直近なので保持される。
            if let Some(frame) = self
                .frames
                .iter_mut()
                .skip(1)
                .find(|frame| frame.fd.is_some())
            {
                frame.fd = None;
            }
        }
        let entries = entries(&fd)?;
        self.frames.push(Frame {
            name,
            identity,
            fd: Some(fd),
            entries,
        });
        Ok(())
    }

    // 根の削除は呼び出し側が固定した親の記述子を使う。
    pub(super) fn pop(&mut self, remove: bool) -> io::Result<bool> {
        let frame = self.frames.pop().ok_or_else(changed_directory)?;
        if self.frames.is_empty() {
            return Ok(false);
        }
        let parent = self.fd()?;
        if remove {
            unlink_directory(parent, &frame.name, &frame.identity)?;
        }
        Ok(true)
    }
}

pub(super) fn is_directory(stat: &Stat) -> bool {
    FileType::from_raw_mode(stat.st_mode) == FileType::Directory
}

pub(super) fn unlink_directory(
    parent: BorrowedFd<'_>,
    name: &OsStr,
    identity: &Stat,
) -> io::Result<()> {
    let current = fs::statat(parent, name, AtFlags::SYMLINK_NOFOLLOW)?;
    if !same_directory(&current, identity) || !is_directory(&current) {
        return Err(changed_directory());
    }
    // 検査の後にリンクへ変わっても、unlinkat はリンク先を辿らない。
    fs::unlinkat(parent, name, AtFlags::REMOVEDIR)?;
    Ok(())
}

pub(super) fn open_remove_root(path: &Path) -> io::Result<(OwnedFd, OsString, Stat, OwnedFd)> {
    // Path::file_name は末尾の .. を除くため、OS に渡す最後の構成要素を
    // バイト列から取り出す。途中の .・.. とリンクの解決順を保つ。
    let mut components = path.as_os_str().as_bytes().rsplitn(2, |byte| *byte == b'/');
    let name = components.next().unwrap_or_default();
    let parent = match components.next() {
        Some(b"") => Path::new("/"),
        Some(parent) => Path::new(OsStr::from_bytes(parent)),
        None => Path::new("."),
    };
    let name = if name.is_empty() {
        path.as_os_str()
    } else {
        OsStr::from_bytes(name)
    };
    let parent = fs::open(
        parent,
        PARENT_ACCESS | OFlags::DIRECTORY | OFlags::CLOEXEC,
        Mode::empty(),
    )?;
    let identity = fs::statat(&parent, name, AtFlags::SYMLINK_NOFOLLOW)?;
    if !is_directory(&identity) {
        return Err(io::Error::new(
            io::ErrorKind::NotADirectory,
            super::text::NOT_DIRECTORY,
        ));
    }
    use rustix::fd::AsFd;
    let root = open_checked(parent.as_fd(), name, &identity)?;
    Ok((parent, name.to_owned(), identity, root))
}
