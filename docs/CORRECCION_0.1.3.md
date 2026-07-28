# Corrección 0.1.3 — importación de XLSX con celdas de error

## Síntoma

Al seleccionar uno de los históricos, la aplicación mostraba:

```text
Null check operator used on a null value
```

El fallo ocurría antes de insertar registros en SQLite.

## Causa comprobada

El lector `excel 4.0.6` podía fallar durante `Excel.decodeBytes` al encontrar determinadas estructuras internas del XLSX. En el archivo `Resumen_Flexotraccion.xlsx` analizado existen siete celdas calculadas con errores de Excel (`#DIV/0!` y `#VALUE!`). Todas están en columnas de densidad o absorción de las muestras 4 y 5; las columnas de masas no están afectadas.

## Solución

La versión 0.1.3 elimina la dependencia `excel` y añade un lector tabular XLSX específico para esta aplicación. El lector:

- abre el XLSX como contenedor ZIP;
- localiza la hoja `Resumen` mediante `workbook.xml` y sus relaciones;
- interpreta números, textos compartidos, textos en línea, booleanos y fechas;
- convierte las celdas de error en valores nulos controlados;
- continúa importando todos los especímenes que sí tienen masas válidas;
- informa cuántas celdas de error fueron omitidas.

La absorción y la densidad se siguen recalculando a partir de masa saturada, masa inmersa y masa seca, de modo que omitir las siete celdas calculadas defectuosas no elimina información física necesaria.

## Aplicación del parche

1. Cierre la aplicación.
2. Extraiga el ZIP del parche sobre la carpeta raíz del proyecto y acepte reemplazar archivos.
3. Ejecute `ACTUALIZAR_IMPORTADOR.bat`.
4. Vuelva a importar el histórico.

No es necesario borrar la base de datos: el intento fallido no alcanzó a registrar un lote de importación.
