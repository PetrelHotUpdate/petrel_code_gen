// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:path/path.dart';
import 'package:petrel_register_code_gen_annotation/petrel_register_code_gen_annotation.dart';
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
    List<MethodElement> methodsWithAnnotation = element.methods.where((method) {
      return method.metadata.any(
        (metadata) {
          final value = metadata.computeConstantValue();
          if (value == null) return false;
          final reader = ConstantReader(value);
          final typeName = reader.objectValue.type?.getDisplayString();
          print('typeName: $typeName');
          return typeName == 'PetrelRegisterMethod';
        },
      );
    }).toList();

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
      final paramType = param.type;
      final paramAnnotationReader = param.metadata
          .map((e) {
            final value = e.computeConstantValue();
            if (value == null) return null;
            final reader = ConstantReader(value);
            final typeName = reader.objectValue.type?.getDisplayString();
            if (typeName != 'PetrelRegisterMethodParam') {
              return null;
            }
            return reader;
          })
          .whereType<ConstantReader>()
          .firstOrNull;
      late String readCode;
      if (paramType.isDartCoreBool ||
          paramType.isDartCoreString ||
          paramType.isDartCoreDouble ||
          paramType.isDartCoreInt) {
        readCode = "channelData.data['${param.name}']";
      } else if (paramAnnotationReader != null) {
        final value = "channelData.data['${param.name}']";
        readCode = '${param.type.getDisplayString()}.fromJson($value)';
      } else {
        throw Exception(
            'Unsupported type: $paramType in $methodName 请使用@PetrelRegisterMethodParam注解支持');
      }
      if (param.isNamed) {
        buffer.write("${param.name}: $readCode,");
      } else {
        buffer.write('$readCode,');
      }
    }
    return '''
register('$methodName', (channelData) {
      return $methodName(${buffer.toString()}).then((e) => e.toJson());
});
    ''';
  }

  String _generateMethodCode(MethodElement method) {
    final methodName = method.name;
    final params = method.parameters;
    final displayString = method.getDisplayString();
    final typeArgument = (method.returnType as InterfaceType)
        .typeArguments
        .first
        .getDisplayString();
    String converterCode = '$typeArgument.fromJson(e)';
    final customConverter = method.metadata
        .map((metadata) {
          final value = metadata.computeConstantValue();
          if (value == null) return null;
          final reader = ConstantReader(value);
          final typeName = reader.objectValue.type?.getDisplayString();
          if (typeName != 'PetrelRegisterMethod') {
            return null;
          }
          return reader.read('customConverter').stringValue;
        })
        .whereType<String>()
        .firstOrNull;
    if (customConverter != null && customConverter.isNotEmpty) {
      converterCode = customConverter;
    }

    return '''
  @override
  $displayString {
    return call('$methodName', {
      ${params.map((e) => "'${e.name}': ${e.name},").join('')}
    }).then((e) => $converterCode);
  }
''';
  }
}
