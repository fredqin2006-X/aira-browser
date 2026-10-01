#!/usr/bin/env python3
"""Local origin, HTTP proxy and SOCKS5 proxy for the download-engine proxy check.

The HTTP and SOCKS listeners answer the download themselves. They do not resolve
the requested host, so an unresolvable name can only succeed when the client
actually sent the request through the proxy.
"""

import argparse
import base64
import socket
import threading
from pathlib import Path


def log(path: Path, line: str) -> None:
    with path.open('a', encoding='utf-8') as handle:
        handle.write(line + '\n')


def read_until(conn: socket.socket, marker: bytes, limit: int = 65536) -> bytes:
    data = b''
    while marker not in data and len(data) < limit:
        chunk = conn.recv(4096)
        if not chunk:
            break
        data += chunk
    return data


def recv_exact(conn: socket.socket, size: int) -> bytes:
    data = b''
    while len(data) < size:
        chunk = conn.recv(size - len(data))
        if not chunk:
            break
        data += chunk
    return data


def http_response(status: str, body: bytes, extra: bytes = b'') -> bytes:
    return (
        f'HTTP/1.1 {status}\r\n'.encode('ascii')
        + extra
        + b'Content-Length: ' + str(len(body)).encode('ascii')
        + b'\r\nConnection: close\r\n\r\n'
        + body
    )


def authorized(head: str, user: str, password: str) -> bool:
    expected = f'{user}:{password}'
    for line in head.split('\r\n'):
        if not line.lower().startswith('proxy-authorization:'):
            continue
        value = line.split(':', 1)[1].strip()
        if not value.lower().startswith('basic '):
            return False
        try:
            decoded = base64.b64decode(value.split(' ', 1)[1].strip()).decode('utf-8')
        except (ValueError, UnicodeDecodeError):
            return False
        return decoded == expected
    return False


def serve_origin(conn: socket.socket, log_path: Path) -> None:
    data = read_until(conn, b'\r\n\r\n')
    head = data.split(b'\r\n\r\n', 1)[0].decode('latin1', errors='replace')
    request = head.split('\r\n', 1)[0]
    log(log_path, 'ORIGIN ' + request)
    conn.sendall(http_response('200 OK', b'direct-ok\n'))


def serve_http_proxy(conn: socket.socket, log_path: Path, user: str, password: str) -> None:
    data = read_until(conn, b'\r\n\r\n')
    head = data.split(b'\r\n\r\n', 1)[0].decode('latin1', errors='replace')
    request = head.split('\r\n', 1)[0]
    log(log_path, 'HTTP ' + request)
    if request.upper().startswith('CONNECT '):
        if 'Proxy-Authorization:' in head and not authorized(head, user, password):
            log(log_path, 'AUTH reject ' + request)
            conn.sendall(http_response(
                '407 Proxy Authentication Required',
                b'',
                b'Proxy-Authenticate: Basic realm="aira"\r\n'
            ))
            return
        conn.sendall(b'HTTP/1.1 200 Connection Established\r\n\r\n')
        return
    if 'Proxy-Authorization:' in head and not authorized(head, user, password):
        log(log_path, 'AUTH reject ' + request)
        conn.sendall(http_response(
            '407 Proxy Authentication Required',
            b'',
            b'Proxy-Authenticate: Basic realm="aira"\r\n'
        ))
        return
    if 'Proxy-Authorization:' in head:
        log(log_path, 'AUTH accept ' + request)
    conn.sendall(http_response('200 OK', b'proxied-ok\n'))


def serve_socks(conn: socket.socket, log_path: Path) -> None:
    greeting = recv_exact(conn, 2)
    if len(greeting) < 2 or greeting[0] != 5:
        return
    methods = recv_exact(conn, greeting[1])
    if len(methods) < greeting[1]:
        return
    conn.sendall(b'\x05\x00')
    header = recv_exact(conn, 4)
    if len(header) < 4 or header[1] != 1:
        return
    address_type = header[3]
    if address_type == 1:
        raw = recv_exact(conn, 4)
        host = socket.inet_ntoa(raw) if len(raw) == 4 else ''
        kind = 'ip'
    elif address_type == 3:
        length_raw = recv_exact(conn, 1)
        if len(length_raw) != 1:
            return
        host = recv_exact(conn, length_raw[0]).decode('utf-8', errors='replace')
        kind = 'domain'
    elif address_type == 4:
        raw = recv_exact(conn, 16)
        host = socket.inet_ntop(socket.AF_INET6, raw) if len(raw) == 16 else ''
        kind = 'ip'
    else:
        return
    port_raw = recv_exact(conn, 2)
    if len(port_raw) != 2:
        return
    port = int.from_bytes(port_raw, 'big')
    log(log_path, f'SOCKS {kind} {host}:{port}')
    conn.sendall(b'\x05\x00\x00\x01\x7f\x00\x00\x01\x00\x00')
    read_until(conn, b'\r\n\r\n')
    conn.sendall(http_response('200 OK', b'socks-proxied-ok\n'))


def listen(name: str, handler, log_path: Path) -> int:
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 0))
    server.listen(32)
    port = server.getsockname()[1]

    def accept_loop() -> None:
        while True:
            try:
                conn, _ = server.accept()
            except OSError:
                return
            threading.Thread(target=handle_connection, args=(conn, handler, log_path, name), daemon=True).start()

    threading.Thread(target=accept_loop, daemon=True).start()
    return port


def handle_connection(conn: socket.socket, handler, log_path: Path, name: str) -> None:
    try:
        handler(conn)
    except Exception as error:
        log(log_path, f'{name} error {error}')
    finally:
        try:
            conn.close()
        except OSError:
            pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--port-file', required=True)
    parser.add_argument('--log-file', required=True)
    parser.add_argument('--user', required=True)
    parser.add_argument('--password', required=True)
    args = parser.parse_args()
    log_path = Path(args.log_file)
    log_path.write_text('', encoding='utf-8')
    origin = listen('ORIGIN', lambda conn: serve_origin(conn, log_path), log_path)
    http_proxy = listen(
        'HTTP',
        lambda conn: serve_http_proxy(conn, log_path, args.user, args.password),
        log_path
    )
    socks = listen('SOCKS', lambda conn: serve_socks(conn, log_path), log_path)
    Path(args.port_file).write_text(
        f'origin={origin}\nhttp_proxy={http_proxy}\nsocks={socks}\n',
        encoding='utf-8'
    )
    threading.Event().wait()


if __name__ == '__main__':
    main()
