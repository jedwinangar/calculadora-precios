import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const CalculadoraPreciosApp());
}

class CalculadoraPreciosApp extends StatelessWidget {
  const CalculadoraPreciosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora de Precios',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const CalculadoraPage(),
    );
  }
}

class CalculadoraPage extends StatefulWidget {
  const CalculadoraPage({super.key});

  @override
  State<CalculadoraPage> createState() => _CalculadoraPageState();
}

class _CalculadoraPageState extends State<CalculadoraPage> {
  final TextEditingController costoController =
      TextEditingController();

  String proveedor = 'Proveedor 1';
  double? precio;
  String? error;

  double calcularProveedor1(double costo) {
    return 1.9604 *
        math.pow(
          costo * 1.16 * 0.65,
          0.95,
        );
  }

  void calcular() {
    final texto = costoController.text
        .trim()
        .replaceAll(',', '.');

    final costo = double.tryParse(texto);

    setState(() {
      error = null;
      precio = null;

      if (costo == null || costo <= 0) {
        error =
            'Introduce un costo válido mayor que cero.';
        return;
      }

      if (proveedor == 'Proveedor 1') {
        precio = calcularProveedor1(costo);
      } else {
        error =
            'La fórmula de este proveedor está pendiente.';
      }
    });
  }

  void limpiar() {
    setState(() {
      costoController.clear();
      precio = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final precioTexto = precio == null
        ? '—'
        : '\$${precio!.toStringAsFixed(2)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calculadora de Precios',
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'CALCULADORA DE PRECIOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 28),

                DropdownButtonFormField<String>(
                  value: proveedor,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Proveedor 1',
                      child: Text('Proveedor 1'),
                    ),
                    DropdownMenuItem(
                      value: 'Proveedor 2',
                      child: Text(
                        'Proveedor 2 — pendiente',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Proveedor 3',
                      child: Text(
                        'Proveedor 3 — pendiente',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Proveedor 4',
                      child: Text(
                        'Proveedor 4 — pendiente',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      proveedor = value;
                      precio = null;
                      error = null;
                    });
                  },
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: costoController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onSubmitted: (_) => calcular(),
                  decoration: const InputDecoration(
                    labelText: 'Costo del producto',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    hintText: 'Ej. 1000.00',
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: calcular,
                  icon: const Icon(Icons.calculate),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: Text(
                      'CALCULAR',
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: limpiar,
                  child: const Text('Limpiar'),
                ),

                const SizedBox(height: 30),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'PRECIO AL PÚBLICO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 10),

                        FittedBox(
                          child: Text(
                            precioTexto,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Proveedor 1: '
                  'P = 1.9604 × '
                  '(C × 1.16 × 0.65)^0.95',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
