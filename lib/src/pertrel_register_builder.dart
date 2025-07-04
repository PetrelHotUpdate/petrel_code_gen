// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
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
    StringBuffer defaultImplBuffer = StringBuffer();

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
      if (!methodName.startsWith('\$')) {
        throw Exception('Method name $methodName must start with \$');
      }
      final methodParams = method.parameters;
      bool isOptionalReturnType = false;
      if (method.returnType is InterfaceType) {
        final typeArgumentFirst =
            (method.returnType as InterfaceType).typeArguments.first;
        final nullabilitySuffix = typeArgumentFirst.nullabilitySuffix;
        if (nullabilitySuffix == NullabilitySuffix.question) {
          isOptionalReturnType = true;
        }
      }

      constructorParamsBuffer.writeln('''
$methodType Function(${_generateHandlerParams(methodParams)})? $methodName,
      ''');
      registerBuffer.writeln(_generateRegisterCode(
        methodName,
        methodParams,
        isOptionalReturnType,
      ));
      methodBuffer.writeln(_generateMethodCode(method));
      defaultImplBuffer.writeln('''
@override
${method.getDisplayString()} async => throw UnimplementedError();
''');
    }

    codeBuffer.writeln('''
part of "$fileName";

abstract class \$$newClassName extends $className {
  \$$newClassName() {
    ${registerBuffer.toString()}
  }

  ${methodBuffer.toString()}
}
class Default${newClassName}Impl extends \$$newClassName {
  ${defaultImplBuffer.toString()}
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
          if (param.isRequired) {
            optionalNamedParams.add('required $displayString');
          } else {
            optionalNamedParams.add(displayString);
          }
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
    String methodName,
    List<ParameterElement> params,
    bool isOptionalReturnType,
  ) {
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
          paramType.isDartCoreInt ||
          paramType.isDartCoreMap ||
          paramType.isDartCoreList) {
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
    String toJsonCode =
        !isOptionalReturnType ? 'e.toJson()' : 'e?.toJson() ?? {}';
    return '''
register('\\$methodName', (channelData) {
    return _$methodName(${buffer.toString()}).then((e) => $toJsonCode);
});
    ''';
  }

  String _generateMethodCode(MethodElement method) {
    final methodName = method.name;
    final params = method.parameters;
    final displayString =
        method.getDisplayString().replaceFirst(methodName, '_$methodName');
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
  $displayString {
    return call('\\$methodName', {
      ${params.map((e) {
      /// 是否是注解对象
      final isAnnotation = e.metadata.any((e) {
        final value = e.computeConstantValue();
        if (value == null) return false;
        final reader = ConstantReader(value);
        final typeName = reader.objectValue.type?.getDisplayString();
        return typeName == 'PetrelRegisterMethodParam';
      });
      if (isAnnotation) {
        return "'${e.name}': ${e.name}.toJson(),";
      } else {
        return "'${e.name}': ${e.name},";
      }
    }).join('')}
    }).then((e) => $converterCode);
  }
''';
  }
}
