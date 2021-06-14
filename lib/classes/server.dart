part of connectme;

class Client {
	Client(this.socket, this.headers) {
		socket.listen((dynamic data) {
			if (data is Uint8List) {
				final PackMeMessage? message = _server._packMe.unpack(data);
				if (message != null) data = message;
			}
			if (_server._handlers[data.runtimeType] != null) {
				for (final Function handler in _server._handlers[data.runtimeType]!) _processHandler(handler, data, this);
			}
			if (_handlers[data.runtimeType] != null) {
				for (final Function handler in _handlers[data.runtimeType]!) _processHandler(handler, data, this);
			}
		}, onDone: () {
			_server.onDisconnect?.call(this);
			_server.clients.remove(this);
		}, onError: (dynamic err, StackTrace stack) {
			_server.onError?.call('ConnectMe socket error occurred: $err', stack);
		});
	}

	late final ConnectMeServer _server;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};
	final WebSocket socket;
	final HttpHeaders headers;

	Future<void> _processHandler(Function handler, dynamic data, Client client) async {
		try {
			await handler(data, client);
		}
		catch (err, stack) {
			_server.onError?.call('ConnectMe message handler execution error: $err', stack);
		}
	}

	void send(dynamic data) {
		if (data is PackMeMessage) data = _server._packMe.pack(data);
		else if (data is! Uint8List && data is! String) {
			_server.onError?.call('Unsupported data type for Client.send, only PackMeMessage, Uint8List and String are supported');
			return;
		}
		if (data != null) socket.add(data);
	}

	void listen<T>(Future<void> Function(T) handler) {
		if (_handlers[T] == null) _handlers[T] = <Function>[];
		_handlers[T]!.add(handler);
	}

	void cancel<T>(Future<void> Function(T) handler) {
		_handlers[T]?.remove(handler);
	}
}

class ConnectMeServer {
	ConnectMeServer._(this.address, this.port, this._clientFactory, this.onLog, this.onError, this.onConnect, this.onDisconnect, this.onMessage);

	final InternetAddress address;
	final int port;
	late final HttpServer? httpServer;
	final List<Client> clients = <Client>[];
	final Client Function(WebSocket, HttpHeaders)? _clientFactory;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};

	final Function(String)? onLog;
	final Function(String, [StackTrace])? onError;
	final Function(Client)? onConnect;
	final Function(Client)? onDisconnect;
	final Function(dynamic data)? onMessage;

	Future<void> init() async {
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
				final Client client = _clientFactory != null ? _clientFactory!(socket, request.headers) : Client(socket, request.headers);
				client._server = this;
				clients.add(client);
				onConnect?.call(client);
			});
			onLog?.call('ConnectMe server is running on: ${httpServer!.address.address}${address.type != InternetAddressType.unix ? ' port ${httpServer!.port}' : ''}');
		}
	}

	void broadcast(dynamic data, {bool Function(Client)? where}) {
		if (data is PackMeMessage) data = _packMe.pack(data);
		else if (data is! Uint8List && data is! String) {
			onError?.call('Unsupported data type for ConnectMe.broadcast, only PackMeMessage, Uint8List and String are supported');
			return;
		}
		for (final Client client in clients) {
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