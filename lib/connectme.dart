library connectme;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:packme/packme.dart';

part 'classes/client.dart';
part 'classes/server.dart';

class ConnectMe {
	static Future<ConnectMeServer<C>> listen<C extends ConnectMeClient>(InternetAddress address, {
		int port = 0,
		C Function(WebSocket, HttpHeaders)? clientFactory,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(C)? onConnect,
		Function(C)? onDisconnect,
	}) async {
		final ConnectMeServer<C> server = ConnectMeServer<C>._(address, port, clientFactory, onLog, onError, onConnect, onDisconnect);
		await server._init();
		return server;
	}

	static Future<ConnectMeClient> connect(String url, {
		Map<String, dynamic> headers = const <String, dynamic>{},
		bool autoReconnect = true,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function()? onConnect,
		Function()? onDisconnect,
	}) async {
		final ConnectMeClient client = ConnectMeClient._(url, headers, autoReconnect, onLog, onError, onConnect, onDisconnect);
		await client._init();
		return client;
	}
}
