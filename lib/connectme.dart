library connectme;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:packme/packme.dart';

part 'src/client.dart';
part 'src/server.dart';

class ConnectMe {
	static ConnectMeServer<C> server<C extends ConnectMeClient>(InternetAddress address, {
		int port = 0,
		C Function(WebSocket, HttpHeaders)? clientFactory,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(C)? onConnect,
		Function(C)? onDisconnect,
	}) {
		return ConnectMeServer<C>._(address, port, clientFactory, queryTimeout, onLog, onError, onConnect, onDisconnect);
	}

	static Future<ConnectMeServer<C>> serve<C extends ConnectMeClient>(InternetAddress address, {
		int port = 0,
		C Function(WebSocket, HttpHeaders)? clientFactory,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(C)? onConnect,
		Function(C)? onDisconnect,
	}) async {
		final ConnectMeServer<C> server = ConnectMeServer<C>._(address, port, clientFactory, queryTimeout, onLog, onError, onConnect, onDisconnect);
		await server.serve();
		return server;
	}

	static ConnectMeClient client(String url, {
		Map<String, dynamic> headers = const <String, dynamic>{},
		bool autoReconnect = true,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function()? onConnect,
		Function()? onDisconnect,
	}) {
		return ConnectMeClient._(url, headers, autoReconnect, queryTimeout, onLog, onError, onConnect, onDisconnect);
	}

	static Future<ConnectMeClient> connect(String url, {
		Map<String, dynamic> headers = const <String, dynamic>{},
		bool autoReconnect = true,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function()? onConnect,
		Function()? onDisconnect,
	}) async {
		final ConnectMeClient client = ConnectMeClient._(url, headers, autoReconnect, queryTimeout, onLog, onError, onConnect, onDisconnect);
		await client.connect();
		return client;
	}
}
