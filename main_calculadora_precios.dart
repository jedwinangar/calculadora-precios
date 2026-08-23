import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const PriceCalculatorPage(),
    );
  }
}

class ProviderConfig {
  String name;
  String acquisitionFormula;
  String publicFormula;

  ProviderConfig({
    required this.name,
    required this.acquisitionFormula,
    required this.publicFormula,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'acquisitionFormula': acquisitionFormula,
        'publicFormula': publicFormula,
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      name: (json['name'] ?? 'Proveedor').toString(),
      acquisitionFormula:
          (json['acquisitionFormula'] ?? 'C').toString(),
      publicFormula:
          (json['publicFormula'] ?? 'A').toString(),
    );
  }
}

class AppConfig {
  List<ProviderConfig> providers;
  String cashFormula;
  String wholesaleFormula;

  AppConfig({
    required this.providers,
    required this.cashFormula,
    required this.wholesaleFormula,
  });

  Map<String, dynamic> toJson() => {
        'providers': providers.map((p) => p.toJson()).toList(),
        'cashFormula': cashFormula,
        'wholesaleFormula': wholesaleFormula,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final list = json['providers'];
    return AppConfig(
      providers: list is List
          ? list
              .whereType<Map>()
              .map((e) => ProviderConfig.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : <ProviderConfig>[],
      cashFormula: (json['cashFormula'] ?? 'P / 1.035').toString(),
      wholesaleFormula:
          (json['wholesaleFormula'] ?? 'P × 0.96').toString(),
    );
  }
}

/// Evaluador sencillo de fórmulas.
///
/// Variables disponibles:
/// C = costo/precio ingresado del proveedor.
/// A = costo de adquisición.
/// P = precio público.
///
/// Operadores:
/// +  -  *  /  ^
/// También acepta ×, ÷ y paréntesis.
class FormulaEvaluator {
  final String text;
  final Map<String, double> variables;
  int _index = 0;

  FormulaEvaluator(this.text, this.variables);

