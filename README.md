# TripMeet

TripMeet es una aplicación móvil desarrollada con **Flutter** que busca transformar la manera de viajar, permitiendo a las personas **descubrir lugares, compartir experiencias y conectar con otros viajeros**.

La aplicación combina el descubrimiento de lugares con una experiencia social, permitiendo crear planes, encontrar personas interesadas en participar y comunicarse dentro de cada actividad.

---

## Tecnologías utilizadas

* **Flutter** — Desarrollo de la aplicación móvil.
* **Dart** — Lenguaje de programación.
* **Firebase Authentication** — Registro e inicio de sesión de usuarios.
* **Cloud Firestore** — Base de datos de la aplicación.
* **Firebase Storage** — Almacenamiento de imágenes y archivos.
* **Google Maps** — Mapas y ubicación de lugares.
* **Node.js / npm** — Herramientas necesarias para Firebase CLI y funcionalidades adicionales.
* **FlutterFire CLI** — Configuración e integración de Flutter con Firebase.

---

# Requisitos

Antes de ejecutar el proyecto debes tener instalado:

### Flutter

Se recomienda utilizar una versión estable de Flutter compatible con el proyecto.

Verifica la instalación:

```powershell
flutter --version
flutter doctor
```

Si `flutter doctor` muestra problemas relacionados con Android, debes solucionarlos antes de ejecutar la aplicación.

### Android Studio

Android Studio es necesario para desarrollar y ejecutar la aplicación en Android.

Debe contar con:

* Android SDK
* Android SDK Command-line Tools
* Android Emulator, si se utilizará un emulador

Puedes verificar la configuración con:

```powershell
flutter doctor
```

### Java

El proyecto utiliza **JDK 17** para el desarrollo Android.

Comprueba que Flutter esté utilizando una versión compatible:

```powershell
flutter doctor -v
```

### Visual Studio Code

Puedes utilizar VS Code como editor.

Se recomienda instalar las extensiones:

* Flutter
* Dart

### Node.js

Node.js es necesario para utilizar Firebase CLI y otras herramientas relacionadas.

Comprueba la instalación:

```powershell
node --version
npm --version
```

### Firebase CLI

Instala Firebase CLI:

```powershell
npm install -g firebase-tools
```

Comprueba la instalación:

```powershell
firebase --version
```

Inicia sesión con la cuenta de Google que tenga acceso al proyecto Firebase:

```powershell
firebase login
```

### FlutterFire CLI

Instala FlutterFire CLI:

```powershell
dart pub global activate flutterfire_cli
```

Comprueba la instalación:

```powershell
flutterfire --version
```

Si Windows indica que `flutterfire` no se reconoce, agrega la siguiente carpeta al `PATH`:

```text
C:\Users\TU_USUARIO\AppData\Local\Pub\Cache\bin
```

---

# Instalación del proyecto

## 1. Clonar el repositorio

Clona el repositorio desde GitHub:

```powershell
git clone URL_DEL_REPOSITORIO
```

Luego entra en la carpeta:

```powershell
cd TripMeet
```

> Reemplaza `URL_DEL_REPOSITORIO` por la URL del repositorio de GitHub.

---

## 2. Obtener las dependencias

Dentro de la carpeta del proyecto ejecuta:

```powershell
flutter pub get
```

Esto instalará automáticamente las dependencias definidas en `pubspec.yaml`.

---

# Configuración de Firebase

El proyecto ya se encuentra configurado para trabajar con Firebase.

La configuración de FlutterFire se encuentra en:

```text
lib/firebase_options.dart
```

Este archivo es generado automáticamente por FlutterFire.

### Importante

Si estás clonando este repositorio para utilizar el proyecto existente, **no ejecutes `flutterfire configure` nuevamente** sin consultar primero con el equipo.

Tampoco es necesario crear otro proyecto de Firebase.

El proyecto utiliza los siguientes servicios:

* Firebase Authentication
* Cloud Firestore
* Firebase Storage

---

# Dependencias principales

Las principales dependencias utilizadas por TripMeet incluyen:

```yaml
firebase_core
firebase_auth
cloud_firestore
firebase_storage
google_maps_flutter
```

Las versiones específicas se encuentran en:

```text
pubspec.yaml
```

No es necesario instalar estas dependencias manualmente. Después de clonar el proyecto simplemente ejecuta:

```powershell
flutter pub get
```

---

# Ejecutar la aplicación

## Ver dispositivos disponibles

Ejecuta:

```powershell
flutter devices
```

Flutter mostrará los dispositivos disponibles, por ejemplo:

```text
Chrome
Edge
Android Emulator
Dispositivo Android
```

---

## Ejecutar en Android

Con un emulador abierto o un dispositivo Android conectado:

```powershell
flutter run
```

