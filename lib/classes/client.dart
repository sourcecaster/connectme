part of connectme;

class ConnectMeClient {
	ConnectMeClient(this.socket, this.headers) : url = '', _autoReconnect = false, requestHeaders = const <String, dynamic>{} {
		_listenSocket(asServer: true);
	}

	ConnectMeClient._(this.url, this.requestHeaders, this._autoReconnect, this.onLog, this.onError, this.onConnect, this.onDisconnect) : _packMe = PackMe(onError: onError);

	late final PackMe _packMe;
	final String url;
	final bool _autoReconnect;
	bool _applyReconnect = true;
	late final ConnectMeServer<ConnectMeClient> _server;
	final Map<Type, List<Function>> _handlers = <Type, List<Function>>{};
	late WebSocket socket;
	late final HttpHeaders headers;
	final Map<String, dynamic> requestHeaders;

	late final Function(String)? onLog;
	late final Function(String, [StackTrace])? onError;
	late final Function? onConnect;
	late final Function? onDisconnect;

	Future<void> _init() async {
		await onLog?.call('Connecting to $url...');
		socket = await WebSocket.connect(url, headers: requestHeaders);
		onConnect?.call();
		await onLog?.call('Connection established');
		_listenSocket(asServer: false);
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
		socket.listen((dynamic data) {
			if (data is Uint8List) {
				final PackMeMessage? message = _packMe.unpack(data);
				if (message != null) data = message;
			}
			if (asServer && _server._handlers[data.runtimeType] != null) {
				for (final Function handler in _server._handlers[data.runtimeType]!) _processHandler(handler, data, this);
			}
			if (_handlers[data.runtimeType] != null) {
				for (final Function handler in _handlers[data.runtimeType]!) _processHandler(handler, data);
			}
		}, onDone: () {
			if (asServer) {
				_server.clients.remove(this);
				onDisconnect?.call(this);
			}
			else {
				onDisconnect?.call();
				if (_autoReconnect && _applyReconnect) {
					onError?.call('Connection to $url was closed, reconnect in 3 second...');
					Timer(const Duration(seconds: 3), _init);
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
			onError?.call('Unsupported data type for Client.send, only PackMeMessage, Uint8List and String are supported');
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

	Future<void> close() async {
		_applyReconnect = false;
		await socket.close();
	}
}