  double evaluate() {
    _index = 0;
    final value = _parseExpression();
    _skipSpaces();

    if (_index != text.length) {
      throw FormatException(
        'Carácter no válido cerca de "${text.substring(_index)}"',
      );
    }

    if (!value.isFinite) {
      throw const FormatException('El resultado no es válido.');
    }

    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();

    while (true) {
      _skipSpaces();
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parsePower();

    while (true) {
      _skipSpaces();
      if (_match('*')) {
        value *= _parsePower();
      } else if (_match('×')) {
        value *= _parsePower();
      } else if (_match('/')) {
        final divisor = _parsePower();
        if (divisor == 0) {
          throw const FormatException('No se puede dividir entre cero.');
        }
        value /= divisor;
      } else if (_match('÷')) {
        final divisor = _parsePower();
        if (divisor == 0) {
          throw const FormatException('No se puede dividir entre cero.');
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parsePower() {
    var value = _parseUnary();
    _skipSpaces();

    if (_match('^')) {
      final exponent = _parsePower();
      value = math.pow(value, exponent).toDouble();
    }

    return value;
  }

  double _parseUnary() {
    _skipSpaces();

    if (_match('+')) {
      return _parseUnary();
    }
    if (_match('-')) {
      return -_parseUnary();
    }

    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipSpaces();

    if (_match('(')) {
      final value = _parseExpression();
      _skipSpaces();

      if (!_match(')')) {
        throw const FormatException('Falta un paréntesis de cierre.');
      }

      return value;
    }

    final variable = _readVariable();
    if (variable != null) {
      final value = variables[variable];
      if (value == null) {
        throw FormatException('Variable "$variable" no disponible.');
      }
      return value;
    }

    return _readNumber();
  }

  String? _readVariable() {
    _skipSpaces();

    final start = _index;
    while (_index < text.length &&
        RegExp(r'[A-Za-z_]').hasMatch(text[_index])) {
      _index++;
    }

    if (start == _index) return null;

    final word = text.substring(start, _index).toUpperCase();
    if (word == 'C' || word == 'A' || word == 'P') {
      return word;
    }

    throw FormatException('Variable "$word" no reconocida.');
  }

  double _readNumber() {
    _skipSpaces();

    final start = _index;
    var hasDigit = false;
    var hasDot = false;

    while (_index < text.length) {
      final char = text[_index];

      if (RegExp(r'[0-9]').hasMatch(char)) {
        hasDigit = true;
        _index++;
      } else if (char == '.' && !hasDot) {
        hasDot = true;
        _index++;
      } else {
        break;
      }
    }

    if (!hasDigit) {
      throw FormatException(
        'Se esperaba un número o una variable en "$text".',
      );
    }

    return double.parse(text.substring(start, _index));
  }

  void _skipSpaces() {
    while (_index < text.length && text[_index].trim().isEmpty) {
      _index++;
    }
  }

  bool _match(String value) {
    if (_index < text.length && text[_index] == value) {
      _index++;
      return true;
    }
    return false;
  }
}

class PriceCalculatorPage extends StatefulWidget {
  const PriceCalculatorPage({super.key});

  @override
  State<PriceCalculatorPage> createState() => _PriceCalculatorPageState();
}

class _PriceCalculatorPageState extends State<PriceCalculatorPage> {
  static const String _configKey = 'price_calculator_config_v3';
  static const String _providersKey = 'providers';
  static const String _cashFormulaKey = 'cash_formula';
  static const String _wholesaleFormulaKey = 'wholesale_formula';

  AppConfig _config = AppConfig(
    providers: [
      ProviderConfig(
        name: 'RADEC',
        acquisitionFormula: 'C × 1.16 × 0.65',
        publicFormula: '1.9604 × A^0.95',
      ),
      ProviderConfig(
        name: 'GRIMEX',
        acquisitionFormula: 'C × 0.62',
        publicFormula: '1.9604 × A^0.95',
      ),
    ],
    cashFormula: 'P / 1.035',
    wholesaleFormula: 'P × 0.96',
  );

  int _selectedProvider = 0;
  final TextEditingController _costController = TextEditingController();

  double? _acquisitionCost;
  double? _publicPrice;
  double? _cashPrice;
  double? _wholesalePrice;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_configKey);

    if (saved != null) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is Map) {
          final loaded = AppConfig.fromJson(
            Map<String, dynamic>.from(decoded),
          );

          if (loaded.providers.isNotEmpty) {
            _config = loaded;
          }
        }
      } catch (_) {
        // Si la configuración guardada está dañada, se conservan
        // los valores iniciales.
      }
    } else {
      // Compatibilidad con versiones anteriores que guardaban
      // las listas por separado.
      final names = prefs.getStringList(_providersKey);
      final cash = prefs.getString(_cashFormulaKey);
      final wholesale = prefs.getString(_wholesaleFormulaKey);

      if (names != null && names.isNotEmpty) {
        for (var i = 0; i < names.length; i++) {
          if (i < _config.providers.length) {
            _config.providers[i].name = names[i];
          }
        }
      }

      if (cash != null && cash.trim().isNotEmpty) {
        _config.cashFormula = cash;
      }
      if (wholesale != null && wholesale.trim().isNotEmpty) {
        _config.wholesaleFormula = wholesale;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _configKey,
      jsonEncode(_config.toJson()),
    );

    // También mantenemos estas claves para compatibilidad.
    await prefs.setStringList(
      _providersKey,
      _config.providers.map((p) => p.name).toList(),
    );
    await prefs.setString(_cashFormulaKey, _config.cashFormula);
    await prefs.setString(
      _wholesaleFormulaKey,
      _config.wholesaleFormula,
    );
  }

  double _evaluate(String formula, Map<String, double> variables) {
    return FormulaEvaluator(formula, variables).evaluate();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();

    final costText = _costController.text.trim().replaceAll(',', '.');
    final cost = double.tryParse(costText);

    if (cost == null || cost < 0) {
      setState(() {
        _errorMessage = 'Ingresa un costo válido.';
        _acquisitionCost = null;
        _publicPrice = null;
        _cashPrice = null;
        _wholesalePrice = null;
      });
      return;
    }

    final provider = _config.providers[_selectedProvider];

    try {
      final acquisition = _evaluate(
        provider.acquisitionFormula,
        {'C': cost},
      );

      final publicPrice = _evaluate(
        provider.publicFormula,
        {
          'C': cost,
          'A': acquisition,
        },
      );

      final cashPrice = _evaluate(
        _config.cashFormula,
        {
          'C': cost,
          'A': acquisition,
          'P': publicPrice,
        },
      );

      final wholesalePrice = _evaluate(
        _config.wholesaleFormula,
        {
          'C': cost,
          'A': acquisition,
          'P': publicPrice,
        },
      );

      setState(() {
        _errorMessage = null;
        _acquisitionCost = acquisition;
        _publicPrice = publicPrice;
        _cashPrice = cashPrice;
        _wholesalePrice = wholesalePrice;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'No se pudo calcular. Revisa las fórmulas configuradas.';
        _acquisitionCost = null;
        _publicPrice = null;
        _cashPrice = null;
        _wholesalePrice = null;
      });
    }
  }

  void _clear() {
    _costController.clear();
    setState(() {
      _errorMessage = null;
      _acquisitionCost = null;
      _publicPrice = null;
      _cashPrice = null;
      _wholesalePrice = null;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderSettingsPage(
          config: _config,
          onSave: (updated) async {
            setState(() {
              _config = updated;
              if (_selectedProvider >= _config.providers.length) {
                _selectedProvider = 0;
              }
            });
            await _saveConfig();
            _calculate();
          },
        ),
      ),
    );
  }

  String _money(double? value) {
    if (value == null) return '—';
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final provider = _config.providers[_selectedProvider];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Precios'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Configurar proveedores y fórmulas',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CALCULADORA DE PRECIOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              DropdownButtonFormField<int>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Proveedor',
                ),
                items: List.generate(
                  _config.providers.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(_config.providers[index].name),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedProvider = value;
                    _errorMessage = null;
                    _acquisitionCost = null;
                    _publicPrice = null;
                    _cashPrice = null;
                    _wholesalePrice = null;
                  });
                },
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo / precio del proveedor',
                  hintText: 'Ej. 1000.00',
                  prefixText: '\$ ',
                ),
                onSubmitted: (_) => _calculate(),
              ),
              const SizedBox(height: 18),

              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate),
                  label: const Text(
                    'CALCULAR',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _clear,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text(
                  'Limpiar',
                  style: TextStyle(fontSize: 17),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              _ResultCard(
                title: 'COSTO DE ADQUISICIÓN',
                value: _money(_acquisitionCost),
              ),
              const SizedBox(height: 12),
              _ResultCard(
                title: 'PRECIO AL PÚBLICO',
                value: _money(_publicPrice),
                emphasized: true,
              ),
              const SizedBox(height: 12),
              _ResultCard(
                title: 'PAGO EN EFECTIVO',
                value: _money(_cashPrice),
              ),
              const SizedBox(height: 12),
              _ResultCard(
                title: 'PRECIO MAYORISTA',
                value: _money(_wholesalePrice),
              ),

              const SizedBox(height: 24),

              Card(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        provider.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FormulaLine(
                        label: 'Adquisición',
                        formula: provider.acquisitionFormula,
                      ),
                      _FormulaLine(
                        label: 'Público',
                        formula: provider.publicFormula,
                      ),
                      _FormulaLine(
                        label: 'Efectivo',
                        formula: _config.cashFormula,
                      ),
                      _FormulaLine(
                        label: 'Mayorista',
                        formula: _config.wholesaleFormula,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Variables: C = costo ingresado, A = costo de adquisición, P = precio público.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final bool emphasized;

  const _ResultCard({
    required this.title,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: emphasized ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: emphasized ? 20 : 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: emphasized ? 31 : 27,
                fontWeight: FontWeight.bold,
                color: emphasized
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaLine extends StatelessWidget {
  final String label;
  final String formula;

  const _FormulaLine({
    required this.label,
    required this.formula,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '$label: $formula',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class ProviderSettingsPage extends StatefulWidget {
  final AppConfig config;
  final Future<void> Function(AppConfig config) onSave;

  const ProviderSettingsPage({
    super.key,
    required this.config,
    required this.onSave,
  });

  @override
  State<ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<ProviderSettingsPage> {
  late List<_EditableProvider> _providers;
  late TextEditingController _cashController;
  late TextEditingController _wholesaleController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _providers = widget.config.providers
        .map(
          (p) => _EditableProvider(
            name: TextEditingController(text: p.name),
            acquisition:
                TextEditingController(text: p.acquisitionFormula),
            public: TextEditingController(text: p.publicFormula),
          ),
        )
        .toList();

    _cashController =
        TextEditingController(text: widget.config.cashFormula);
    _wholesaleController =
        TextEditingController(text: widget.config.wholesaleFormula);
  }

  @override
  void dispose() {
    for (final p in _providers) {
      p.dispose();
    }
    _cashController.dispose();
    _wholesaleController.dispose();
    super.dispose();
  }

  void _addProvider() {
    setState(() {
      _providers.add(
        _EditableProvider(
          name: TextEditingController(text: 'Nuevo proveedor'),
          acquisition: TextEditingController(text: 'C'),
          public: TextEditingController(text: 'A'),
        ),
      );
    });
  }

  void _removeProvider(int index) {
    if (_providers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe existir al menos un proveedor.'),
        ),
      );
      return;
    }

    setState(() {
      final removed = _providers.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    final providers = <ProviderConfig>[];

    for (final p in _providers) {
      final name = p.name.text.trim();
      final acquisition = p.acquisition.text.trim();
      final public = p.public.text.trim();

      if (name.isEmpty || acquisition.isEmpty || public.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa el nombre y las dos fórmulas de cada proveedor.',
            ),
          ),
        );
        return;
      }

      providers.add(
        ProviderConfig(
          name: name,
          acquisitionFormula: acquisition,
          publicFormula: public,
        ),
      );
    }

    if (_cashController.text.trim().isEmpty ||
        _wholesaleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa las fórmulas de efectivo y mayorista.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final config = AppConfig(
      providers: providers,
      cashFormula: _cashController.text.trim(),
      wholesaleFormula: _wholesaleController.text.trim(),
    );

    try {
      await widget.onSave(config);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          const Text(
            'Proveedores',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Puedes cambiar nombres y todas las fórmulas. '
            'Los cambios quedan guardados en el dispositivo.',
          ),
          const SizedBox(height: 16),

          ...List.generate(
            _providers.length,
            (index) => _ProviderEditorCard(
              index: index,
              data: _providers[index],
              onRemove: () => _removeProvider(index),
            ),
          ),

          OutlinedButton.icon(
            onPressed: _addProvider,
            icon: const Icon(Icons.add),
            label: const Text('Agregar proveedor'),
          ),

          const SizedBox(height: 28),

          const Text(
            'Fórmulas generales',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _cashController,
            decoration: const InputDecoration(
              labelText: 'Pago en efectivo',
              helperText:
                  'Usa P para el precio público. Ejemplo: P / 1.035',
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _wholesaleController,
            decoration: const InputDecoration(
              labelText: 'Precio mayorista',
              helperText:
                  'Usa P para el precio público. Ejemplo: P × 0.96',
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Variables disponibles:\n'
                'C = costo/precio ingresado del proveedor\n'
                'A = costo de adquisición\n'
                'P = precio público\n\n'
                'Operadores: +, -, ×, *, ÷, /, ^ y paréntesis.',
              ),
            ),
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('GUARDAR CAMBIOS'),
          ),
        ],
      ),
    );
  }
}

class _EditableProvider {
  final TextEditingController name;
  final TextEditingController acquisition;
  final TextEditingController public;

  _EditableProvider({
    required this.name,
    required this.acquisition,
    required this.public,
  });

  void dispose() {
    name.dispose();
    acquisition.dispose();
    public.dispose();
  }
}

class _ProviderEditorCard extends StatelessWidget {
  final int index;
  final _EditableProvider data;
  final VoidCallback onRemove;

  const _ProviderEditorCard({
    required this.index,
    required this.data,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Proveedor ${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar proveedor',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: data.name,
              decoration: const InputDecoration(
                labelText: 'Nombre del proveedor',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: data.acquisition,
              decoration: const InputDecoration(
                labelText: 'Fórmula de costo de adquisición',
                helperText: 'Ejemplo RADEC: C × 1.16 × 0.65',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: data.public,
              decoration: const InputDecoration(
                labelText: 'Fórmula de precio público',
                helperText: 'Ejemplo: 1.9604 × A^0.95',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
