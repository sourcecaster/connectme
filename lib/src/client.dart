part of connectme;

class _Query<T> {
	_Query(this.completer) : time = DateTime.now().millisecondsSinceEpoch;
	final Completer<T> completer;
	final int time;
}

class ConnectMeClient {
	ConnectMeClient(this.socket) :
			_packMe = socket._server!._packMe,
			_server = socket._server,
			address = null,
			headers = const <String, dynamic>{},
			port = 0,
			autoReconnect = false,
			queryTimeout = socket._server!.queryTimeout,
			onLog = socket._server!.onLog,
			onError = socket._server!.onError {
		_socketInitialized = true;
		_listenSocket();
	}

	ConnectMeClient._(this.address, this.headers, this.port, this.autoReconnect, this.queryTimeout, this.onLog, this.onError, this.onConnect, this.onDisconnect) :
			_packMe = PackMe(onError: onError),
			_server = null;

	final ConnectMeServer<ConnectMeClient>? _server;
	final PackMe _packMe;

	late ConnectMeSocket socket;
	final dynamic address;
	final Map<String, dynamic> headers;
	final int port;
	bool autoReconnect;
	int queryTimeout;

	bool _socketInitialized = false;
	bool _applyReconnect = true;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};
	final Map<int, _Query<PackMeMessage>> _queries = <int, _Query<PackMeMessage>>{};
	Timer? _queriesTimer;

	final Function(String)? onLog;
	final Function(String, [StackTrace])? onError;
	Function? onConnect;
	Function? onDisconnect;

	Future<void> connect() async {
		if (_server == null) {
			_applyReconnect = true;
			_queriesTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _checkQueriesTimeout());
			await onLog?.call('Connecting to $address...');

			InternetAddress? internetAddress;
			if (address is String) internetAddress = InternetAddress.tryParse(address as String);
			else if (address is InternetAddress) internetAddress = address as InternetAddress;
			else throw Exception('Address must be either String or InternetAddress instance');
			if (internetAddress == null) socket = ConnectMeSocket.ws(await WebSocket.connect(address as String, headers: headers));
			else socket = ConnectMeSocket.tcp(await Socket.connect(internetAddress, port));
			_socketInitialized = true;

			onConnect?.call();
			await onLog?.call('Connection established');
			_listenSocket();
		}
	}

	void _checkQueriesTimeout({bool cancelDueToClose = false}) {
		final List<int> keys = _queries.keys.toList();
		final int now = DateTime.now().millisecondsSinceEpoch;
		for (final int transactionId in keys) {
			if (now - _queries[transactionId]!.time >= queryTimeout * 1000 || cancelDueToClose) {
				final Completer<PackMeMessage> completer = _queries[transactionId]!.completer;
				_queries.remove(transactionId);
				completer.completeError('ConnectMe client.query() ${cancelDueToClose ? 'cancelled due to socket close' : 'response timed out'}');
			}
		}
	}

	Future<void> _processHandler(Function handler, dynamic data, [ConnectMeClient? client]) async {
		try {
			if (client != null) await handler(data, client);
			else await handler(data);
		}
		catch (err, stack) {
			onError?.call('ConnectMe message handler execution error: $err', stack);
		}
	}

	void _listenSocket() {
		socket.listen((dynamic data) {
			if (data is Uint8List) {
				final PackMeMessage? message = _packMe.unpack(data);
				if (message != null) {
					final int transactionId = message.$transactionId;
					if (_queries[transactionId] != null) {
						final Completer<PackMeMessage> completer = _queries[transactionId]!.completer;
						_queries.remove(transactionId);
						completer.complete(message);
						return;
					}
					data = message;
				}
			}
			final Type type = data is Uint8List ? Uint8List : data.runtimeType;
			if (_handlers[type] != null) {
				for (final Function handler in _handlers[type]!) _processHandler(handler, data);
			}
			if (_server != null && _server!._handlers[type] != null) {
				for (final Function handler in _server!._handlers[type]!) _processHandler(handler, data, this);
			}
		}, onDone: () {
			_checkQueriesTimeout(cancelDueToClose: true);
			if (_server != null) {
				_server!.clients.remove(this);
				onDisconnect?.call(this);
			}
			else {
				onDisconnect?.call();
				if (autoReconnect && _applyReconnect) {
					onError?.call('Connection to $address was closed, reconnect in 3 second...');
					Timer(const Duration(seconds: 3), connect);
				}
				else onLog?.call('Disconnected from $address');
			}
		}, onError: (dynamic err, StackTrace stack) {
			onError?.call('ConnectMe socket error has occurred: $err', stack);
		});
	}

	void register(Map<int, PackMeMessage Function()> messageFactory) {
		_packMe.register(messageFactory);
	}

	void send(dynamic data) {
		if (data is PackMeMessage) data = _packMe.pack(data);
		else if (data is! Uint8List && data is! String) {
			onError?.call('Unsupported data type for Client.send(), only PackMeMessage, Uint8List and String are supported');
			return;
		}
		if (data != null && socket.state == WebSocket.open) socket.add(data);
	}

	Future<T> query<T extends PackMeMessage>(PackMeMessage message) {
		final Completer<T> completer = Completer<T>();
		final Uint8List? data = _packMe.pack(message);
		if (data != null && socket.state == WebSocket.open) {
			_queries[message.$transactionId] = _Query<T>(completer);
			socket.add(data);
		}
		else {
			onError?.call("ConnectMe client.query() failed to pack message, future won't be resolved");
		}
		return completer.future;
	}

	void listen<T>(Function(T) handler) {
		if (_handlers[T] == null) _handlers[T] = <Function>[];
		_handlers[T]!.add(handler);
	}

	void cancel<T>(Function(T) handler) {
		_handlers[T]?.remove(handler);
	}

	Future<void> close() async {
		if (_queriesTimer != null) {
			_queriesTimer!.cancel();
			_queriesTimer = null;
		}
		_handlers.clear();
		_applyReconnect = false;
		if (_socketInitialized) await socket.close();
	}
}