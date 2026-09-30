# prelude のソース

本章は、prelude のソース（言語で書いた prelude の定義）の全文を与える。[標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md)の「prelude のソースの書き方」が「prelude のソースの関数の定義そのものは、実装プランで与える」とした部分である。作業 T01 が、このままファイルに置く。

## 書き方の方針

- 03-06 の表で実装の欄を「ソース」とした関数（`List` の関数を引数にとる 7 関数、`Option` の 6 関数、`Result` の 7 関数）を、モジュールの名前で修飾した関数として書く。
- リストを辿る関数は、累積の引数を持つ末尾再帰で書き、長さに比例する深さの末尾でない再帰を使わない（03-06「関数を引数にとる関数の共通の規則」）。`List.map` と `List.filter` は、逆順に累積してから `List.reverse` で戻す。`List.fold`・`List.forEach`・`List.any`・`List.all`・`List.find` は、それ自身が末尾再帰になる。
- 残りのリストは、prelude のソースの中だけで使える `List.dropFirst` で取り出す（[組み込みの関数](10-10-builtins.md)）。
- `List.any` と `List.all` は、`||` と `&&` の右辺に再帰の呼び出しを置く。右辺は末尾位置にあり（01-08「末尾呼び出し」）、結果が決まった時点で残りの要素について関数を呼ばない。
- 受け取った関数は、要素を先頭から順に一つずつ渡して呼ぶ。

ファイルは名前の順（`list.bnt`・`option.bnt`・`result.bnt`）に読み込む（02-04「prelude」）。

```text file=src/prelude/list.bnt
// prelude: List の関数のうち、関数を引数にとるもの（設計書 03-06「List」）

fn List.map[T, U, effect E](xs: List[T], f: fn(T) -> U uses E) -> List[U] uses E {
  List.reverse(mapInto(xs, f, []))
}

fn mapInto[T, U, effect E](xs: List[T], f: fn(T) -> U uses E, acc: List[U]) -> List[U] uses E {
  match List.head(xs) {
    None => acc
    Some(x) => {
      let y = f(x)
      mapInto(List.dropFirst(xs), f, List.prepend(acc, y))
    }
  }
}

fn List.filter[T, effect E](xs: List[T], p: fn(T) -> Bool uses E) -> List[T] uses E {
  List.reverse(filterInto(xs, p, []))
}

fn filterInto[T, effect E](xs: List[T], p: fn(T) -> Bool uses E, acc: List[T]) -> List[T] uses E {
  match List.head(xs) {
    None => acc
    Some(x) => {
      let rest = List.dropFirst(xs)
      if p(x) {
        filterInto(rest, p, List.prepend(acc, x))
      } else {
        filterInto(rest, p, acc)
      }
    }
  }
}

fn List.fold[T, A, effect E](xs: List[T], init: A, f: fn(A, T) -> A uses E) -> A uses E {
  match List.head(xs) {
    None => init
    Some(x) => List.fold(List.dropFirst(xs), f(init, x), f)
  }
}

fn List.forEach[T, effect E](xs: List[T], f: fn(T) -> Unit uses E) -> Unit uses E {
  match List.head(xs) {
    None => ()
    Some(x) => {
      f(x)
      List.forEach(List.dropFirst(xs), f)
    }
  }
}

fn List.any[T, effect E](xs: List[T], p: fn(T) -> Bool uses E) -> Bool uses E {
  match List.head(xs) {
    None => false
    Some(x) => p(x) || List.any(List.dropFirst(xs), p)
  }
}

fn List.all[T, effect E](xs: List[T], p: fn(T) -> Bool uses E) -> Bool uses E {
  match List.head(xs) {
    None => true
    Some(x) => p(x) && List.all(List.dropFirst(xs), p)
  }
}

fn List.find[T, effect E](xs: List[T], p: fn(T) -> Bool uses E) -> Option[T] uses E {
  match List.head(xs) {
    None => None
    Some(x) => if p(x) { Some(x) } else { List.find(List.dropFirst(xs), p) }
  }
}
```

```text file=src/prelude/option.bnt
// prelude: Option の関数（設計書 03-06「Option」）

fn Option.map[T, U, effect E](o: Option[T], f: fn(T) -> U uses E) -> Option[U] uses E {
  match o {
    Some(x) => Some(f(x))
    None => None
  }
}

fn Option.andThen[T, U, effect E](o: Option[T], f: fn(T) -> Option[U] uses E) -> Option[U] uses E {
  match o {
    Some(x) => f(x)
    None => None
  }
}

fn Option.unwrapOr[T](o: Option[T], d: T) -> T {
  match o {
    Some(x) => x
    None => d
  }
}

fn Option.isSome[T](o: Option[T]) -> Bool {
  match o {
    Some(_) => true
    None => false
  }
}

fn Option.isNone[T](o: Option[T]) -> Bool {
  match o {
    Some(_) => false
    None => true
  }
}

fn Option.okOr[T, X](o: Option[T], e: X) -> Result[T, X] {
  match o {
    Some(x) => Ok(x)
    None => Err(e)
  }
}
```

```text file=src/prelude/result.bnt
// prelude: Result の関数（設計書 03-06「Result」）

fn Result.map[T, U, X, effect E](r: Result[T, X], f: fn(T) -> U uses E) -> Result[U, X] uses E {
  match r {
    Ok(x) => Ok(f(x))
    Err(e) => Err(e)
  }
}

fn Result.mapErr[T, X, Y, effect E](r: Result[T, X], f: fn(X) -> Y uses E) -> Result[T, Y] uses E {
  match r {
    Ok(x) => Ok(x)
    Err(e) => Err(f(e))
  }
}

fn Result.andThen[T, U, X, effect E](r: Result[T, X], f: fn(T) -> Result[U, X] uses E) -> Result[U, X] uses E {
  match r {
    Ok(x) => f(x)
    Err(e) => Err(e)
  }
}

fn Result.unwrapOr[T, X](r: Result[T, X], d: T) -> T {
  match r {
    Ok(x) => x
    Err(_) => d
  }
}

fn Result.isOk[T, X](r: Result[T, X]) -> Bool {
  match r {
    Ok(_) => true
    Err(_) => false
  }
}

fn Result.isErr[T, X](r: Result[T, X]) -> Bool {
  match r {
    Ok(_) => false
    Err(_) => true
  }
}

fn Result.ok[T, X](r: Result[T, X]) -> Option[T] {
  match r {
    Ok(x) => Some(x)
    Err(_) => None
  }
}
```

## 埋め込み

```rust file=src/prelude/mod.rs
//! prelude のソース（設計書 02-04「prelude」）。`include_str!` で処理系に埋め込む。

/// prelude のソースのファイルの名前と内容。ファイルの名前の順に並べる。
/// 読み込みの段は、表示名を `<prelude>/` にファイルの名前を続けたものとしてソースの表に加える。
pub const SOURCES: [(&str, &str); 3] = [
    ("list.bnt", include_str!("list.bnt")),
    ("option.bnt", include_str!("option.bnt")),
    ("result.bnt", include_str!("result.bnt")),
];

/// 表示名の接頭辞。
pub const DISPLAY_PREFIX: &str = "<prelude>/";
```

prelude のソースに誤りがあれば、それは処理系の不具合である。作業 T13 と T15 は、prelude のソースだけを検査して誤りがないことを確かめるテストを置く（02-04「prelude」の最後の段落）。
