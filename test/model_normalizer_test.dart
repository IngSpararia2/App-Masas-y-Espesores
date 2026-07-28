import 'package:flutter_test/flutter_test.dart';
import 'package:masalab_historico/core/model_normalizer.dart';

void main() {
  test('unifica variantes de modelos de compresión', () {
    expect(ModelNormalizer.canonicalize('M12L DIV'), 'M12L-DIV');
    expect(ModelNormalizer.canonicalize('M12L-DIV'), 'M12L-DIV');
    expect(ModelNormalizer.canonicalize('M12L-DIP'), 'M12L-DIV');
    expect(ModelNormalizer.canonicalize('M12LDIV'), 'M12L-DIV');
  });

  test('elimina sufijo de fecha cuando no existe ruta de modelo', () {
    expect(
      ModelNormalizer.chooseFlexureModel(sampleId: 'AH4-1213'),
      'AH4',
    );
    expect(
      ModelNormalizer.chooseFlexureModel(sampleId: 'AR6-ANT'),
      'AR6-ANT',
    );
  });
}
