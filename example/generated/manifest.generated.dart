import 'package:packme/packme.dart';

class HowAreYouResponse extends PackMeMessage {
	HowAreYouResponse({
		required this.answer,
		required this.squareRoot,
	});
	HowAreYouResponse._empty();

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

	@override
	String toString() {
		return 'HowAreYouResponse\x1b[0m(answer: ${PackMe.dye(answer)}, squareRoot: ${PackMe.dye(squareRoot)})';
	}
}

class HowAreYouRequest extends PackMeMessage {
	HowAreYouRequest({
		required this.name,
		required this.number,
	});
	HowAreYouRequest._empty();

	late String name;
	late int number;
	
	HowAreYouResponse $response({
		required String answer,
		required double squareRoot,
	}) {
		final HowAreYouResponse message = HowAreYouResponse(answer: answer, squareRoot: squareRoot);
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

	@override
	String toString() {
		return 'HowAreYouRequest\x1b[0m(name: ${PackMe.dye(name)}, number: ${PackMe.dye(number)})';
	}
}

final Map<int, PackMeMessage Function()> manifestMessageFactory = <int, PackMeMessage Function()>{
	595126750: () => HowAreYouResponse._empty(),
	643804858: () => HowAreYouRequest._empty(),
};