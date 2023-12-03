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
	final Map<String, Function> _routes = <String, Function>{};
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
			case ConnectMeType.http:
				_httpServer = await HttpServer.bind(address, port);
				break;
		}
	}

	Future<void> serve() async {
		final String protocol = type == ConnectMeType.ws ? 'WebSocket' : 'TCP';

		try {
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
		}
		catch (err, stack) {
			onError?.call('Unable to bind $protocol server to $address: $err', stack);
			return;
		}

		try {
			if (_httpServer != null) {
				if (type == ConnectMeType.ws) {
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
				else {
					_httpServer!.listen((HttpRequest request) async {
						if (_routes[request.uri.path] != null) {
							try {
								await _routes[request.uri.path]?.call(request);
							}
							catch (err, stack) {
								try {
									request.response
										..statusCode = HttpStatus.internalServerError
										..close();
								}
								catch (err) { /* Ignore */ }
								onError?.call('An error occurred while processing a HTTP ${request.uri.path} request: $err', stack);
							}
						}
						else {
							request.response
								..statusCode = HttpStatus.notFound
								..close();
						}
					});
				}
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
		}
		catch (err, stack) {
			onError?.call('Unable to listen to $protocol server socket: $err', stack);
			return;
		}

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

	void on(String route, Function(HttpRequest request) handler) {
		if (type != ConnectMeType.http) throw Exception('Unable to add routes for non HTTP server.');
		if (!RegExp('^/.*').hasMatch(route)) route = '/$route';
		_routes[route] = handler;
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
		final List<Future<void>> promises = <Future<void>>[];
		for (int i = clients.length - 1; i >= 0; i--) {
			promises.add(clients[i].close());
		}
		await Future.wait(promises);
		clients.clear();
		if (_httpServer != null) await _httpServer?.close();
		else if (_tcpServer != null) await _tcpServer?.close();
	}
}