También puedes especificar un dispositivo:

```powershell
flutter run -d ID_DEL_DISPOSITIVO
```

---

## Ejecutar en Chrome

Para ejecutar la versión web:

```powershell
flutter run -d chrome
```

---

# Estructura del proyecto

```text
TripMeet/
│
├── android/                 # Configuración específica de Android
├── ios/                     # Configuración específica de iOS
├── web/                     # Configuración para la versión web
├── windows/                 # Configuración para Windows
│
├── lib/                     # Código principal de la aplicación
│   ├── main.dart            # Punto de entrada
│   └── firebase_options.dart# Configuración de Firebase
│
├── test/                    # Pruebas
│
├── pubspec.yaml             # Dependencias y configuración del proyecto
├── pubspec.lock             # Versiones instaladas de dependencias
└── README.md                # Documentación
```

---

# Firebase

## Authentication

Firebase Authentication se utiliza para gestionar las cuentas de los usuarios.

Actualmente se contempla el uso de:

* Correo electrónico
* Contraseña

La configuración se encuentra en Firebase Console → Authentication.

---

## Cloud Firestore

Cloud Firestore funciona como la base de datos principal de TripMeet.

Se utilizará para almacenar información como:

* Usuarios
* Lugares
* Planes
* Participantes
* Mensajes
* Información relacionada con las experiencias

La estructura definitiva de las colecciones puede cambiar a medida que avance el desarrollo.

---

## Firebase Storage

Firebase Storage se utilizará para almacenar archivos e imágenes, por ejemplo:

* Fotos de perfil
* Fotografías de lugares
* Imágenes asociadas a planes
* Otros archivos necesarios para la aplicación

---

# Desarrollo con Git

Si estás trabajando en equipo, se recomienda **no trabajar directamente sobre `main`**.

## Crear una rama

```powershell
git checkout -b nombre-de-la-funcionalidad
```

Ejemplo:

```powershell
git checkout -b login
```

---

## Antes de comenzar a trabajar

Actualiza tu repositorio:

```powershell
git pull
```

Y descarga las dependencias:

```powershell
flutter pub get
```

---

## Guardar cambios

Después de realizar cambios:

```powershell
git add .
```

Luego crea un commit:

```powershell
git commit -m "Descripción de los cambios"
```

Finalmente:

```powershell
git push origin nombre-de-la-funcionalidad
```

---

## Pull Request

Cuando termines una funcionalidad:

1. Haz `push` de tu rama.
2. Abre un Pull Request en GitHub.
3. Explica brevemente los cambios realizados.
4. Espera la revisión.
5. Después de la aprobación, integra los cambios a `main`.

---

# Recomendaciones importantes

Antes de modificar el proyecto:

```powershell
git pull
```

Después de actualizar:

```powershell
flutter pub get
```

Antes de hacer un commit, verifica que la aplicación siga funcionando:

```powershell
flutter run
```

### No hacer

* No crear otro proyecto Flutter dentro de `TripMeet`.
* No crear otro proyecto de Firebase para trabajar con el repositorio existente.
* No modificar manualmente `firebase_options.dart`.
* No eliminar archivos de configuración sin consultar al equipo.
* No subir contraseñas, tokens, claves privadas u otra información sensible.
* No trabajar directamente sobre `main` sin coordinación con el equipo.

---

# Solución de problemas

### Flutter no se reconoce

Comprueba que Flutter esté agregado al `PATH`:

```powershell
flutter --version
```

Si no funciona, revisa la instalación de Flutter.

### Firebase no se reconoce

Comprueba:

```powershell
firebase --version
```

Si no funciona, instala Firebase CLI:

```powershell
npm install -g firebase-tools
```

### FlutterFire no se reconoce

Comprueba:

```powershell
flutterfire --version
```

Si no funciona, asegúrate de tener esta carpeta en el `PATH`:

```text
C:\Users\TU_USUARIO\AppData\Local\Pub\Cache\bin
```

### Problemas con Android

Ejecuta:

```powershell
flutter doctor -v
```

Revisa especialmente:

* Android SDK
* Java
* Android licenses

Para aceptar las licencias:

```powershell
flutter doctor --android-licenses
```

---

# Inicio rápido

Si tu entorno ya está configurado y solo quieres ejecutar TripMeet:

```powershell
git clone URL_DEL_REPOSITORIO
cd TripMeet
flutter pub get
flutter run
```

Para ejecutar en Chrome:

```powershell
flutter run -d chrome
```

---

# Estado del proyecto

TripMeet se encuentra actualmente en desarrollo.

Las funcionalidades y estructura del proyecto pueden cambiar a medida que avance el desarrollo.

---

## Equipo

Proyecto desarrollado como trabajo académico grupal.

**TripMeet — Conectando personas a través de experiencias.**
