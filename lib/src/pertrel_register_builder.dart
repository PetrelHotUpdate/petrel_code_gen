// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:petrel_register_code_gen/src/annotations.dart';
import 'package:source_gen/source_gen.dart';

class PetrelRegisterBuilder
    extends GeneratorForAnnotation<PetrelRegisterClass> {
  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is ClassElement) {
      final className = element.name;
      final newClassName = className.replaceFirst('_', '');
      final buffer = StringBuffer();
      buffer.writeln('// 自动生成的代码');
      buffer.writeln('class $newClassName extends $className {');

      // 生成构造函数和字段
      final fieldsWithAnnotation = <FieldElement>[];
      print('function: ${element.methods.length}');
      for (var field in element.fields) {
        print('field: ${field.name} ${field.metadata.length}');

        if (field.metadata
            .any((m) => m.element?.name == 'PetrelRegisterField')) {
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
