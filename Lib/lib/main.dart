import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

void main() {
  runApp(const CalculadoraPreciosApp());
}

class ProviderConfig {
  String name;
  String formula;

  ProviderConfig({
    required this.name,
    required this.formula,
  });
}

class AppConfig {
  List<ProviderConfig> providers;
  String cashFormula;

  AppConfig({
    required this.providers,
    required this.cashFormula,
  });
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF3),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAF3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7A8178)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF39733D),
              width: 2,
            ),
          ),
        ),
      ),
      home: const PriceCalculatorPage(),
    );
  }
}

class PriceCalculatorPage extends StatefulWidget {
  const PriceCalculatorPage({super.key});

  @override
  State<PriceCalculatorPage> createState() => _PriceCalculatorPageState();
}

class _PriceCalculatorPageState extends State<PriceCalculatorPage> {
  static const String _providersKey = 'providers';
  static const String _cashFormulaKey = 'cash_formula';

  AppConfig _config = AppConfig(
    providers: [
      ProviderConfig(
        name: 'RADEC',
        formula: '1.9604 × (C × 1.16 × 0.65)^0.95',
      ),
      ProviderConfig(
        name: 'GRIMEX',
        formula: '1.9604 × (C × 0.62)^0.95',
      ),
    ],
    cashFormula: 'P / 1.035',
  );

  int _selectedProvider = 0;
  final TextEditingController _costController = TextEditingController();
  double? _publicPrice;
  double? _cashPrice;
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

    final names = prefs.getStringList(_providersKey);
    final formulas = prefs.getStringList('provider_formulas');

    if (names != null &&
        formulas != null &&
        names.length == formulas.length &&
        names.isNotEmpty) {
      _config = AppConfig(
        providers: List.generate(
          names.length,
          (index) => ProviderConfig(
            name: names[index],
            formula: formulas[index],
          ),
        ),
        cashFormula: prefs.getString(_cashFormulaKey) ?? 'P / 1.035',
      );
    }

    if (_selectedProvider >= _config.providers.length) {
      _selectedProvider = 0;
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _providersKey,
      config.providers.map((p) => p.name).toList(),
    );

    await prefs.setStringList(
      'provider_formulas',
      config.providers.map((p) => p.formula).toList(),
    );

    await prefs.setString(_cashFormulaKey, config.cashFormula);

    if (!mounted) return;

