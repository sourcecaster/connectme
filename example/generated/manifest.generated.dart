import 'package:packme/packme.dart';

enum MathOperation {
	add,
	subtract,
	multiply,
	divide,
}

class IntroductionMessage extends PackMeMessage {
	IntroductionMessage({
		required this.name,
		required this.age,
	});
	IntroductionMessage.$empty();

	late String name;
	late int age;

	@override
	int $estimate() {
		$reset();
		int _bytes = 9;
		_bytes += $stringBytes(name);
		return _bytes;
	}

	@override
	void $pack() {
		$initPack(377751248);
		$packString(name);
		$packUint8(age);
	}

	@override
	void $unpack() {
		$initUnpack();
		name = $unpackString();
		age = $unpackUint8();
	}

	@override
	String toString() {
		return 'IntroductionMessage\x1b[0m(name: ${PackMe.dye(name)}, age: ${PackMe.dye(age)})';
	}
}

class MathQuestionRequest extends PackMeMessage {
	MathQuestionRequest({
		required this.operation,
		required this.x,
		required this.y,
	});
	MathQuestionRequest.$empty();

	late MathOperation operation;
	late int x;
	late int y;

	MathQuestionResponse $response({
		required double result,
	}) {
		final MathQuestionResponse message = MathQuestionResponse(result: result);
		message.$request = this;
		return message;
	}

	@override
	int $estimate() {
		$reset();
		return 11;
	}

	@override
	void $pack() {
		$initPack(752154248);
		$packUint8(operation.index);
		$packUint8(x);
		$packUint8(y);
	}

	@override
	void $unpack() {
		$initUnpack();
		operation = MathOperation.values[$unpackUint8()];
		x = $unpackUint8();
		y = $unpackUint8();
	}

	@override
	String toString() {
		return 'MathQuestionRequest\x1b[0m(operation: ${PackMe.dye(operation)}, x: ${PackMe.dye(x)}, y: ${PackMe.dye(y)})';
	}
}

class MathQuestionResponse extends PackMeMessage {
	MathQuestionResponse({
		required this.result,
	});
	MathQuestionResponse.$empty();

	late double result;

	@override
	int $estimate() {
		$reset();
		return 16;
	}

	@override
	void $pack() {
		$initPack(142788393);
		$packDouble(result);
	}

	@override
	void $unpack() {
		$initUnpack();
		result = $unpackDouble();
	}

	@override
	String toString() {
		return 'MathQuestionResponse\x1b[0m(result: ${PackMe.dye(result)})';
	}
}

final Map<int, PackMeMessage Function()> manifestMessageFactory = <int, PackMeMessage Function()>{
	377751248: () => IntroductionMessage.$empty(),
	752154248: () => MathQuestionRequest.$empty(),
	142788393: () => MathQuestionResponse.$empty(),
};