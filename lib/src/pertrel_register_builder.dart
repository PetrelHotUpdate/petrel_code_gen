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
    if (element is! ClassElement) {
      throw Exception('PetrelRegisterClass must be used on a class');
    }
    final className = element.name;
    final newClassName = className.replaceFirst('_', '');

    final codeBuffer = StringBuffer();
    final constructorParamsBuffer = StringBuffer();
    final methodBuffer = StringBuffer();
    final registerBuffer = StringBuffer();

    // 生成构造函数和字段
    final methodsWithAnnotation = element.methods.where((method) {
      return method.metadata.any(
        (e) => e.element?.displayName == 'PetrelRegisterMethod',
      );
    });

    for (final method in methodsWithAnnotation) {
      final methodType = method.returnType.getDisplayString();
      final methodName = method.name;
      final methodParams = method.parameters;

      constructorParamsBuffer.writeln('''
        required $methodType Function(${_generateHandlerParams(methodParams)}) $methodName,
      ''');
      registerBuffer.writeln(_generateRegisterCode(methodName, methodParams));
      methodBuffer.writeln(_generateMethodCode(method));
    }

    codeBuffer.writeln('''
part of "$fileName";

class $newClassName extends $className {
  $newClassName({
    ${constructorParamsBuffer.toString()}
  }) {
    ${registerBuffer.toString()}
  }

  ${methodBuffer.toString()}
}
''');
    return codeBuffer.toString();
  }

  String _generateHandlerParams(List<ParameterElement> params) {
    StringBuffer buffer = StringBuffer();
    List<String> positionalParams = [];
    List<String> optionalParams = [];
    List<String> optionalNamedParams = [];
    for (final param in params) {
      final displayString = param
          .getDisplayString()
          .replaceFirst('[', '')
          .replaceFirst(']', '')
          .replaceFirst('{', '')
          .replaceFirst('}', '')
          .replaceFirst('required', '')
          .split('=')
          .first;
      final runtimeType = param.runtimeType.toString();
      if (runtimeType == 'DefaultParameterElementImpl') {
        if (param.isNamed) {
          optionalNamedParams.add(displayString);
        } else {
          optionalParams.add(displayString);
        }
      } else {
        positionalParams.add(displayString);
      }
    }
    if (positionalParams.isNotEmpty) {
      String positionalParamsString = positionalParams.join(', ');
      buffer.write(positionalParamsString);
      if (optionalParams.isNotEmpty || optionalNamedParams.isNotEmpty) {
        buffer.write(',');
      }
    }
    if (optionalParams.isNotEmpty) {
      String optionalParamsString = optionalParams.join(', ');
      buffer.write('[$optionalParamsString]');
    }
    if (optionalNamedParams.isNotEmpty) {
      String optionalNamedParamsString = optionalNamedParams.join(', ');
      buffer.write('{$optionalNamedParamsString}');
    }

    return buffer.toString();
  }

  String _generateRegisterCode(
      String methodName, List<ParameterElement> params) {
    StringBuffer buffer = StringBuffer();
    for (final param in params) {
      if (param.isNamed) {
        buffer.write("${param.name}: channelData.data['${param.name}'],");
      } else {
        buffer.write("channelData.data['${param.name}'],");
      }
    }
    return '''
register('$methodName', (channelData) {
      return $methodName(${buffer.toString()});
});
    ''';
  }

  String _generateMethodCode(MethodElement method) {
    final methodName = method.name;
    final params = method.parameters;
    final displayString = method.getDisplayString();
    print('displayString: $displayString');
    return '''
  @override
  $displayString {
    return call('$methodName', {
      ${params.map((e) => "'${e.name}': ${e.name},").join('')}
    });
  }
''';
  }
}
