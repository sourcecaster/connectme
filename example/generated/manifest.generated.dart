import 'package:packme/packme.dart';

class HowAreYouRequest extends PackMeMessage {
	late String name;
	late int number;
	
	@override
	HowAreYouResponse get $response {
		final HowAreYouResponse message = HowAreYouResponse();
		message.$request = this;
		return message;
	}
	
	@override
	int $estimate() {
		$reset();
		int bytes = 10;
		bytes += $stringBytes(name);
		return bytes;
	}
	
	@override
	void $pack() {
		$initPack(643804858);
		$packString(name);
		$packUint16(number);
	}
	
	@override
	void $unpack() {
		$initUnpack();
		name = $unpackString();
		number = $unpackUint16();
	}
	
}

class HowAreYouResponse extends PackMeMessage {
	late String answer;
	late double squareRoot;
	
	@override
	int $estimate() {
		$reset();
		int bytes = 16;
		bytes += $stringBytes(answer);
		return bytes;
	}
	
	@override
	void $pack() {
		$initPack(595126750);
		$packString(answer);
		$packDouble(squareRoot);
	}
	
	@override
	void $unpack() {
		$initUnpack();
		answer = $unpackString();
		squareRoot = $unpackDouble();
	}
	
}

final Map<int, PackMeMessage Function()> manifestMessageFactory = <int, PackMeMessage Function()>{
	643804858: () => HowAreYouRequest(),
	595126750: () => HowAreYouResponse(),
};