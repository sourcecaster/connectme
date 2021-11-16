import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectme/connectme.dart';
import 'package:test/test.dart';
import 'generated/test.generated.dart';

const Utf8Codec _utf8 = Utf8Codec();

void main() {
    late ConnectMeServer<ConnectMeClient> server;
    late ConnectMeClient client;
    late Timer timer;

    group('WebSocket connection tests', () {
        test('ConnectMe.serve() and ConnectMe.connect()', () async {
            timer = Timer(const Duration(seconds: 2), () => fail('Operation timed out'));
            server = await ConnectMe.serve(InternetAddress('127.0.0.1'),
                port: 31337,
                type: ConnectMeType.ws,
                onConnect: expectAsync1<void, dynamic>((dynamic client) {
                    expect(client, isA<ConnectMeClient>());
                }),
            );
            client = await ConnectMe.connect('ws://127.0.0.1:31337',
                onConnect: expectAsync0<void>(() {}),
            );
            await client.close();
            await server.close();
            timer.cancel();
        });
    });

    group('TCP connection tests', () {
        test('ConnectMe.serve() and ConnectMe.connect()', () async {
            timer = Timer(const Duration(seconds: 2), () => fail('Operation timed out'));
            server = await ConnectMe.serve(InternetAddress('127.0.0.1'),
                port: 31337,
                type: ConnectMeType.tcp,
                onConnect: expectAsync1<void, dynamic>((dynamic client) {
                    expect(client, isA<ConnectMeClient>());
                }),
            );
            client = await ConnectMe.connect('127.0.0.1',
                port: 31337,
                onConnect: expectAsync0<void>(() {}),
            );
            await client.close();
            await server.close();
            timer.cancel();
        });
    });

    group('WebSocket message exchange tests', () {
        setUp(() async {
            timer = Timer(const Duration(seconds: 2), () => fail('Operation timed out'));
            server = await ConnectMe.serve(InternetAddress('127.0.0.1'), port: 31337, type: ConnectMeType.ws);
            client = await ConnectMe.connect('ws://127.0.0.1:31337');
        });

        tearDown(() async {
            await client.close();
            await server.close();
            timer.cancel();
        });

        test('Client sends String to server', () async {
            final Completer<String> completer = Completer<String>();
            server.listen<String>((String message, ConnectMeClient client) {
                completer.complete(message);
            });
            client.send('Test message from client');
            expect(await completer.future, 'Test message from client');
        });

        test('Server broadcasts String to clients', () async {
            final Completer<String> completer = Completer<String>();
            client.listen<String>((String message) {
                completer.complete(message);
            });
            server.broadcast('Test message from server');
            expect(await completer.future, 'Test message from server');
        });

        test('Client sends Uint8List to server', () async {
            final Completer<Uint8List> completer = Completer<Uint8List>();
            server.listen<Uint8List>((Uint8List message, ConnectMeClient client) {
                completer.complete(message);
            });
            client.send(Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
            expect(await completer.future, Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
        });

        test('Server broadcasts Uint8List to clients', () async {
            final Completer<Uint8List> completer = Completer<Uint8List>();
            client.listen<Uint8List>((Uint8List message) {
                completer.complete(message);
            });
            server.broadcast(Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
            expect(await completer.future, Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
        });

        test('Client sends TestResponse query to server', () async {
            server.register(testMessageFactory);
            server.listen<TestRequest>((TestRequest request, ConnectMeClient client) {
                client.send(request.$response(responseParam: request.requestParam));
            });
            client.register(testMessageFactory);
            final TestResponse response = await client.query<TestResponse>(TestRequest(requestParam: 3.1415926535));
            expect(response.responseParam, 3.1415926535);
        });

        test('Server sends TestResponse query to client', () async {
            client.register(testMessageFactory);
            client.listen<TestRequest>((TestRequest request) {
                client.send(request.$response(responseParam: request.requestParam));
            });
            server.register(testMessageFactory);
            final TestResponse response = await server.clients.first.query<TestResponse>(TestRequest(requestParam: 3.1415926535));
            expect(response.responseParam, 3.1415926535);
        });
    });

    group('TCP message exchange tests', () {
        setUp(() async {
            timer = Timer(const Duration(seconds: 2), () => fail('Operation timed out'));
            server = await ConnectMe.serve(InternetAddress('127.0.0.1'), port: 31337, type: ConnectMeType.tcp);
            client = await ConnectMe.connect('127.0.0.1', port: 31337);
        });

        tearDown(() async {
            await client.close();
            await server.close();
            timer.cancel();
        });

        test('Client sends String to server', () async {
            final Completer<Uint8List> completer = Completer<Uint8List>();
            server.listen<Uint8List>((Uint8List message, ConnectMeClient client) {
                completer.complete(message);
            });
            client.send('Test message from client');
            final List<int> expected = _utf8.encode('Test message from client');
            expect(await completer.future, Uint8List.fromList(expected));
        });

        test('Server broadcasts String to clients', () async {
            final Completer<Uint8List> completer = Completer<Uint8List>();
            client.listen<Uint8List>((Uint8List message) {
                completer.complete(message);
            });
            server.broadcast('Test message from server');
            final List<int> expected = _utf8.encode('Test message from server');
            expect(await completer.future, Uint8List.fromList(expected));
        });

        test('Client sends Uint8List to server', () async {
            final Completer<Uint8List> completer = Completer<Uint8List>();
            server.listen<Uint8List>((Uint8List message, ConnectMeClient client) {
                completer.complete(message);
            });
            client.send(Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
            expect(await completer.future, Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
        });

        test('Server broadcasts Uint8List to clients', () async {
            final Completer<Uint8List> completer = Completer<Uint8List>();
            client.listen<Uint8List>((Uint8List message) {
                completer.complete(message);
            });
            server.broadcast(Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
            expect(await completer.future, Uint8List.fromList(<int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]));
        });

        test('Client sends TestResponse query to server', () async {
            server.register(testMessageFactory);
            server.listen<TestRequest>((TestRequest request, ConnectMeClient client) {
                client.send(request.$response(responseParam: request.requestParam));
            });
            client.register(testMessageFactory);
            final TestResponse response = await client.query<TestResponse>(TestRequest(requestParam: 3.1415926535));
            expect(response.responseParam, 3.1415926535);
        });

        test('Server sends TestResponse query to client', () async {
            client.register(testMessageFactory);
            client.listen<TestRequest>((TestRequest request) {
                client.send(request.$response(responseParam: request.requestParam));
            });
            server.register(testMessageFactory);
            final TestResponse response = await server.clients.first.query<TestResponse>(TestRequest(requestParam: 3.1415926535));
            expect(response.responseParam, 3.1415926535);
        });
    });
}