    setState(() {
      _config = config;
      if (_selectedProvider >= _config.providers.length) {
        _selectedProvider = 0;
      }
      _publicPrice = null;
      _cashPrice = null;
      _errorMessage = null;
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();

    final raw = _costController.text.trim().replaceAll(',', '');

    if (raw.isEmpty) {
      setState(() {
        _errorMessage = 'Ingresa el costo del producto.';
        _publicPrice = null;
        _cashPrice = null;
      });
      return;
    }

    final cost = double.tryParse(raw);

    if (cost == null || cost < 0) {
      setState(() {
        _errorMessage = 'Ingresa un costo válido.';
        _publicPrice = null;
        _cashPrice = null;
      });
      return;
    }

    if (_config.providers.isEmpty) {
      setState(() {
        _errorMessage = 'No hay proveedores configurados.';
        _publicPrice = null;
        _cashPrice = null;
      });
      return;
    }

    try {
      final formula = _config.providers[_selectedProvider].formula;
      final publicPrice = FormulaEvaluator.evaluate(
        formula,
        variables: {'C': cost},
      );

      if (!publicPrice.isFinite || publicPrice < 0) {
        throw const FormatException('Resultado inválido');
      }

      final cashPrice = FormulaEvaluator.evaluate(
        _config.cashFormula,
        variables: {
          'P': publicPrice,
          'C': cost,
        },
      );

      if (!cashPrice.isFinite || cashPrice < 0) {
        throw const FormatException('Resultado de efectivo inválido');
      }

      setState(() {
        _publicPrice = publicPrice;
        _cashPrice = cashPrice;
        _errorMessage = null;
      });
    } catch (_) {
      setState(() {
        _publicPrice = null;
        _cashPrice = null;
        _errorMessage =
            'No se pudo calcular. Revisa la fórmula configurada.';
      });
    }
  }

  void _clear() {
    setState(() {
      _costController.clear();
      _publicPrice = null;
      _cashPrice = null;
      _errorMessage = null;
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<AppConfig>(
      MaterialPageRoute(
        builder: (_) => ProviderSettingsPage(
          initialConfig: _config,
        ),
      ),
    );

    if (result != null) {
      await _saveConfig(result);
    }
  }

  String _money(double? value) {
    if (value == null) return '—';
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final provider = _config.providers.isEmpty
        ? null
        : _config.providers[_selectedProvider];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Precios'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Configurar proveedores y fórmulas',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CALCULADORA DE PRECIOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 48),
              DropdownButtonFormField<int>(
                value: provider == null ? null : _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Proveedor',
                ),
                items: List.generate(
                  _config.providers.length,
                  (index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text(_config.providers[index].name),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedProvider = value;
                    _publicPrice = null;
                    _cashPrice = null;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _calculate(),
                decoration: const InputDecoration(
                  labelText: 'Costo del producto',
                  prefixText: '\$ ',
                  hintText: 'Ej. 1000.00',
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text(
                    'CALCULAR',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 58,
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 34),
              _ResultCard(
                title: 'PRECIO AL PÚBLICO',
                value: _money(_publicPrice),
              ),
              const SizedBox(height: 18),
              _ResultCard(
                title: 'PAGO EN EFECTIVO',
                value: _money(_cashPrice),
                compact: true,
              ),
              const SizedBox(height: 18),
              _ResultCard(
                title: 'DESCUENTO MAYORISTAS',
                value: 'Pendiente',
                compact: true,
                muted: true,
              ),
              const SizedBox(height: 32),
              if (provider != null)
                Text(
                  '${provider.name}: ${provider.formula}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Efectivo: ${_config.cashFormula}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
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
  final bool compact;
  final bool muted;

  const _ResultCard({
    required this.title,
    required this.value,
    this.compact = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: compact ? 20 : 28,
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 19 : 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 27 : 34,
                fontWeight: FontWeight.w800,
                color: muted
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderSettingsPage extends StatefulWidget {
  final AppConfig initialConfig;

  const ProviderSettingsPage({
    super.key,
    required this.initialConfig,
  });

  @override
  State<ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<ProviderSettingsPage> {
  late List<ProviderConfig> _providers;
  late TextEditingController _cashController;

  @override
  void initState() {
    super.initState();

    _providers = widget.initialConfig.providers
        .map(
          (p) => ProviderConfig(
            name: p.name,
            formula: p.formula,
          ),
        )
        .toList();

    _cashController = TextEditingController(
      text: widget.initialConfig.cashFormula,
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _addProvider() {
    setState(() {
      _providers.add(
        ProviderConfig(
          name: 'Nuevo proveedor',
          formula: 'C',
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
      _providers.removeAt(index);
    });
  }

  void _save() {
    final cleaned = <ProviderConfig>[];

    for (final provider in _providers) {
      final name = provider.name.trim();
      final formula = provider.formula.trim();

      if (name.isEmpty || formula.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa el nombre y la fórmula de cada proveedor.'),
          ),
        );
        return;
      }

      try {
        FormulaEvaluator.evaluate(
          formula,
          variables: {'C': 1000, 'P': 1000},
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('La fórmula de "$name" no es válida.'),
          ),
        );
        return;
      }

      cleaned.add(
        ProviderConfig(
          name: name,
          formula: formula,
        ),
      );
    }

    final cashFormula = _cashController.text.trim();

    if (cashFormula.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fórmula de pago en efectivo no puede estar vacía.'),
        ),
      );
      return;
    }

    try {
      FormulaEvaluator.evaluate(
        cashFormula,
        variables: {'C': 1000, 'P': 1000},
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fórmula de pago en efectivo no es válida.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      AppConfig(
        providers: cleaned,
        cashFormula: cashFormula,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Proveedores',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Puedes cambiar los nombres y las fórmulas sin modificar el código. '
            'Los cambios se guardan en el dispositivo y permanecen después de cerrar la aplicación.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(
            _providers.length,
            (index) => _ProviderEditorCard(
              index: index,
              provider: _providers[index],
              onDelete: () => _removeProvider(index),
              onNameChanged: (value) {
                _providers[index].name = value;
              },
              onFormulaChanged: (value) {
                _providers[index].formula = value;
              },
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addProvider,
            icon: const Icon(Icons.add),
            label: const Text('Agregar proveedor'),
          ),
          const SizedBox(height: 32),
          const Text(
            'Pago en efectivo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cashController,
            decoration: const InputDecoration(
              labelText: 'Fórmula',
              hintText: 'Ej. P / 1.035',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Variables disponibles: C = costo del producto, P = precio al público.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 28),
          const Text(
            'Descuento mayoristas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta sección queda reservada para configurar posteriormente '
            'el descuento o fórmula para clientes mayoristas.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderEditorCard extends StatelessWidget {
  final int index;
  final ProviderConfig provider;
  final VoidCallback onDelete;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onFormulaChanged;

  const _ProviderEditorCard({
    required this.index,
    required this.provider,
    required this.onDelete,
    required this.onNameChanged,
    required this.onFormulaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Proveedor ${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar proveedor',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: provider.name,
              decoration: const InputDecoration(
                labelText: 'Nombre',
              ),
              onChanged: onNameChanged,
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: provider.formula,
              decoration: const InputDecoration(
                labelText: 'Fórmula',
                hintText: 'Ej. 1.9604 × (C × 1.16 × 0.65)^0.95',
              ),
              onChanged: onFormulaChanged,
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Usa C para representar el costo. '
                'También puedes usar P cuando sea necesario.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Evaluador matemático pequeño y seguro para las fórmulas de la aplicación.
///
/// Operadores permitidos:
/// +  -  *  ×  /  ^
/// Paréntesis: ( )
/// Variables: C y P
/// Ejemplos:
///   1.9604 × (C × 1.16 × 0.65)^0.95
///   1.9604 × (C × 0.62)^0.95
///   P / 1.035
class FormulaEvaluator {
  static double evaluate(
    String expression, {
    required Map<String, double> variables,
  }) {
    final tokens = _tokenize(expression);
    final rpn = _toRpn(tokens);
    return _evaluateRpn(rpn, variables);
  }

  static List<String> _tokenize(String expression) {
    var text = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    if (text.isEmpty) {
      throw const FormatException('Fórmula vacía');
    }

    final tokens = <String>[];
    int i = 0;

    while (i < text.length) {
      final char = text[i];

      if (_isDigit(char) || char == '.') {
        final start = i;
        bool hasDot = false;

        while (i < text.length) {
          final c = text[i];

          if (_isDigit(c)) {
            i++;
            continue;
          }

          if (c == '.' && !hasDot) {
            hasDot = true;
            i++;
            continue;
          }

          break;
        }

        final number = text.substring(start, i);
        if (number == '.') {
          throw const FormatException('Número inválido');
        }

        tokens.add(number);
        continue;
      }

      if (_isLetter(char)) {
        final start = i;
        while (i < text.length && _isLetter(text[i])) {
          i++;
        }

        final variable = text.substring(start, i).toUpperCase();

        if (variable != 'C' && variable != 'P') {
          throw FormatException('Variable no permitida: $variable');
        }

        tokens.add(variable);
        continue;
      }

      if ('+-*/^()'.contains(char)) {
        tokens.add(char);
        i++;
        continue;
      }

      throw FormatException('Carácter no permitido: $char');
    }

    return tokens;
  }

  static List<String> _toRpn(List<String> tokens) {
    final output = <String>[];
    final operators = <String>[];

    String previous = '';

    for (final token in tokens) {
      if (_isNumber(token) || token == 'C' || token == 'P') {
        output.add(token);
      } else if (_isOperator(token)) {
        var op = token;

        // Unary +/-
        if ((op == '+' || op == '-') &&
            (previous.isEmpty ||
                _isOperator(previous) ||
                previous == '(')) {
          output.add('0');
        }

        while (operators.isNotEmpty &&
            _isOperator(operators.last) &&
            ((_precedence(operators.last) > _precedence(op)) ||
                (_precedence(operators.last) == _precedence(op) &&
                    !_isRightAssociative(op)))) {
          output.add(operators.removeLast());
        }

        operators.add(op);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        bool foundOpening = false;

        while (operators.isNotEmpty) {
          final top = operators.removeLast();

          if (top == '(') {
            foundOpening = true;
            break;
          }

          output.add(top);
        }

        if (!foundOpening) {
          throw const FormatException('Paréntesis desbalanceados');
        }
      }

      previous = token;
    }

    while (operators.isNotEmpty) {
      final op = operators.removeLast();

      if (op == '(' || op == ')') {
        throw const FormatException('Paréntesis desbalanceados');
      }

      output.add(op);
    }

    return output;
  }

  static double _evaluateRpn(
    List<String> rpn,
    Map<String, double> variables,
  ) {
    final stack = <double>[];

    for (final token in rpn) {
      if (_isNumber(token)) {
        stack.add(double.parse(token));
        continue;
      }

      if (token == 'C' || token == 'P') {
        final value = variables[token];

        if (value == null) {
          throw FormatException('Falta la variable $token');
        }

        stack.add(value);
        continue;
      }

      if (_isOperator(token)) {
        if (stack.length < 2) {
          throw const FormatException('Fórmula incompleta');
        }

        final b = stack.removeLast();
        final a = stack.removeLast();

        late final double result;

        switch (token) {
          case '+':
            result = a + b;
            break;
          case '-':
            result = a - b;
            break;
          case '*':
            result = a * b;
            break;
          case '/':
            if (b == 0) {
              throw const FormatException('División entre cero');
            }
            result = a / b;
            break;
          case '^':
            result = math.pow(a, b).toDouble();
            break;
          default:
            throw FormatException('Operador desconocido: $token');
        }

        if (!result.isFinite) {
          throw const FormatException('Resultado no finito');
        }

        stack.add(result);
      }
    }

    if (stack.length != 1) {
      throw const FormatException('Fórmula inválida');
    }

    return stack.single;
  }

  static bool _isOperator(String value) {
    return '+-*/^'.contains(value);
  }

  static int _precedence(String value) {
    switch (value) {
      case '+':
      case '-':
        return 1;
      case '*':
      case '/':
        return 2;
      case '^':
        return 3;
      default:
        return 0;
    }
  }

  static bool _isRightAssociative(String value) => value == '^';

  static bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isLetter(String value) {
    final code = value.toUpperCase().codeUnitAt(0);
    return (code >= 65 && code <= 90);
  }

  static bool _isNumber(String value) {
    return double.tryParse(value) != null;
  }
}
