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

	int get state {
		return type == ConnectMeType.ws ? webSocket!.readyState : WebSocket.open;
	}

	static Future<ConnectMeSocket> connect(dynamic address, {Map<String, dynamic>? headers, int port = 0}) async {
		InternetAddress? internetAddress;
		if (address is String) internetAddress = InternetAddress.tryParse(address);
		else if (address is InternetAddress) internetAddress = address;
		else throw Exception('Address must be either String or InternetAddress instance');
		if (internetAddress == null) {
			final WebSocket socket = await WebSocket.connect(address as String, headers: headers);
			return ConnectMeSocket.ws(socket);
		}
		else {
			final Socket socket = await Socket.connect(internetAddress, port);
			return ConnectMeSocket.tcp(socket);
		}
	}

	void listen(Function(dynamic) onData, {Function? onError, Function()? onDone}) {
		switch (type) {
			case ConnectMeType.ws:
				webSocket!.listen(onData, onDone: onDone, onError: onError);
				break;
			case ConnectMeType.tcp:
				tcpSocket!.listen(onData, onDone: onDone, onError: onError);
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
				tcpSocket!.add(bytes);
				break;
		}
	}

	Future<void> close() async {
		switch (type) {
			case ConnectMeType.ws:
				webSocket!.close();
				break;
			case ConnectMeType.tcp:
				tcpSocket!.close();
				break;
		}
	}
}
