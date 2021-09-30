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