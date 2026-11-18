# Mi Bolsillo

Aplicación Flutter para registrar ingresos, gastos y presupuestos mensuales en
Android y iOS. Los datos se guardan en una base de datos SQLite local, sin
cuenta ni sincronización. No están cifrados por la aplicación: protege el
dispositivo y ten presente que al desinstalarla puedes perderlos.
Las copias de seguridad del sistema operativo pueden incluir los datos si están
habilitadas en el dispositivo.

## Funciones

- Registro de ingresos y gastos por categoría y fecha.
- Categorías de ingreso: salario, ventas, arriendo, trabajo independiente,
  inversiones, regalos y otros. Las categorías de gasto incluyen arriendo,
  servicios públicos, educación y servicios financieros.
- Las categorías antiguas de gastos «Vivienda» y «Servicios» se actualizan a
  «Arriendo» y «Servicios públicos» en movimientos, presupuestos y recurrencias.
  Los ingresos existentes conservan sus categorías.
- Presupuestos mensuales por categoría y moneda, con avisos dentro de la app
  al llegar al 80 % y al 100 % del límite.
- Resumen mensual con balance y gráfico de gastos por categoría.
- USD y COP se manejan por separado, sin conversiones.
- Interfaz con tema claro u oscuro según la configuración del dispositivo,
  basada en la biblioteca de código abierto
  [FlexColorScheme](https://pub.dev/packages/flex_color_scheme) (licencia BSD-3).
- Ingresos y gastos recurrentes mensuales: al registrar un movimiento, activa
  «Repetir cada mes». Los movimientos pendientes se crean al abrir o retomar
  la app. Si un mes no tiene el día indicado, se usa su último día; el mes
  siguiente conserva el día original. Detener una recurrencia no borra los
  movimientos anteriores.
- Exportación de todos los movimientos como CSV mediante el menú de compartir.
  El CSV no incluye presupuestos ni reglas recurrentes y no se puede importar:
  no es una copia de seguridad completa.

## Ejecutar y probar

Instala Flutter y las herramientas de Android según
[la guía oficial](https://docs.flutter.dev/get-started/install). Para ejecutar
en iOS se necesita macOS con Xcode y la configuración de firma correspondiente.
Desde esta carpeta:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

En este equipo, si Flutter aún no está en el PATH, sustituye `flutter` por
`& "$env:USERPROFILE\develop\flutter\bin\flutter.bat"`. Para Android, si Java
no está configurado, establece en la misma terminal:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

Para generar un APK de depuración compatible con teléfonos ARM y emuladores
x86_64, especifica las plataformas al compilar:

```powershell
flutter build apk --debug --target-platform android-arm,android-arm64,android-x64
```

El APK se guarda en `build\app\outputs\flutter-apk\app-debug.apk`. Vuelve a
generarlo antes de compartirlo: `flutter run` puede sobrescribirlo con una
compilación específica del dispositivo utilizado.

El ícono fuente está en `assets\icon\app_icon.png`. Para regenerar los íconos
de Android y iOS después de modificarlo, ejecuta `dart run flutter_launcher_icons`.

El proyecto usa los identificadores y la firma de depuración generados por
Flutter. Antes de publicarlo hay que definir identificadores propios, firma de
producción y cumplir los requisitos de las tiendas.
