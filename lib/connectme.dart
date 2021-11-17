library connectme;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:packme/packme.dart';

part 'src/client.dart';
part 'src/server.dart';
part 'src/socket.dart';

enum ConnectMeType {
	ws,
	tcp,
}

class ConnectMe {
	static ConnectMeServer<C> server<C extends ConnectMeClient>(InternetAddress address, {
		int port = 0,
		C Function(ConnectMeSocket)? clientFactory,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(C)? onConnect,
		Function(C)? onDisconnect,
		ConnectMeType type = ConnectMeType.ws,
	}) {
		return ConnectMeServer<C>._(address, port, type, clientFactory, queryTimeout, onLog, onError, onConnect, onDisconnect);
	}

	static Future<ConnectMeServer<C>> serve<C extends ConnectMeClient>(InternetAddress address, {
		int port = 0,
		C Function(ConnectMeSocket)? clientFactory,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function(C)? onConnect,
		Function(C)? onDisconnect,
		ConnectMeType type = ConnectMeType.ws,
	}) async {
		final ConnectMeServer<C> server = ConnectMeServer<C>._(address, port, type, clientFactory, queryTimeout, onLog, onError, onConnect, onDisconnect);
		await server.serve();
		return server;
	}

	static ConnectMeClient client(dynamic address, {
		Map<String, dynamic> headers = const <String, dynamic>{},
		int port = 0,
		bool autoReconnect = true,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function()? onConnect,
		Function()? onDisconnect,
	}) {
		return ConnectMeClient._(address, headers, port, autoReconnect, queryTimeout, onLog, onError, onConnect, onDisconnect);
	}

	static Future<ConnectMeClient> connect(dynamic address, {
		Map<String, dynamic> headers = const <String, dynamic>{},
		int port = 0,
		bool autoReconnect = true,
		int queryTimeout = 30,
		Function(String)? onLog,
		Function(String, [StackTrace])? onError,
		Function()? onConnect,
		Function()? onDisconnect,
	}) async {
		final ConnectMeClient client = ConnectMeClient._(address, headers, port, autoReconnect, queryTimeout, onLog, onError, onConnect, onDisconnect);
		await client.connect();
		return client;
	}
}
