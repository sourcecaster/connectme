part of connectme;

const Utf8Codec _utf8 = Utf8Codec();

class ConnectMeSocket {
	ConnectMeSocket.ws(this.webSocket, [this.httpRequest]) : type = ConnectMeType.ws, tcpSocket = null;
	ConnectMeSocket.tcp(this.tcpSocket) : type = ConnectMeType.tcp, webSocket = null, httpRequest = null;

	final ConnectMeType type;
	final WebSocket? webSocket;
	final HttpRequest? httpRequest;
	final Socket? tcpSocket;
	ConnectMeServer<ConnectMeClient>? _server;
	int _packetLength = 0;
	final BytesBuilder _packetBuffer = BytesBuilder();

	int get state {
		return type == ConnectMeType.ws ? webSocket!.readyState : WebSocket.open;
	}

	void listen(Function(dynamic) onData, {Function? onError, Function()? onDone}) {
		switch (type) {
			case ConnectMeType.ws:
				webSocket!.listen(onData, onDone: onDone, onError: onError);
				break;
			case ConnectMeType.tcp:
				tcpSocket!.listen(onData, onDone: onDone, onError: onError);
				break;
			case ConnectMeType.http:
				break;
		}
	}

	void add(dynamic data) {
		switch (type) {
			case ConnectMeType.ws:
				webSocket!.add(data);
				break;
			case ConnectMeType.tcp:
				final Uint8List bytes = data is String ? _utf8.encoder.convert(data) : data as Uint8List;
				tcpSocket!.add(Uint8List(8)..buffer.asByteData().setUint64(0, 8 + bytes.length, Endian.big));
				tcpSocket!.add(bytes);
				break;
			case ConnectMeType.http:
				break;
		}
	}

	Future<void> close() async {
		switch (type) {
			case ConnectMeType.ws:
				await webSocket!.close();
				break;
			case ConnectMeType.tcp:
				await tcpSocket!.close();
				tcpSocket!.destroy();
				break;
			case ConnectMeType.http:
				break;
		}
	}

	List<Uint8List> _extractPackets(Uint8List data) {
		_packetBuffer.add(data);
		if (_packetBuffer.length >= _packetLength) {
			final List<Uint8List> result = <Uint8List>[];
			final Uint8List buffer = _packetBuffer.takeBytes();
			int offset = 0;
			do {
				_packetLength = buffer.buffer.asByteData().getUint64(offset, Endian.big);
				if (buffer.length < offset + _packetLength) break;
				final Uint8List data = buffer.sublist(offset + 8, offset + _packetLength);
				offset += _packetLength;
				result.add(data);
				_packetLength = 0;
			} while (buffer.length >= offset + 8);
			_packetBuffer.add(buffer.sublist(offset));
			return result;
		}
		return <Uint8List>[];
	}
}
