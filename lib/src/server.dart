part of connectme;

class ConnectMeServer<C extends ConnectMeClient> {
	ConnectMeServer._(this.address, this.port, this.type, this._clientFactory, this.queryTimeout, this.onLog, this.onError, this.onConnect, this.onDisconnect) : _packMe = PackMe(onError: onError);

	final PackMe _packMe;
	final InternetAddress address;
	final int port;
	final ConnectMeType type;
	final int queryTimeout;
	HttpServer? _httpServer;
	ServerSocket? _tcpServer;
	final List<C> clients = <C>[];
	final C Function(ConnectMeSocket)? _clientFactory;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};
	Timer? clientsQueriesTimer;

	final Function(String)? onLog;
	final Function(String, [StackTrace])? onError;
	final Function(C)? onConnect;
	final Function(C)? onDisconnect;

	Future<void> _bind(InternetAddress address, int port) async {
		switch (type) {
			case ConnectMeType.ws:
				_httpServer = await HttpServer.bind(address, port);
				break;
			case ConnectMeType.tcp:
				_tcpServer = await ServerSocket.bind(address, port);
				break;
		}
	}

	Future<void> serve() async {
		final String protocol = type == ConnectMeType.ws ? 'WebSocket' : 'TCP';

		if (address.type == InternetAddressType.unix) {
			onLog?.call('Starting $protocol server using unix named socket...');
			final File socketFile = File(address.address);
			if (socketFile.existsSync()) socketFile.deleteSync(recursive: true);
			await _bind(address, 0);
			if (socketFile.existsSync()) Process.run('chmod', <String>['0677', address.address]);
		}
		else {
			onLog?.call('Starting $protocol server using IP address...');
			await _bind(address, port);
		}

		if (_httpServer != null) {
			_httpServer!.listen((HttpRequest request) async {
				final ConnectMeSocket socket = ConnectMeSocket.ws(await WebSocketTransformer.upgrade(request), request);
				socket._server = this;
				final C client = _clientFactory != null ? _clientFactory!(socket) : ConnectMeClient(socket) as C
					..onConnect = onConnect
					..onDisconnect = onDisconnect;
				clients.add(client);
				onConnect?.call(client);
			});
		}
		else if (_tcpServer != null) {
			_tcpServer!.listen((Socket tcpSocket) {
				final ConnectMeSocket socket = ConnectMeSocket.tcp(tcpSocket);
				socket._server = this;
				final C client = _clientFactory != null ? _clientFactory!(socket) : ConnectMeClient(socket) as C
					..onConnect = onConnect
					..onDisconnect = onDisconnect;
				clients.add(client);
				onConnect?.call(client);
			});
		}
		else return;

		onLog?.call('$protocol server is running on: ${address.address}${address.type != InternetAddressType.unix ? ' port $port' : ''}');
		clientsQueriesTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
			for (final C client in clients) client._checkQueriesTimeout();
		});
	}

	void register(Map<int, PackMeMessage Function()> messageFactory) {
		_packMe.register(messageFactory);
	}

	void broadcast(dynamic data, {bool Function(C)? where}) {
		if (data is PackMeMessage) data = _packMe.pack(data);
		else if (data is! Uint8List && data is! String) {
			onError?.call('Unsupported data type for ConnectMe.broadcast(), only PackMeMessage, Uint8List and String are supported');
			return;
		}
		for (final C client in clients) {
			if (where != null && !where(client)) continue;
			if (data != null && client.socket.state == WebSocket.open) client.socket.add(data);
		}
	}

	void listen<T>(Function(T, C) handler) {
		if (_handlers[T] == null) _handlers[T] = <Function>[];
		_handlers[T]!.add(handler);
	}

	void cancel<T>(Function(T, C) handler) {
		_handlers[T]?.remove(handler);
	}

	Future<void> close() async {
		if (clientsQueriesTimer != null) {
			clientsQueriesTimer!.cancel();
			clientsQueriesTimer = null;
		}
		for (int i = clients.length - 1; i >= 0; i--) {
			await clients[i].socket.close();
		}
		if (_httpServer != null) await _httpServer?.close();
		else if (_tcpServer != null) await _tcpServer?.close();
	}
}