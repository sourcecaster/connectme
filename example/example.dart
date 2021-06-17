import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectme/connectme.dart';
import 'generated/manifest.generated.dart';

/// We'll use it to randomly assign a name to every new client.

const List<String> clientCodeNames = <String>['Bob', 'Maria', 'Peter', 'Max', 'Ron', 'Steve', 'Richard', 'Alice'];

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

class CustomClient extends ConnectMeClient {
	CustomClient(WebSocket socket, HttpHeaders headers) : super(socket, headers);
	late final String name;
}

/// Create client, connect, say something, disconnect.

Future<void> connectSaySomethingAndDisconnect() async {
	final ConnectMeClient client = await ConnectMe.connect('ws://127.0.0.1:31337');

	/// Register PackMe messages from generated/manifest.generated.dart in order
	/// to make client able to process them.
	client.register(manifestMessageFactory);

	/// Listen for HowAreYouRequest message and reply.
	client.listen<HowAreYouRequest>((HowAreYouRequest data) async {
		final String myName = data.name;
		final int numberToCalcRootFrom = data.number;
		final HowAreYouResponse response = data.$response
			..answer = '$numberToCalcRootFrom you say? $myName knows the answer, check it out.'
			..squareRoot = sqrt(numberToCalcRootFrom);
		await Future<void>.delayed(const Duration(seconds: 1));
		client.send(response);
	});
	await Future<void>.delayed(const Duration(seconds: 1));

	/// Say hello and wait before closing connection.
	client.send('Hello there!');
	await Future<void>.delayed(const Duration(seconds: 2));
	client.close();
}

/// Example entry point.

Future<void> main() async {
	final Random rand = Random();
	/// ConnectMeServer supports both ip address and unix named sockets.
	final ConnectMeServer<CustomClient> server = await ConnectMe.serve<CustomClient>(InternetAddress('127.0.0.1'),
		port: 31337,
		onLog: logMessage,
		onError: logError,
		onConnect: (CustomClient client) {
			/// Assign a random name to our client.
			final String name = clientCodeNames[rand.nextInt(clientCodeNames.length)];
			client.name = name;
			logMessage('\nA client from ${client.headers.host} has connected :) Hello, ${client.name}!');
		},
		onDisconnect: (CustomClient client) {
			logMessage('A client named ${client.name} has disconnected :(');
		},
		/// Client factory returns our inherited class instance.
		clientFactory: (_, __) => CustomClient(_, __),
	);

	/// Register PackMe messages from generated/manifest.generated.dart in order
	/// to make server able to process them.
	server.register(manifestMessageFactory);

	/// Add global server String message listener.
	server.listen<String>((String message, CustomClient client) async {
		logMessage('${client.name} says: $message');

		/// Once we've got hello message from the client, send him a PackMe
		/// HowAreYouRequest message.
		final HowAreYouRequest request = HowAreYouRequest()
			..name = client.name
			..number = rand.nextInt(65536);
		logMessage("How are you, ${client.name}? Tell me what's the square root of ${request.number}?");
		final HowAreYouResponse response = await client.query<HowAreYouResponse>(request);
		logMessage('${client.name} says: ${response.answer}');
		logMessage("And his answer is absolutely correct! It's ${response.squareRoot}!");
	});

	/// We could add global PackMe HowAreYouResponse message listener and use
	/// client.send() instead of client.query(). The result would be pretty the
	/// same though it's a different approach.
	// server.listen<HowAreYouResponse>((HowAreYouResponse data, CustomClient client) async {
	// 	logMessage('${client.name} says: ${data.answer}');
	// 	logMessage("And his answer is absolutely correct! It's ${data.squareRoot}!");
	// });

	/// Every 5 seconds we'll connect to 127.0.0.1, send String message,
	/// PackeMeMessage and disconnect.
	Timer.periodic(const Duration(seconds: 5), (_) {
		connectSaySomethingAndDisconnect();
	});
	logMessage('Wait for 5 seconds and someone will connect for sure.');
}