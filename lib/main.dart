import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CalculadoraPreciosApp());

class CalculadoraPreciosApp extends StatelessWidget {
  const CalculadoraPreciosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Calculadora de Precios',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF397A3D)),
      scaffoldBackgroundColor: const Color(0xFFF9FBF5),
    ),
    home: const CalculadoraPage(),
  );
}

class Proveedor {
  String nombre;
  String formula;
  Proveedor({required this.nombre, required this.formula});
}

class CalculadoraPage extends StatefulWidget {
  const CalculadoraPage({super.key});
  @override
  State<CalculadoraPage> createState() => _CalculadoraPageState();
}

class _CalculadoraPageState extends State<CalculadoraPage> {
  final costoController = TextEditingController();
  List<Proveedor> proveedores = [
    Proveedor(nombre: 'RADEC', formula: '1.9604*(C*1.16*0.65)^0.95'),
    Proveedor(nombre: 'GRIMEX', formula: '1.9604*(C*0.62)^0.95'),
  ];
  int seleccionado = 0;
  double? precioPublico;
  double? pagoEfectivo;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    costoController.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    final nombres = p.getStringList('proveedores_nombres');
    final formulas = p.getStringList('proveedores_formulas');
    if (nombres != null && formulas != null &&
        nombres.length == formulas.length && nombres.isNotEmpty) {
      proveedores = List.generate(nombres.length, (i) =>
        Proveedor(nombre: nombres[i], formula: formulas[i]));
    }
    if (mounted) setState(() => cargando = false);
  }

  Future<void> guardar() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('proveedores_nombres',
        proveedores.map((e) => e.nombre).toList());
    await p.setStringList('proveedores_formulas',
        proveedores.map((e) => e.formula).toList());
  }

  void calcular() {
    final costo = double.tryParse(
      costoController.text.trim().replaceAll(',', '.'),
    );
    if (costo == null || costo < 0) {
      mensaje('Introduce un costo válido.');
      return;
    }
    try {
      final p = EvaluadorFormula.evaluar(
        proveedores[seleccionado].formula, costo);
      if (!p.isFinite || p < 0) throw const FormatException();
      setState(() {
        precioPublico = p;
        pagoEfectivo = p / 1.035;
      });
    } catch (_) {
      mensaje('No se pudo calcular. Revisa la fórmula.');
    }
  }

  void mensaje(String s) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(s)));

  Future<void> configuracion() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ConfiguracionPage(
        proveedores: proveedores,
        onGuardar: (lista) async {
          proveedores = lista.isEmpty
              ? [Proveedor(nombre: 'Proveedor 1', formula: 'C')]
              : lista;
          if (seleccionado >= proveedores.length) seleccionado = 0;
          await guardar();
          if (mounted) setState(() {
            precioPublico = null;
            pagoEfectivo = null;
          });
        },
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final prov = proveedores[seleccionado];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Precios'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [IconButton(
          tooltip: 'Configuración',
          icon: const Icon(Icons.settings),
          onPressed: configuracion,
        )],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 15),
              const Text('CALCULADORA DE PRECIOS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold)),
              const SizedBox(height: 35),
              DropdownButtonFormField<int>(
                value: seleccionado,
                decoration: const InputDecoration(
                  labelText: 'Proveedor', border: OutlineInputBorder()),
                items: List.generate(proveedores.length, (i) =>
                  DropdownMenuItem(value: i, child: Text(proveedores[i].nombre))),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    seleccionado = v;
                    precioPublico = null;
                    pagoEfectivo = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: costoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: const InputDecoration(
                  labelText: 'Costo del producto',
                  prefixText: r'$ ',
                  hintText: 'Ej. 1000.00',
                  border: OutlineInputBorder()),
                onSubmitted: (_) => calcular(),
              ),
              const SizedBox(height: 22),
              SizedBox(height: 56, child: FilledButton.icon(
                onPressed: calcular,
                icon: const Icon(Icons.calculate),
                label: const Text('CALCULAR',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 12),
              SizedBox(height: 52, child: OutlinedButton(
                onPressed: () {
                  costoController.clear();
                  setState(() {
                    precioPublico = null;
                    pagoEfectivo = null;
                  });
                },
                child: const Text('Limpiar', style: TextStyle(fontSize: 17)),
              )),
              const SizedBox(height: 28),
              ResultadoCard('PRECIO AL PÚBLICO', precioPublico, 40),
              const SizedBox(height: 14),
              ResultadoCard('PAGO EN EFECTIVO', pagoEfectivo, 32),
              const SizedBox(height: 14),
              const Card(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(children: [
                  Text('PRECIO MAYORISTA',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('Pendiente de definir',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ]),
              )),
              const SizedBox(height: 24),
              Text('${prov.nombre}: ${prov.formula}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Pago en efectivo = Precio al público / 1.035',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultadoCard extends StatelessWidget {
  final String titulo;
  final double? valor;
  final double tamano;
  const ResultadoCard(this.titulo, this.valor, this.tamano, {super.key});
  @override
  Widget build(BuildContext context) => Card(
    elevation: titulo == 'PRECIO AL PÚBLICO' ? 3 : 1,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(children: [
        Text(titulo, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FittedBox(child: Text(
          valor == null ? '—' : '\$${valor!.toStringAsFixed(2)}',
          style: TextStyle(fontSize: tamano, fontWeight: FontWeight.bold))),
      ]),
    ),
  );
}

class ConfiguracionPage extends StatefulWidget {
  final List<Proveedor> proveedores;
  final Future<void> Function(List<Proveedor>) onGuardar;
  const ConfiguracionPage({super.key, required this.proveedores, required this.onGuardar});
  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  late List<Proveedor> proveedores;

  @override
  void initState() {
    super.initState();
    proveedores = widget.proveedores.map((p) =>
      Proveedor(nombre: p.nombre, formula: p.formula)).toList();
  }

  Future<void> editar(int i) async {
    final n = TextEditingController(text: proveedores[i].nombre);
    final f = TextEditingController(text: proveedores[i].formula);
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Editar ${proveedores[i].nombre}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: n, decoration: const InputDecoration(
            labelText: 'Nombre del proveedor', border: OutlineInputBorder())),
          const SizedBox(height: 18),
          TextField(controller: f, maxLines: 3, decoration: const InputDecoration(
            labelText: 'Fórmula del precio al público',
            hintText: 'Ej. 1.9604*(C*1.16*0.65)^0.95',
            border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Text('Usa C para representar el costo. Operadores: +  -  *  /  ^
También puedes usar × y ÷.',
            style: TextStyle(fontSize: 12)),
        ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () {
          if (n.text.trim().isEmpty || f.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nombre y fórmula son obligatorios.')));
            return;
          }
          setState(() {
            proveedores[i].nombre = n.text.trim();
            proveedores[i].formula = f.text.trim();
          });
          Navigator.pop(ctx);
        }, child: const Text('Guardar')),
      ],
    ));
    n.dispose();
    f.dispose();
  }

  Future<void> agregar() async {
    final n = TextEditingController();
    final f = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Nuevo proveedor'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: n, decoration: const InputDecoration(
            labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 18),
          TextField(controller: f, maxLines: 3, decoration: const InputDecoration(
            labelText: 'Fórmula', hintText: 'Ej. 1.9604*(C*0.62)^0.95',
            border: OutlineInputBorder())),
        ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () {
          if (n.text.trim().isEmpty || f.text.trim().isEmpty) return;
          setState(() => proveedores.add(
            Proveedor(nombre: n.text.trim(), formula: f.text.trim())));
          Navigator.pop(ctx);
        }, child: const Text('Agregar')),
      ],
    ));
    n.dispose();
    f.dispose();
  }

  Future<void> eliminar(int i) async {
    if (proveedores.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe existir al menos un proveedor.')));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar proveedor'),
      content: Text('¿Deseas eliminar "${proveedores[i].nombre}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
      ],
    ));
    if (ok == true) setState(() => proveedores.removeAt(i));
  }

  Future<void> guardarTodo() async {
    await widget.onGuardar(proveedores);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada correctamente.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configuración')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('PROVEEDORES',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Puedes cambiar nombres y fórmulas, agregar o eliminar proveedores. Los cambios se guardan en este dispositivo.'),
        const SizedBox(height: 20),
        ...List.generate(proveedores.length, (i) {
          final p = proveedores[i];
          return Card(margin: const EdgeInsets.only(bottom: 14), child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Text(p.formula)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) { if (v == 'editar') editar(i); else eliminar(i); },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ));
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: agregar, icon: const Icon(Icons.add),
          label: const Text('Agregar proveedor')),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: guardarTodo, icon: const Icon(Icons.save),
          label: const Text('Guardar configuración')),
        const SizedBox(height: 25),
        const Card(child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pago en efectivo', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5), Text('Se calcula automáticamente como: P / 1.035'),
            SizedBox(height: 15),
            Text('Precio mayorista', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5), Text('Pendiente de definir. El espacio ya está preparado.'),
          ]),
        )),
      ],
    )),
  );
}

