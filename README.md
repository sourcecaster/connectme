## What is ConnectMe
ConnectMe is a lightweight library for working with WebSocket or TCP connections both on client and server sides. It allows you to:
* create connections to WebSocket servers with different options (like autoReconnect, queryTimeout);
* create WebSocket servers using any InternetAddress object;
* manage connections on server side using default or your own Client class;
* send messages of different data types: String, Uint8List or PackMe messages;
* listen to any messages (including possibility to listen for specific client on server side);
* asynchronously query data using [PackMe](https://pub.dev/packages/packme) messages: SomeResponse response = await client.query(SomeRequest());
* broadcast messages to all clients or group of clients specified by criteria;

## It is integrated with PackMe 
[PackMe](https://pub.dev/packages/packme) is an extremely fast binary serializer with built-in script for generating .dart classes from simple JSON manifest files. It provides an easy and efficient way to pack your class objects into binary buffers and vice versa. 

## Usage
It is recommended to use [PackMe](https://pub.dev/packages/packme) messages for data exchange since it gives some important benefits such as clear communication protocol described in JSON, asynchronous queries support out of the box and small data packets size.

Here's a simple manifest.json file (located in packme directory) for some hypothetical client-server application (see PackMe JSON manifest format documentation [here](https://pub.dev/packages/packme)):
```json
{
    "get_user": [
        {
            "id": "string"
        },
        {
            "first_name": "string",
            "last_name": "string",
            "age": "uint8"
        }
    ]
}
```
Generate dart files:
```bash
# Usage: dart run packme <json_manifests_dir> <generated_classes_dir>
dart run packme packme generated
```
Using on server side:
```dart
import 'generated/manifest.generated.dart';
import 'package:connectme/connectme.dart';

void main() async {
    final ConnectMeServer server = await ConnectMe.serve(InternetAddress('127.0.0.1'),
        port: 31337,
        onConnect: (ConnectMeClient client) {
            print('${client.headers.host} connected.');
        },
        onDisconnect: (ConnectMeClient client) {
            print('${client.headers.host} disconnected.');
        },
        type: ConnectMeType.ws, // by default, means using WebSocket server, can be also pure TCP
    );
    
    // Listen for a String message and send reverse string back to client.
    // (Note: it will not work with TCP server since all Strings are sent as Uint8List)
    server.listen<String>((String message, ConnectMeClient client) {
        client.send(message.split('').reversed.join(''));
    });

    // Register PackMe messages from manifest.generated.dart to be able to listen for them.
    server.register(manifestMessageFactory);
    
    // Listen for GetUserRequest message and reply with GetUserResponse.
    server.listen<GetUserRequest>((GetUserRequest request, ConnectMeClient client) {
        // GetUserRequest.$response method returns GetUserResponse associated with current request.
        final GetUserResponse response = request.$response(
            firstName: 'Alyx',
            lastName: 'Vance',
            age: 19,
        );
    });
}
```
Using on client side:
```dart
import 'generated/manifest.generated.dart';
import 'package:connectme/connectme.dart';

void main() async {
    final ConnectMeClient client = await ConnectMe.connect('ws://127.0.0.1:31337');
    
    // Register PackMe messages from manifest.generated.dart to be able to process them.
    client.register(manifestMessageFactory);

    // Listen for reverse String messages from the server.
    client.listen<String>((String message) {
        print('Here is our reversed string: $message');
    });
    
    // Send a string message to the server.
    client.send('Was it a car or a cat I saw?');
    
    // Query user data from the server. 
    final GetUserResponse response = client.query<GetUserResponse>(GetUserRequest(id: 'hl3'));
    print('A person name is ${response.firstName} ${response.lastName} and she is ${response.age} years old.');
}
```

## Server initialization and options
There are two methods available: 
* ConnectMe.server\<T>(InternetAddress address, {options}) - creates and returns ConnectMeServer instance; 
* ConnectMe.serve\<T>(InternetAddress address, {options}) - creates ConnectMeServer instance and runs it. Returns Future\<ConnectMeServer>.
Generic \<T> specifies a client class which will be used by server. By default it's ConnectMeClient. Any custom class must be derived from ConnectMeClient.
Both methods have the same options available:
* int port - port to listen (leave empty when using unix named sockets), default value: 0;
* T Function(ConnectMeSocket)? clientFactory - factory function which returns T class instance;
* int queryTimeout - timeout of query calls in seconds, default value: 30; 
* Function(String)? onLog - log function, it is recommended to always set it;
* Function(String, \[StackTrace])? onError - error handler function, it is recommended to always set it;
* Function(T)? onConnect - client connect callback;
* Function(T)? onDisconnect - client disconnect callback.
```dart
final ConnectMeServer server = ConnectMe.server(...);
await server.serve();

// Is the same as:

final ConnectMeServer server = await ConnectMe.serve(InternetAddress('127.0.0.1'),
```

## Client initialization and options
There are two methods available:
* ConnectMe.client(dynamic address, {options}) - creates and returns ConnectMeClient instance;
* ConnectMe.connect(dynamic address, {options}) - creates ConnectMeClient instance and establishes a connection. Returns Future\<ConnectMeClient>.
If address is a valid url starting with 'ws://' or 'wss://' then WebSocket connection is established. If address is an instance of InternetAddress then TCP Socket connection will be used.
Both methods have the same options available:
* Map\<String, dynamic> headers - custom headers to send on connection;
* bool autoReconnect - automatically reconnect when connection is lost, true by default;
* int queryTimeout - timeout of query calls in seconds, default value: 30;
* Function(String)? onLog - log function, it is recommended to always set it;
* Function(String, \[StackTrace])? onError - error handler function, it is recommended to always set it;
* Function()? onConnect - connect callback;
* Function()? onDisconnect - disconnect callback.
```dart
final ConnectMeClient client = ConnectMe.client(...);
await client.connect();

// Is the the same as:

final ConnectMeClient client = await ConnectMe.connect(...);
```

## Send data
You can send messages of different data types: String, Uint8List and [PackMe](https://pub.dev/packages/packme) messages.
```dart
client.send("Is this what you've been waiting for?");
client.send(Uint8List.fromList(<int>[1, 2, 4]));
client.send(GetUserResponse(
    firstName: 'Alyx',
    lastName: 'Vance',
    age: 19,
));
```
Keep in mind that GetUserResponse is sent as Uint8List as well. It means there is a tiny chance that your Uint8List data might be identified as [PackMe](https://pub.dev/packages/packme) message. In order to avoid this, it is not recommended to mix Uint8List and PackMe messages within a single client or server instance. Or just ensure that the first 4 bytes of your data never match those specified in registered PackMe message factories (Map<int, PackMeMessage> keys). 

## Listen for message events
Methods server.listen\<T>(Function(T, C) handler) and client.listen\<T>(Function(T) handler) allows you to listen for a message of specific type \<T>. In order to cancel message listener call method cancel\<T>(handler).
```dart
void _handleServerStringMessage(String message, ConnectMeClient client) {
    print('Got a message: $message from client ${client.headers.host}');
}

void _handleServerGetUserRequest(GetUserRequest request, ConnectMeClient client) {
    print('A client ${client.headers.host} asked for a user with ID: ${request.id}');
}

void _handleClientGetUserResponse(GetUserResponse response) {
    print('Got a user from server: $response');
}

void main() async {
    // ... whatever code goes here
    
    server.listen<String>(_handleServerStringMessage);
    server.listen<GetUserRequest>(_handleServerGetUserRequest);
    client.listen<GetUserResponse>(_handleClientGetUserResponse);
    
    // ... whatever code goes here
    
    server.cancel<String>(_handleServerStringMessage);
    server.cancel<GetUserRequest>(_handleServerGetUserRequest);
    client.cancel<GetUserResponse>(_handleClientGetUserResponse);
}
```

## Listen for specific client messages
Sometimes it is useful to be able to add message listeners for some specific clients only, for example, logged in users only. Instead of verifying it in global message listeners (which is less secure).
```dart
bool _isAuthorizedToDoSomething(String codePhrase) {
    return codePhrase == "I am Iron Man.";
}

void main() async {
    // ... whatever code goes here
    
    // Listen for some authorization request from connected clients.
    server.listen<AuthorizeRequest>((AuthorizeRequest request, ConnectMeClient client) {
        if (_isAuthorizedToDoSomething(request.codePhrase)) {
            client.listen<GodModeRequest>(_handleGodModeRequest);
            client.listen<AllWeaponsRequest>(_handleAllWeaponsRequest);
            client.listen<KillEveryoneRequest>(_handleKillEveryoneRequest);
            client.send(request.$response(
                allowed: true,
                reason: 'Welcome on board!',
            ));
        }
        else {
            client.send(request.$response(
                allowed: false,
                reason: 'You are not Iron Man.',
            ));
            // Close client connection.
            client.close();
        }
    });
}

```

## Broadcasting messages
ConnectMeServer has a method broadcast() which allows you to send a message to all connected clients:
```dart
// Send a String message to all connected clients.
server.broadcast('Cheese for Everyone!');

// Send a String message to specific clients only.
server.broadcast('Scratch that! Cheese for no one.', (ConnectMeClient client) {
    return client.headers.host == '127.0.0.1';
});
```

## Managing server clients
You can access all connected clients via property List\<T> server.clients - where \<T> is your class for clients (ConnectMeClient by default). Every client has two useful properties:
* WebSocket? socket - client connection socket;
* late final HttpHeaders headers - HTTP headers sent by client on connection;
```dart
// Close all local connections. Keep in mind that it will automatically remove those clients from server.clients.
List<ConnectMeClient> _clientsToDisconnect = <ConnectMeClient>[];
_clientsToDisconnect.addAll(server.clients.where((ConnectMeClient client) => client.headers.host == '127.0.0.1'));
for (final ConnectMeClient client in _clientsToDisconnect) client.close();
```

## Supported platforms
Now it's available for Dart only. Soon will be implemented for JavaScript. Will there be more platforms? Well it depends... If developers will find this package useful then it will be implemented for C++ I guess.
