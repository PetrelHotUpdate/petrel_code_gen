import 'package:build/build.dart';
import 'package:petrel_register_code_gen/src/pertrel_register_builder.dart';
import 'package:source_gen/source_gen.dart';

Builder petrelRegisterBuilder(BuilderOptions options) => LibraryBuilder(
      PetrelRegisterBuilder(),
      generatedExtension: '.r.dart',
      options: options,
    );
