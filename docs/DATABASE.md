# Base de datos y actualización incremental

## Archivo local

SQLite se guarda en el directorio de soporte privado de la aplicación con el nombre:

`masalab_historico.sqlite`

## Tablas

### `measurements`

Guarda un registro normalizado por espécimen. Los campos principales son:

- tipo de ensayo;
- modelo canónico y modelo original;
- fecha, informe/número de ensayo, ID de muestra e ítem;
- masas seca, saturada, inmersa y natural;
- absorción y densidad recalculadas;
- espesor, ancho y longitud;
- bandera de validez y observaciones de calidad.

### `import_batches`

Registra cada archivo importado, su hash SHA-256 y los conteos de nuevos, actualizados, sin cambios y rechazados.

## Prevención de duplicados

La clave de deduplicación se construye con:

`tipo + modelo + fecha + informe/ensayo + ID muestra + ítem + número de espécimen`

Cuando esos identificadores faltan se añade la ruta relativa y la fila como respaldo. La clave se guarda como SHA-256.

En una importación posterior:

1. Si la clave no existe, se inserta.
2. Si existe y el contenido cambió, se actualiza.
3. Si existe y el contenido es idéntico, se cuenta como “sin cambios”.
4. Si el archivo completo tiene el mismo hash que uno previo, no se procesa nuevamente.

## Normalización de modelos

Se eliminan diferencias de mayúsculas, espacios y separadores. También se unifican alias frecuentes, por ejemplo:

- `M12L DIV`
- `M12L-DIV`
- `M12L-DIP`

Todos se almacenan como `M12L-DIV`.
