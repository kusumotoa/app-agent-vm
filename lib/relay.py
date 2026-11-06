"""接続を標準入出力の枠に載せて、VM とホストの間で運ぶ。
VM の中ではこのファイルを丸ごと python3 -c で動かす。

枠は 種類(1) 接続番号(4) 長さ(4) 本体。O は接続を開く（本体は宛先の名前）、D はデータ、C は書き終えた。
"""
import socket
import struct
import sys
import threading

HEAD = struct.Struct(">cII")
PORT = 443


def parse_sni(data):
    """TLS の ClientHello から server_name を取り出す。取れなければ None。"""
    try:
        if len(data) < 6 or data[0] != 0x16 or data[5] != 0x01:
            return None
        pos = 5 + 4 + 2 + 32
        pos += 1 + data[pos]
        pos += 2 + int.from_bytes(data[pos:pos + 2], "big")
        pos += 1 + data[pos]
        end = pos + 2 + int.from_bytes(data[pos:pos + 2], "big")
        pos += 2
        while pos + 4 <= end:
            kind = int.from_bytes(data[pos:pos + 2], "big")
            size = int.from_bytes(data[pos + 2:pos + 4], "big")
            pos += 4
            if kind == 0:
                length = int.from_bytes(data[pos + 3:pos + 5], "big")
                return data[pos + 5:pos + 5 + length].decode("ascii").lower() or None
            pos += size
    except (IndexError, UnicodeDecodeError):
        return None
    return None


def read_hello(sock):
    """ClientHello のレコードが揃うまで読む。"""
    sock.settimeout(10)
    data = b""
    while len(data) < 5:
        chunk = sock.recv(4096)
        if not chunk:
            return data
        data += chunk
    want = 5 + int.from_bytes(data[3:5], "big")
    while len(data) < want:
        chunk = sock.recv(4096)
        if not chunk:
            break
        data += chunk
    sock.settimeout(None)
    return data


class Peer:
    """枠を送り受けする側。VM とホストで同じ。"""

    def __init__(self, inp, out):
        self.inp, self.out = inp, out
        self.wlock, self.lock = threading.Lock(), threading.Lock()
        self.socks, self.ends = {}, {}

    def send(self, kind, number, body=b""):
        with self.wlock:
            try:
                self.out.write(HEAD.pack(kind, number, len(body)) + body)
                self.out.flush()
            except (OSError, ValueError):
                pass

    def read(self, size):
        data = b""
        while len(data) < size:
            chunk = self.inp.read(size - len(data))
            if not chunk:
                raise EOFError
            data += chunk
        return data

    def frames(self):
        try:
            while True:
                kind, number, size = HEAD.unpack(self.read(HEAD.size))
                yield kind, number, self.read(size) if size else b""
        except EOFError:
            return

    def finish(self, number):
        """送る側と受ける側の両方が終わったら閉じる。"""
        with self.lock:
            self.ends[number] = self.ends.get(number, 0) + 1
            if self.ends[number] < 2:
                return
            del self.ends[number]
            sock = self.socks.pop(number, None)
        if sock:
            sock.close()

    def pump(self, number, sock):
        """ソケットから読んだものを枠にして送る。"""
        try:
            while True:
                data = sock.recv(65536)
                if not data:
                    break
                self.send(b"D", number, data)
        except OSError:
            pass
        self.send(b"C", number)
        self.finish(number)

    def deliver(self, kind, number, sock, body):
        """届いた枠をソケットへ書く。"""
        try:
            if kind == b"D":
                sock.sendall(body)
            else:
                sock.shutdown(socket.SHUT_WR)
        except OSError:
            pass
        if kind == b"C":
            self.finish(number)


class Entry(Peer):
    """VM の 127.0.0.1:443。来た接続の宛先を SNI から読んで、ホストへ渡す。"""

    count = 0

    def handle(self, sock):
        try:
            hello = read_hello(sock)
        except OSError:
            hello = b""
        name = parse_sni(hello)
        if not name:
            sock.close()
            return
        with self.lock:
            self.count += 1
            number = self.count
            self.socks[number] = sock
        self.send(b"O", number, name.encode())
        self.send(b"D", number, hello)
        self.pump(number, sock)

    def accept(self, server):
        while True:
            sock, _ = server.accept()
            threading.Thread(target=self.handle, args=(sock,), daemon=True).start()

    def serve(self):
        server = socket.socket()
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", PORT))
        server.listen(128)
        threading.Thread(target=self.accept, args=(server,), daemon=True).start()
        for kind, number, body in self.frames():
            sock = self.socks.get(number)
            if sock:
                self.deliver(kind, number, sock, body)


if __name__ == "__main__":
    Entry(sys.stdin.buffer, sys.stdout.buffer).serve()
