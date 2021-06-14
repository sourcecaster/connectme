part of connectme;

class ConnectMeClient {
	ConnectMeClient._(this.url, this.onLog, this.onError, this.onConnect, this.onDisconnect, this.onMessage);

	final String url;

	final Function(String)? onLog;
	final Function(String, [StackTrace])? onError;
	final Function(Client)? onConnect;
	final Function(Client)? onDisconnect;
	final Function(dynamic data)? onMessage;

	Future<void> init() async {

	}

	Future<void> close() async {

	}
}