# Cómo generar el APK y Windows

1. Crea una cuenta en GitHub si no tienes una.
2. Crea un repositorio nuevo, por ejemplo `calculadora-precios`.
3. Sube todos los archivos de esta carpeta al repositorio.
4. En GitHub entra a **Actions**.
5. Selecciona el workflow **Build Calculadora de Precios**.
6. Pulsa **Run workflow** si quieres lanzar la compilación manualmente.
7. Cuando termine, entra a la ejecución y busca **Artifacts**.
8. Descarga:
   - `calculadora-precios-android` para obtener el APK.
   - `calculadora-precios-windows` para obtener el ZIP de Windows.

Nota: Windows se entrega como ZIP porque una aplicación Flutter de escritorio necesita sus DLL y archivos de soporte además del ejecutable.
