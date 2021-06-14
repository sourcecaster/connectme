import 'dart:typed_data';
import 'package:packme/packme.dart';

class HowAreYouRequest extends PackMeMessage {
	late String name;
	late int number;
	
	@override
	int estimate() {
		reset();
		int bytes = 6;
		bytes += stringBytes(name);
		return bytes;
	}
	
	@override
	void pack() {
		data = Uint8List(estimate());
		packUint32(643804858);
		packString(name);
		packUint16(number);
	}
	
	@override
	void unpack() {
		unpackUint32();
		name = unpackString();
		number = unpackUint16();
	}
	
}

class HowAreYouResponse extends PackMeMessage {
	late String answer;
	late double squareRoot;
	
	@override
	int estimate() {
		reset();
		int bytes = 12;
		bytes += stringBytes(answer);
		return bytes;
	}
	
	@override
	void pack() {
		data = Uint8List(estimate());
		packUint32(595126750);
		packString(answer);
		packDouble(squareRoot);
	}
	
	@override
	void unpack() {
		unpackUint32();
		answer = unpackString();
		squareRoot = unpackDouble();
	}
	
}

final Map<int, PackMeMessage Function()> manifestMessageFactory = <int, PackMeMessage Function()>{
	643804858: () => HowAreYouRequest(),
	595126750: () => HowAreYouResponse(),
};