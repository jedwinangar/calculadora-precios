# Calculadora de Precios

Primera versión multiplataforma para Android y Windows.

## Fórmula implementada: Proveedor 1

P = 1.9604 × (C × 1.16 × 0.65)^0.95

C = costo del producto
P = precio al público

Ejemplo:
C = 1000
P = 1061.3227...
La aplicación muestra $1,061.32.

## Proveedores pendientes

Proveedor 2, 3 y 4 están preparados en el selector, pero no calculan hasta recibir sus fórmulas.

## Compilar

Requiere Flutter instalado.

Android:
flutter build apk --release

Windows:
flutter build windows --release
