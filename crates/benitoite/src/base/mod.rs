//! 処理系の全段が共有する基本の型: 意味の違う整数の専用型、span、ソースの表、ノード番号を鍵とする表。
//! 設計書: 02-02 ソース管理と位置情報、ADR 0015・0022・0025。

pub mod source;

pub use source::{LineCol, Source, SourceKind, SourceTable};

/// 一つの検査の中でソースを区別する番号（02-02「ソースとファイル ID」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct FileId(pub u32);

/// ファイルの内容の先頭からのバイトの位置（02-02「span」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BytePos(pub u32);

/// AST のノード番号。一つの検査の中で重ならない（ADR 0022）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct NodeId(pub u32);

/// 名前解決の束縛の番号。一つの検査の中で重ならない（02-04「束縛」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BindingId(pub u32);

/// ソース上の位置。開始を含み終了を含まない。長さ 0 も許す（02-02「span」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct Span {
    pub file: FileId,
    pub start: BytePos,
    pub end: BytePos,
}

impl Span {
    /// `start` から `end` までを覆う span。二つは同じファイルでなければならない。
    pub fn to(self, end: Span) -> Span {
        Span {
            file: self.file,
            start: self.start,
            end: end.end,
        }
    }
}

/// ノード番号と束縛の番号を振る数え上げの状態。検査ごとに一つ作る（02-03「AST」、ADR 0015）。
/// ソースの大きさの上限（`source::MAX_SOURCE_BYTES`）により、番号は u32 に収まる。
#[derive(Debug, Default)]
pub struct IdGen {
    next_node: u32,
    next_binding: u32,
}

impl IdGen {
    pub fn new() -> IdGen {
        IdGen::default()
    }

    pub fn node(&mut self) -> NodeId {
        let id = NodeId(self.next_node);
        self.next_node = self.next_node.saturating_add(1);
        id
    }

    pub fn binding(&mut self) -> BindingId {
        let id = BindingId(self.next_binding);
        self.next_binding = self.next_binding.saturating_add(1);
        id
    }

    /// これまでに振ったノード番号の数。`NodeMap::with_len` に使う。
    pub fn node_count(&self) -> u32 {
        self.next_node
    }

    pub fn binding_count(&self) -> u32 {
        self.next_binding
    }
}

/// ノード番号を鍵とする表（ADR 0022）。番号は密なので `Vec` で持つ。
#[derive(Clone, Debug)]
pub struct NodeMap<T> {
    slots: Vec<Option<T>>,
}

impl<T> Default for NodeMap<T> {
    fn default() -> Self {
        NodeMap { slots: Vec::new() }
    }
}

impl<T> NodeMap<T> {
    pub fn new() -> NodeMap<T> {
        NodeMap::default()
    }

    pub fn get(&self, id: NodeId) -> Option<&T> {
        let index = usize::try_from(id.0).ok()?;
        self.slots.get(index).and_then(Option::as_ref)
    }

    /// 値を入れる。前の値があれば返す。
    pub fn insert(&mut self, id: NodeId, value: T) -> Option<T> {
        let Ok(index) = usize::try_from(id.0) else {
            return None;
        };
        if self.slots.len() <= index {
            self.slots.resize_with(index.saturating_add(1), || None);
        }
        match self.slots.get_mut(index) {
            Some(slot) => slot.replace(value),
            None => None,
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = (NodeId, &T)> {
        self.slots.iter().enumerate().filter_map(|(i, v)| {
            let id = NodeId(u32::try_from(i).ok()?);
            v.as_ref().map(|v| (id, v))
        })
    }
}

/// 束縛の番号を鍵とする表。作りは `NodeMap` と同じ。
#[derive(Clone, Debug)]
pub struct BindingMap<T> {
    slots: Vec<Option<T>>,
}

impl<T> Default for BindingMap<T> {
    fn default() -> Self {
        BindingMap { slots: Vec::new() }
    }
}

impl<T> BindingMap<T> {
    pub fn new() -> BindingMap<T> {
        BindingMap::default()
    }

    pub fn get(&self, id: BindingId) -> Option<&T> {
        let index = usize::try_from(id.0).ok()?;
        self.slots.get(index).and_then(Option::as_ref)
    }

    pub fn insert(&mut self, id: BindingId, value: T) -> Option<T> {
        let Ok(index) = usize::try_from(id.0) else {
            return None;
        };
        if self.slots.len() <= index {
            self.slots.resize_with(index.saturating_add(1), || None);
        }
        match self.slots.get_mut(index) {
            Some(slot) => slot.replace(value),
            None => None,
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = (BindingId, &T)> {
        self.slots.iter().enumerate().filter_map(|(i, v)| {
            let id = BindingId(u32::try_from(i).ok()?);
            v.as_ref().map(|v| (id, v))
        })
    }
}
