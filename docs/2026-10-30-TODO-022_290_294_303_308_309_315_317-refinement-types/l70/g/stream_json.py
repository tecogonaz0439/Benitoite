#!/usr/bin/env python3
"""圧縮JSONの根の配列を、一要素ずつ読む（標準ライブラリだけを使う）。"""
import json


class Reader:
    def __init__(self, file):
        self.file = file
        self.buffer = ""
        self.position = 0
        self.eof = False
        self.decoder = json.JSONDecoder()

    def fill(self):
        if self.eof:
            return False
        self.buffer = self.buffer[self.position:]
        self.position = 0
        block = self.file.read(1024 * 1024)
        self.buffer += block
        self.eof = not block
        return bool(block)

    def peek(self):
        while True:
            while self.position < len(self.buffer) and self.buffer[self.position].isspace():
                self.position += 1
            if self.position < len(self.buffer):
                return self.buffer[self.position]
            if not self.fill():
                return ""

    def take(self, token):
        actual = self.peek()
        assert actual == token, (token, actual)
        self.position += 1

    def value(self):
        assert self.peek(), "unexpected end of JSON"
        while True:
            try:
                value, end = self.decoder.raw_decode(self.buffer, self.position)
                # 数の途中でchunkが終わった場合も、次の区切りまで読み足す。
                if end == len(self.buffer) and not self.eof:
                    if self.fill():
                        continue
                    value, end = self.decoder.raw_decode(self.buffer, self.position)
                self.position = end
                return value
            except json.JSONDecodeError:
                if not self.fill():
                    raise


def events(path):
    """(kind, key, index, value)を返す。根がobjectでない形式は使わない。"""
    with path.open(encoding="utf-8") as source:
        reader = Reader(source)
        if reader.peek() == "[":
            reader.take("[")
            yield "array", "", 0, None
            index = 0
            while reader.peek() != "]":
                if index:
                    reader.take(",")
                yield "item", "", index, reader.value()
                index += 1
            reader.take("]")
            yield "end", "", index, None
            assert reader.peek() == ""
            return
        if reader.peek() != "{":
            yield "field", "", 0, reader.value()
            assert reader.peek() == ""
            return
        reader.take("{")
        first = True
        while reader.peek() != "}":
            if not first:
                reader.take(",")
            first = False
            key = reader.value()
            assert isinstance(key, str)
            reader.take(":")
            if reader.peek() == "[":
                reader.take("[")
                yield "array", key, 0, None
                index = 0
                while reader.peek() != "]":
                    if index:
                        reader.take(",")
                    yield "item", key, index, reader.value()
                    index += 1
                reader.take("]")
                yield "end", key, index, None
            else:
                yield "field", key, 0, reader.value()
        reader.take("}")
        assert reader.peek() == "", "trailing JSON content"
