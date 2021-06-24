part of connectme;

class _Query<T> {
	_Query(this.completer) : time = DateTime.now().millisecondsSinceEpoch;
	final Completer<T> completer;
	final int time;
}

class ConnectMeClient {
	ConnectMeClient(this.socket, this.headers) : url = '', _autoReconnect = false, requestHeaders = const <String, dynamic>{} {
		_listenSocket(asServer: true);
	}

	ConnectMeClient._(this.url, this.requestHeaders, this._autoReconnect, this.queryTimeout, this.onLog, this.onError, this.onConnect, this.onDisconnect) : _packMe = PackMe(onError: onError);

	late final PackMe _packMe;
	final String url;
	final bool _autoReconnect;
	bool _applyReconnect = true;
	late final int queryTimeout;
	late final ConnectMeServer<ConnectMeClient> _server;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};
	WebSocket? socket;
	late final HttpHeaders headers;
	final Map<String, dynamic> requestHeaders;
	final Map<int, _Query<PackMeMessage>> queries = <int, _Query<PackMeMessage>>{};
	Timer? queriesTimer;

	late final Function(String)? onLog;
	late final Function(String, [StackTrace])? onError;
	late final Function? onConnect;
	late final Function? onDisconnect;

	Future<void> connect() async {
		_applyReconnect = true;
		queriesTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _checkQueriesTimeout());
		await onLog?.call('Connecting to $url...');
		socket = await WebSocket.connect(url, headers: requestHeaders);
		onConnect?.call();
		await onLog?.call('Connection established');
		_listenSocket(asServer: false);
	}

	void _checkQueriesTimeout({bool cancelDueToClose = false}) {
		final List<int> keys = queries.keys.toList();
		final int now = DateTime.now().millisecondsSinceEpoch;
		for (final int transactionId in keys) {
			if (now - queries[transactionId]!.time >= queryTimeout * 1000 || cancelDueToClose) {
				final Completer<PackMeMessage> completer = queries[transactionId]!.completer;
				queries.remove(transactionId);
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

	void _listenSocket({required bool asServer}) {
		socket?.listen((dynamic data) {
			if (data is Uint8List) {
				final PackMeMessage? message = _packMe.unpack(data);
				if (message != null) {
					final int transactionId = message.$transactionId;
					if (queries[transactionId] != null) {
						final Completer<PackMeMessage> completer = queries[transactionId]!.completer;
						queries.remove(transactionId);
						completer.complete(message);
						return;
					}
					data = message;
				}
			}
			if (_handlers[data.runtimeType] != null) {
				for (final Function handler in _handlers[data.runtimeType]!) _processHandler(handler, data);
			}
			if (asServer && _server._handlers[data.runtimeType] != null) {
				for (final Function handler in _server._handlers[data.runtimeType]!) _processHandler(handler, data, this);
			}
		}, onDone: () {
			_checkQueriesTimeout(cancelDueToClose: true);
			if (asServer) {
				_server.clients.remove(this);
				onDisconnect?.call(this);
			}
			else {
				onDisconnect?.call();
				if (_autoReconnect && _applyReconnect) {
					onError?.call('Connection to $url was closed, reconnect in 3 second...');
					Timer(const Duration(seconds: 3), connect);
				}
				else onLog?.call('Disconnected from $url');
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
		if (data != null && socket?.readyState == WebSocket.open) socket!.add(data);
	}

	Future<T> query<T extends PackMeMessage>(PackMeMessage message) {
		final Completer<T> completer = Completer<T>();
		final Uint8List? data = _packMe.pack(message);
		if (data != null && socket?.readyState == WebSocket.open) {
			queries[message.$transactionId] = _Query<T>(completer);
			socket!.add(data);
		}
		else {
			onError?.call("ConnectMe client.query() failed to pack message, future won't be resolved");
		}
		return completer.future;
	}

	void listen<T>(Future<void> Function(T) handler) {
		if (_handlers[T] == null) _handlers[T] = <Function>[];
		_handlers[T]!.add(handler);
	}

	void cancel<T>(Future<void> Function(T) handler) {
		_handlers[T]?.remove(handler);
	}

	Future<void> close() async {
		if (queriesTimer != null) {
			queriesTimer!.cancel();
			queriesTimer = null;
		}
		_handlers.clear();
		_applyReconnect = false;
		await socket?.close();
	}
}