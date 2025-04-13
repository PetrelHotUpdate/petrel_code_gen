// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:path/path.dart';
import 'package:petrel_register_code_gen/src/annotations.dart';
import 'package:source_gen/source_gen.dart';

class PetrelRegisterBuilder
    extends GeneratorForAnnotation<PetrelRegisterClass> {
  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final fileName = basename(buildStep.inputId.path);
    if (element is ClassElement) {
      final className = element.name;
      final newClassName = className.replaceFirst('_', '');
      final buffer = StringBuffer();
      buffer.writeln('part of "$fileName";');
      buffer.writeln('class $newClassName {');

      // 生成构造函数和字段
      final fieldsWithAnnotation = <FieldElement>[];
      for (var field in element.fields) {
        if (field.metadata
            .any((m) => m.element?.displayName == 'PetrelRegisterField')) {
          fieldsWithAnnotation.add(field);
          final fieldType = field.type.getDisplayString();
          final fieldName = field.name;
          buffer.writeln('  final $fieldType $fieldName;');
        }
      }

      // 生成构造函数
      final paramList =
          fieldsWithAnnotation.map((f) => 'required this.${f.name}').join(', ');
      buffer.writeln('  $newClassName({$paramList});');

      // 生成 register 方法
      buffer.writeln('\n  register() {');
      for (var field in fieldsWithAnnotation) {
        final fieldName = field.name;
        buffer
            .writeln('    nativeChannel.register(\'$fieldName\', $fieldName);');
      }
      buffer.writeln('  }');

      buffer.writeln('}');
      return buffer.toString();
    }
    return null;
  }
}
