//! 本体・宣言の局所番号だけを保持する表（設計書 02-05「検査の単位と手順」）。

use crate::base::{BindingId, NodeId};
use std::collections::BTreeMap;

// 番号はプログラム全体で振られる。本体ごとの空き領域を確保せず、
// 診断と出力の走査順は密な表と同じ番号の昇順にする。
macro_rules! body_map {
    ($name:ident, $id:ty) => {
        /// 全体番号を保ったまま、本体・宣言内に存在する要素だけを持つ表。
        #[derive(Clone)]
        pub(super) struct $name<T> {
            entries: BTreeMap<$id, T>,
        }

        impl<T> Default for $name<T> {
            fn default() -> Self {
                Self {
                    entries: BTreeMap::new(),
                }
            }
        }

        impl<T> $name<T> {
            /// 未登録の番号は `None` とする。
            pub(super) fn get(&self, id: $id) -> Option<&T> {
                self.entries.get(&id)
            }

            /// 同じ番号を更新した場合は前の値を返す。
            pub(super) fn insert(&mut self, id: $id, value: T) -> Option<T> {
                self.entries.insert(id, value)
            }

            /// 登録された要素を番号の昇順で辿る。
            pub(super) fn iter(&self) -> impl Iterator<Item = ($id, &T)> {
                self.entries.iter().map(|(id, value)| (*id, value))
            }
        }
    };
}

body_map!(BodyNodeMap, NodeId);
body_map!(BodyBindingMap, BindingId);
