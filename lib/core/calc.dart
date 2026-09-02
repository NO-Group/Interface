/// A tiny, safe arithmetic evaluator for the omnibox calculator.
///
/// Shunting-yard — no eval, no dart:math craziness, no code injection.
class Calculator {
  Calculator._();

  static final _tokenRe = RegExp(r'\d+\.?\d*|[+\-*/%^()]');

  /// Returns the numeric result, or null when [input] is not an expression.
  static double? tryEval(String input) {
    final s = input.trim().replaceAll(',', '').replaceAll('×', '*').replaceAll('÷', '/');
    if (s.isEmpty) return null;
    final tokens = _tokenRe.allMatches(s).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return null;
    // Re-joining must cover the whole input (no letters etc).
    final joined = tokens.join();
    final compact = s.replaceAll(RegExp(r'\s'), '');
    if (joined != compact) return null;
    if (!RegExp(r'\d').hasMatch(s) ||
        !RegExp(r'[+\-*/%^]').hasMatch(s)) {
      return null;
    }
    try {
      final r = _parse(tokens);
      if (r.isNaN || r.isInfinite) return null;
      return r;
    } catch (_) {
      return null;
    }
  }

  static String pretty(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static double _parse(List<String> tokens) {
    final out = <double>[];
    final ops = <String>[];
    final prec = {'+': 1, '-': 1, '*': 2, '/': 2, '%': 2, '^': 3};

    void apply() {
      final op = ops.removeLast();
      if (out.length < 2) throw const FormatException('bad');
      final b = out.removeLast();
      final a = out.removeLast();
      switch (op) {
        case '+':
          out.add(a + b);
        case '-':
          out.add(a - b);
        case '*':
          out.add(a * b);
        case '/':
          out.add(a / b);
        case '%':
          out.add(a % b);
        case '^':
          out.add(_pow(a, b));
      }
    }

    for (final t in tokens) {
      if (RegExp(r'^\d').hasMatch(t)) {
        out.add(double.parse(t));
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          apply();
        }
        if (ops.isEmpty) throw const FormatException('bad');
        ops.removeLast();
      } else {
        while (ops.isNotEmpty &&
            ops.last != '(' &&
            prec[ops.last]! >= prec[t]! &&
            t != '^') {
          apply();
        }
        ops.add(t);
      }
    }
    while (ops.isNotEmpty) {
      if (ops.last == '(') throw const FormatException('bad');
      apply();
    }
    if (out.length != 1) throw const FormatException('bad');
    return out.single;
  }

  static double _pow(double a, double b) {
    // Integer powers only — keeps this dependency-free and deterministic.
    if (b == b.roundToDouble() && b.abs() <= 512) {
      var result = 1.0;
      final base = b < 0 ? 1 / a : a;
      for (var i = 0; i < b.abs().round(); i++) {
        result *= base;
      }
      return result;
    }
    throw const FormatException('non-integer exponent');
  }
}