class EvaluadorFormula {
  static double evaluar(String formula, double costo) {
    final e = formula.replaceAll('×', '*').replaceAll('÷', '/')
      .replaceAll(' ', '').replaceAll(',', '.').replaceAll('C', costo.toString());
    final p = _Parser(e);
    final r = p.parse();
    if (!r.isFinite) throw const FormatException();
    return r;
  }
}

class _Parser {
  final String text;
  int position = 0;
  _Parser(this.text);

  double parse() {
    final v = _addition();
    if (position != text.length) throw const FormatException('Fórmula inválida.');
    return v;
  }

  double _addition() {
    double v = _multiplication();
    while (position < text.length) {
      final c = text[position];
      if (c == '+') { position++; v += _multiplication(); }
      else if (c == '-') { position++; v -= _multiplication(); }
      else break;
    }
    return v;
  }

  double _multiplication() {
    double v = _power();
    while (position < text.length) {
      final c = text[position];
      if (c == '*') { position++; v *= _power(); }
      else if (c == '/') {
        position++;
        final d = _power();
        if (d == 0) throw const FormatException('División entre cero.');
        v /= d;
      } else break;
    }
    return v;
  }

  double _power() {
    double v = _unary();
    if (position < text.length && text[position] == '^') {
      position++;
      v = math.pow(v, _power()).toDouble();
    }
    return v;
  }

  double _unary() {
    if (position < text.length && text[position] == '+') { position++; return _unary(); }
    if (position < text.length && text[position] == '-') { position++; return -_unary(); }
    return _primary();
  }

  double _primary() {
    if (position >= text.length) throw const FormatException('Falta un número.');
    if (text[position] == '(') {
      position++;
      final v = _addition();
      if (position >= text.length || text[position] != ')') {
        throw const FormatException('Falta cerrar paréntesis.');
      }
      position++;
      return v;
    }
    final start = position;
    bool punto = false;
    while (position < text.length) {
      final c = text[position];
      if (c == '.') {
        if (punto) break;
        punto = true; position++;
      } else if (_digito(c)) position++;
      else break;
    }
    if (start == position) throw const FormatException('Número inválido.');
    final n = double.tryParse(text.substring(start, position));
    if (n == null) throw const FormatException('Número inválido.');
    return n;
  }

  bool _digito(String c) {
    final x = c.codeUnitAt(0);
    return x >= 48 && x <= 57;
  }
}
