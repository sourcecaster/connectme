import 'dart:io';
import 'dart:math';
import 'package:connectme/connectme.dart';
import 'generated/manifest.generated.dart';

/// Most probably you'll use your own log and error handler systems. So the good
/// news are: you can pass those handlers to ConnectMe (onLog, onError).

void logMessage(String message) {
	print(message);
}

void logError(String error, [StackTrace? stack]) {
	print('ERROR: $error');
	if (stack != null) print(stack);
}

/// This custom client class is used to replace standard ConnectMeClient class
/// in ConnectMeServer (using classFactory argument).

class CustomServerClient extends ConnectMeClient {
	CustomServerClient(WebSocket socket, HttpHeaders headers) : super(socket, headers);
	late final String name;
	late final int age;
}

/// Create server, which will wait for message from connected clients then send
/// them a request to do some math operation.

Future<void> createTestServer() async {
	final Random rand = Random();
	late final ConnectMeServer<CustomServerClient> server;
	/// ConnectMeServer supports both ip address and unix named sockets.
	server = await ConnectMe.serve<CustomServerClient>(InternetAddress('127.0.0.1'),
		port: 31337,
		onLog: logMessage,
		onError: logError,
		onConnect: (CustomServerClient client) {
			logMessage('\n[SERVER]: A client from ${client.headers.host} has connected.');
		},
		onDisconnect: (CustomServerClient client) {
			logMessage('[SERVER]: A client ${client.name} has disconnected.');
			server.close();
		},
		/// Client factory returns our inherited class instance.
		clientFactory: (_, __) => CustomServerClient(_, __),
	);

	/// Register PackMe messages from generated/manifest.generated.dart in order
	/// to make server able to process them.
	server.register(manifestMessageFactory);

	/// Add global server String message listener. Once we get message, reply
	/// with String message and add new message listener for this client only.
	server.listen<String>((String message, CustomServerClient client) async {
		logMessage('[SERVER]: received message from client: $message');
		await Future<void>.delayed(const Duration(milliseconds: 500)); // We're thinking :)
		client.send('Hello sir! Could you please introduce yourself using PackMe message?');

		/// Now listen for specific PackMe message from this client.
		client.listen<IntroductionMessage>((IntroductionMessage message) async {
			logMessage('[SERVER]: received $message');
			/// This IntroductionMessage contains two fields: name and age.
			client.name = message.name;
			client.age = message.age;
			logMessage('[SERVER]: ok, this is ${client.name} and he is ${client.age} years old. Gonna ask him to do some math...');
			await Future<void>.delayed(const Duration(milliseconds: 500)); // We're thinking :)

			/// Now we'll send MathQuestionsRequest which contains two numbers
			/// and math operation. Expecting to get MathQuestionResponse.
			final MathQuestionResponse response = await client.query<MathQuestionResponse>(MathQuestionRequest(
				operation: MathOperation.values[rand.nextInt(MathOperation.values.length)],
				x: rand.nextInt(100),
				y: rand.nextInt(100),
			));
			logMessage('[SERVER]: received $response');
			logMessage("[SERVER]: the answer is ${response.result}. That's it.");
		});
	});
}

/// Create client, connect, send "Hello!" message, reply to server messages,
/// disconnect.

Future<void> createTestClient() async {
	final ConnectMeClient client = await ConnectMe.connect('ws://127.0.0.1:31337');

	/// Register PackMe messages from generated/manifest.generated.dart in order
	/// to make client able to process them.
	client.register(manifestMessageFactory);
	await Future<void>.delayed(const Duration(seconds: 1)); // We're thinking :)

	/// Say "Hello" and listen for String message from server. Then reply with
	/// IntroductionMessage.
	/// Note: client.send() and client.listen<T>() methods support String,
	/// PackMe messages or Uint8List.
	client.send('Hello!');
	client.listen<String>((String message) async {
		logMessage('[CLIENT]: server says: "$message"');
		await Future<void>.delayed(const Duration(seconds: 1)); // We're thinking :)
		client.send(IntroductionMessage(
			name: 'Eli Vance',
			age: 44,
		));
	});

	/// Listen for MathOperationRequest message and reply.
	client.listen<MathQuestionRequest>((MathQuestionRequest request) async {
		logMessage('[CLIENT]: received: "$request"');
		logMessage('[CLIENT]: they want us to do some math, okay...');
		await Future<void>.delayed(const Duration(seconds: 1)); // We're thinking :)
		double result;
		switch (request.operation) {
			case MathOperation.add:
				result = request.x.toDouble() + request.y.toDouble();
				break;
			case MathOperation.subtract:
				result = request.x.toDouble() - request.y.toDouble();
				break;
			case MathOperation.multiply:
				result = request.x.toDouble() * request.y.toDouble();
				break;
			case MathOperation.divide:
				result = request.x.toDouble() / request.y.toDouble();
				break;
		}
		client.send(request.$response(result: result));

		/// Wait a bit and disconnect.
		await Future<void>.delayed(const Duration(seconds: 2));
		client.close();
	});
}

/// Example entry point. We'll create test server, then wait a few seconds and
/// then create test client.

Future<void> main() async {
	await createTestServer();
	await Future<void>.delayed(const Duration(seconds: 2));
	await createTestClient();
}