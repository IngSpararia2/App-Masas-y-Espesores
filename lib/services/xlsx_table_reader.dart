import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Resultado mínimo de lectura de una hoja XLSX.
///
/// La aplicación solo necesita valores tabulares; por eso este lector evita
/// cargar estilos, imágenes y otros componentes que no intervienen en la
/// importación de los históricos.
class XlsxTableData {
  const XlsxTableData({
    required this.sheetName,
    required this.rows,
    required this.errorCellCount,
    required this.ignoredCellCount,
  });

  final String sheetName;
  final List<List<Object?>> rows;
  final int errorCellCount;
  final int ignoredCellCount;
}

class XlsxTableReader {
  const XlsxTableReader._();

  static XlsxTableData read(
    Uint8List bytes, {
    String preferredSheet = 'Resumen',
  }) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FormatException(
        'El archivo no es un XLSX válido o está dañado: $error',
      );
    }

    final workbookFile = _findFile(archive, 'xl/workbook.xml');
    if (workbookFile == null) {
      throw const FormatException(
        'El archivo XLSX no contiene xl/workbook.xml.',
      );
    }

    final workbook = _parseXml(workbookFile, 'xl/workbook.xml');
    final relationships = _readWorkbookRelationships(archive);
    final sheets = workbook.findAllElements('sheet').toList(growable: false);
    if (sheets.isEmpty) {
      throw const FormatException('El libro no contiene hojas de cálculo.');
    }

    XmlElement selectedSheet = sheets.first;
    for (final sheet in sheets) {
      final name = sheet.getAttribute('name')?.trim();
      if (name != null &&
          name.toLowerCase() == preferredSheet.trim().toLowerCase()) {
        selectedSheet = sheet;
        break;
      }
    }

    final sheetName = selectedSheet.getAttribute('name')?.trim();
    if (sheetName == null || sheetName.isEmpty) {
      throw const FormatException('La hoja seleccionada no tiene nombre.');
    }

    final relationshipId = _attributeByLocalName(selectedSheet, 'id');
    String? worksheetPath;
    if (relationshipId != null) {
      worksheetPath = relationships[relationshipId];
    }
    worksheetPath ??= _firstWorksheetPath(archive);
    if (worksheetPath == null) {
      throw const FormatException(
        'No se encontró el archivo XML de la hoja seleccionada.',
      );
    }

    final worksheetFile = _findFile(archive, worksheetPath);
    if (worksheetFile == null) {
      throw FormatException(
        'No se encontró la hoja interna "$worksheetPath".',
      );
    }

    final sharedStrings = _readSharedStrings(archive);
    final worksheet = _parseXml(worksheetFile, worksheetPath);
    final counters = _CellCounters();
    final rows = _readRows(
      worksheet,
      sharedStrings: sharedStrings,
      counters: counters,
    );

    return XlsxTableData(
      sheetName: sheetName,
      rows: rows,
      errorCellCount: counters.errorCells,
      ignoredCellCount: counters.ignoredCells,
    );
  }

  static Map<String, String> _readWorkbookRelationships(Archive archive) {
    final file = _findFile(archive, 'xl/_rels/workbook.xml.rels');
    if (file == null) return const <String, String>{};

    final document = _parseXml(file, 'xl/_rels/workbook.xml.rels');
    final output = <String, String>{};
    for (final relationship in document.findAllElements('Relationship')) {
      final id = relationship.getAttribute('Id')?.trim();
      final target = relationship.getAttribute('Target')?.trim();
      if (id == null || id.isEmpty || target == null || target.isEmpty) {
        continue;
      }
      output[id] = _resolveWorkbookTarget(target);
    }
    return output;
  }

  static String _resolveWorkbookTarget(String target) {
    var clean = target.replaceAll('\\', '/').trim();
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('xl/')) {
      return p.posix.normalize(clean);
    }
    return p.posix.normalize(p.posix.join('xl', clean));
  }

  static String? _firstWorksheetPath(Archive archive) {
    final candidates = archive.files
        .where((file) =>
            file.isFile &&
            file.name.replaceAll('\\', '/').toLowerCase().startsWith(
                  'xl/worksheets/',
                ) &&
            file.name.toLowerCase().endsWith('.xml'))
        .map((file) => file.name.replaceAll('\\', '/'))
        .toList(growable: false)
      ..sort();
    return candidates.isEmpty ? null : candidates.first;
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = _findFile(archive, 'xl/sharedStrings.xml');
    if (file == null) return const <String>[];

    final document = _parseXml(file, 'xl/sharedStrings.xml');
    return document.findAllElements('si').map((item) {
      return item.findAllElements('t').map((text) => text.innerText).join();
    }).toList(growable: false);
  }

  static List<List<Object?>> _readRows(
    XmlDocument worksheet, {
    required List<String> sharedStrings,
    required _CellCounters counters,
  }) {
    final output = <List<Object?>>[];
    final sheetDataElements = worksheet.findAllElements('sheetData');
    if (sheetDataElements.isEmpty) return output;
    final sheetData = sheetDataElements.first;

    var fallbackRowNumber = 1;
    for (final rowElement in sheetData.findElements('row')) {
      final rowNumber =
          int.tryParse(rowElement.getAttribute('r') ?? '') ?? fallbackRowNumber;
      fallbackRowNumber = rowNumber + 1;
      if (rowNumber <= 0) {
        counters.ignoredCells += rowElement.findElements('c').length;
        continue;
      }

      while (output.length < rowNumber) {
        output.add(<Object?>[]);
      }
      final row = output[rowNumber - 1];

      for (final cell in rowElement.findElements('c')) {
        final reference = cell.getAttribute('r');
        final columnIndex = _columnIndex(reference);
        if (columnIndex == null) {
          counters.ignoredCells++;
          continue;
        }
        while (row.length <= columnIndex) {
          row.add(null);
        }
        row[columnIndex] = _readCellValue(
          cell,
          sharedStrings: sharedStrings,
          counters: counters,
        );
      }
    }
    return output;
  }

  static Object? _readCellValue(
    XmlElement cell, {
    required List<String> sharedStrings,
    required _CellCounters counters,
  }) {
    final type = cell.getAttribute('t')?.trim();

    try {
      switch (type) {
        case 'inlineStr':
          return cell.findAllElements('t').map((node) => node.innerText).join();
        case 's':
          final index = int.tryParse(_firstValue(cell) ?? '');
          if (index == null || index < 0 || index >= sharedStrings.length) {
            counters.ignoredCells++;
            return null;
          }
          return sharedStrings[index];
        case 'b':
          return _firstValue(cell) == '1';
        case 'e':
          // #DIV/0!, #VALUE!, #N/A, etc. No son datos físicos utilizables.
          counters.errorCells++;
          return null;
        case 'str':
          return _firstValue(cell);
        case 'd':
          final raw = _firstValue(cell);
          return raw == null ? null : DateTime.tryParse(raw) ?? raw;
        default:
          final raw = _firstValue(cell);
          if (raw == null || raw.trim().isEmpty) return null;
          return _parseNumericOrText(raw);
      }
    } catch (_) {
      counters.ignoredCells++;
      return null;
    }
  }

  static String? _firstValue(XmlElement cell) {
    final values = cell.findElements('v');
    if (values.isEmpty) return null;
    return values.first.innerText.trim();
  }

  static Object _parseNumericOrText(String raw) {
    final text = raw.trim();
    final integer = int.tryParse(text);
    if (integer != null) return integer;
    final decimal = double.tryParse(text);
    if (decimal != null) return decimal;
    return text;
  }

  static int? _columnIndex(String? reference) {
    if (reference == null || reference.isEmpty) return null;
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(reference.trim());
    final letters = match?.group(1);
    if (letters == null || letters.isEmpty) return null;

    var result = 0;
    for (final unit in letters.toUpperCase().codeUnits) {
      if (unit < 65 || unit > 90) return null;
      result = result * 26 + (unit - 64);
    }
    return result - 1;
  }

  static ArchiveFile? _findFile(Archive archive, String expectedPath) {
    final normalized = expectedPath.replaceAll('\\', '/').toLowerCase();
    for (final file in archive.files) {
      if (file.isFile &&
          file.name.replaceAll('\\', '/').toLowerCase() == normalized) {
        return file;
      }
    }
    return null;
  }

  static XmlDocument _parseXml(ArchiveFile file, String logicalName) {
    try {
      file.decompress();
      final content = file.content;
      late final List<int> bytes;
      if (content is Uint8List) {
        bytes = content;
      } else if (content is List<int>) {
        bytes = content;
      } else {
        throw FormatException(
          'Contenido interno no compatible en $logicalName.',
        );
      }
      return XmlDocument.parse(utf8.decode(bytes));
    } catch (error) {
      if (error is FormatException) rethrow;
      throw FormatException('No se pudo leer $logicalName: $error');
    }
  }

  static String? _attributeByLocalName(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value.trim();
    }
    return null;
  }
}

class _CellCounters {
  int errorCells = 0;
  int ignoredCells = 0;
}
