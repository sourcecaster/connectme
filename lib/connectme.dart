library connectme;

import 'dart:io';
import 'dart:html' as html;
import 'dart:typed_data';

part 'classes/client.dart';
part 'classes/server.dart';

class ConnectMe {
	static Future<ConnectMeServer> listen(InternetAddress address, {
		int port = 0,
		Client Function(WebSocket, HttpHeaders)? clientFactory,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(Client)? onConnect,
		Function(Client)? onDisconnect,
		Function(dynamic data)? onMessage
	}) async {
		final ConnectMeServer server = ConnectMeServer._(address, port, clientFactory, onLog, onError, onConnect, onDisconnect, onMessage);
		await server.init();
		return server;
	}

	static Future<ConnectMeClient> connect(String url, {
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(Client)? onConnect,
		Function(Client)? onDisconnect,
		Function(dynamic data)? onMessage
	}) async {
		final ConnectMeClient client = ConnectMeClient._(url, onLog, onError, onConnect, onDisconnect, onMessage);
		await client.init();
		return client;
	}
}
