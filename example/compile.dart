import 'package:packme/compiler.dart' as compiler;

/// Usage: dart compile.dart <sourceDirectory> <destinationDirectory>

/// You can create a FileWatcher for all *.json files in your PackMe manifests
/// directory. To compile manifest.json from this example type:
/// dart example/compile.dart example example/generated

void main(List<String> args) {
	compiler.main(args);
}