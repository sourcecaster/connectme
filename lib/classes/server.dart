part of connectme;

class ConnectMeServer {
	ConnectMeServer._(this.address, this.port, this._clientFactory, this.onLog, this.onError, this.onConnect, this.onDisconnect);

	final InternetAddress address;
	final int port;
	late final HttpServer? httpServer;
	final List<ConnectMeClient> clients = <ConnectMeClient>[];
	final ConnectMeClient Function(WebSocket, HttpHeaders)? _clientFactory;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};

	final Function(String)? onLog;
	final Function(String, [StackTrace])? onError;
	final Function(ConnectMeClient)? onConnect;
	final Function(ConnectMeClient)? onDisconnect;

	Future<void> _init() async {
		if (address.type == InternetAddressType.unix) {
			onLog?.call('Starting ConnectMe server using unix named socket...');
			final File socketFile = File(address.address);
			if (socketFile.existsSync()) socketFile.deleteSync(recursive: true);
			httpServer = await HttpServer.bind(InternetAddress(address.address, type: InternetAddressType.unix), 0);
		}
		else if (address.address != null) {
			onLog?.call('Starting ConnectMe server using IP address...');
			httpServer = await HttpServer.bind(InternetAddress(address.address, type: InternetAddressType.IPv4), port);
		}
		if (httpServer != null) {
			httpServer!.listen((HttpRequest request) async {
				final WebSocket socket = await WebSocketTransformer.upgrade(request);
				final ConnectMeClient client = _clientFactory != null ? _clientFactory!(socket, request.headers) : ConnectMeClient(socket, request.headers);
				client._server = this;
				client.onLog = onLog;
				client.onError = onError;
				client.onConnect = onConnect;
				client.onDisconnect = onDisconnect;
				clients.add(client);
				onConnect?.call(client);
			});
			onLog?.call('ConnectMe server is running on: ${httpServer!.address.address}${address.type != InternetAddressType.unix ? ' port ${httpServer!.port}' : ''}');
		}
	}

	void broadcast(dynamic data, {bool Function(ConnectMeClient)? where}) {
		if (data is PackMeMessage) data = _packMe.pack(data);
		else if (data is! Uint8List && data is! String) {
			onError?.call('Unsupported data type for ConnectMe.broadcast, only PackMeMessage, Uint8List and String are supported');
			return;
		}
		for (final ConnectMeClient client in clients) {
			if (where != null && !where(client)) continue;
			if (data != null) client.socket.add(data);
		}
	}

	void listen<T>(Future<void> Function(T) handler) {
		if (_handlers[T] == null) _handlers[T] = <Function>[];
		_handlers[T]!.add(handler);
	}

	void cancel<T>(Future<void> Function(T) handler) {
		_handlers[T]?.remove(handler);
	}

	Future<void> close() async {
		for (int i = clients.length - 1; i >= 0; i--) {
			await clients[i].socket.close();
		}
		await httpServer?.close();
	}
}