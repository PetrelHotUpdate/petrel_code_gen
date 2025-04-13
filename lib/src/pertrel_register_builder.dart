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

      final methodParamStringList = <String>[];
      final registerBuffer = StringBuffer();
      final methodBuffer = StringBuffer();

      // 生成构造函数和字段
      final methodsWithAnnotation = <MethodElement>[];
      for (var method in element.methods) {
        if (!method.metadata
            .any((e) => e.element?.displayName == 'PetrelRegisterMethod')) {
          continue;
        }
        methodsWithAnnotation.add(method);
        final methodType = method.returnType.getDisplayString();
        final methodName = method.name;
        final methodParams = method.parameters;
        methodParamStringList
            .add('required $methodType Function() $methodName,');
        registerBuffer.writeln('''
register('$methodName', (data) {
      return $methodName();
    });
''');

        methodBuffer.writeln('''
@override
$methodType $methodName(${methodParams.map((e) => e.type.getDisplayString()).join(', ')}) {
  return nativeChannelEngine.call(CallMessageChannel(
    '$methodName',
    libraryName: libraryName,
    className: className,
    arguments: {},
  ));
}
''');
      }

      // 生成构造函数
      final paramList = methodParamStringList.join('');
      String initMethod = '''
$newClassName({$paramList}) {
  ${registerBuffer.toString()}
}
''';
      final codeBuffer = StringBuffer();
      codeBuffer.write('''
part of "$fileName";

class $newClassName extends $className {
  $initMethod

  ${methodBuffer.toString()}
}
''');
      return codeBuffer.toString();
    }
    return null;
  }

  String _generateMethodParams(List<ParameterElement> params) {}
}
