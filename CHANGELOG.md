## v2.2.2
* HTTP routes handling updated.

## v2.2.0
* HTTP type server added. Method server.on(route, handler) implemented for HTTP routes.

## v2.1.2
* PackMe upgraded to v2.0.1: bugfix.

## v2.1.1
* PackMe upgraded to v2.0.0: object inheritance implemented, nested arrays support.
* IMPORTANT: PackMe objects and enumerations from other JSON files are now referenced using filename: "some_user": "@filename:user". No changes required for references within the same file.

## v2.1.0
* Added support for binary type (uses Uint8List). Format: binary12, binary64 etc. - any buffer length in bytes.

## v2.0.2
* Maximum data length increased to 2^63 for messages sent over TCP socket.
* Bugfix: data messages sent over TCP socket could stall in some cases.

## v2.0.1
* TCP data message boundaries implemented.

## v2.0.0
* ConnectMeClient constructor now takes single ConnectMeSocket argument.
* TCP sockets server/connection support added (breaking changes).
* Bugfix: unix named sockets failed to receive connections due to bad socket file permissions.
* Bugfix: client connection failed reconnect attempt (with autoReconnect: true) caused an unhandled exception.
* Bugfix: socket connections were not properly closed in some cases which could potentially lead to memory leaks.

## v1.1.1
* Safari WebSocket data parsing bug fixed (it adds some extra bytes to buffer and actual Uint8List data size is smaller that its underlying buffer).

## v1.1.0
* Some client properties scope changed to private.

## v1.0.0
* Example extended.
* Readme added.
* Tests implemented.
* Repository structure updated.
* Client and server listen() method no longer requires async handler.