import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Non-breaking spaces and bidi marks intl puts in its output.
const String nbsp = ' ';
const String narrowNbsp = ' ';
const String rlm = '‏';
const String alm = '؜';

void main() {
  final Map<String, Object?> vars = {
    'count': 3,
    'lang': 'ar_EG',
    'trip': {'city': 'Cairo', 'nights': 2},
  };

  Object? resolve(String path) {
    Object? value = vars;
    for (final part in path.split('.')) {
      value = value is Map ? value[part] : null;
    }
    return value;
  }

  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, resolve);

  const String date = "'2026-10-30T14:05:00'";

  group('formatNumber with a locale', () {
    test('uses the locale separators and digits', () {
      expect(eval("formatNumber(1234.5, 1, 'en_US')"), '1,234.5');
      expect(eval("formatNumber(1234.5, 1, 'es_ES')"), '1.234,5');
      expect(eval("formatNumber(1234.5, 1, 'fr_FR')"), '1${narrowNbsp}234,5');
      expect(eval("formatNumber(1234.5, 1, 'ja_JP')"), '1,234.5');
      expect(eval("formatNumber(1234.5, 1, 'tr_TR')"), '1.234,5');
      expect(eval("formatNumber(1234.5, 1, 'ar_EG')"), '١٬٢٣٤٫٥');
      expect(eval("formatNumber(1234.5, 1, 'he_IL')"), '1,234.5');
      expect(eval("formatNumber(1234567, 0, 'ar_EG')"), '١٬٢٣٤٬٥٦٧');
    });

    test('accepts dashes, bare languages and a locale in place of digits', () {
      expect(eval("formatNumber(1234.5, 1, 'ar-EG')"), '١٬٢٣٤٫٥');
      expect(eval("formatNumber(1234.5, 1, 'fr')"), '1${narrowNbsp}234,5');
      expect(eval("formatNumber(1234.5, 1, 'ja')"), '1,234.5');
      expect(eval("formatNumber(1234.5, 1, 'he')"), '1,234.5');
      // intl's bare `ar` writes Latin digits; ar_EG writes Arabic-Indic.
      expect(eval("formatNumber(1234.5, 1, 'ar')"), '1,234.5');
      expect(eval("formatNumber(1234567, 'tr_TR')"), '1.234.567');
      expect(eval('formatNumber(1234.5, 1, lang)'), '١٬٢٣٤٫٥');
    });

    test('falls back to the language, then English, for unknown locales', () {
      expect(eval("formatNumber(1234.5, 1, 'fr_XX')"), '1${narrowNbsp}234,5');
      expect(eval("formatNumber(1234.5, 1, 'xx_YY')"), '1,234.5');
      expect(eval("formatNumber(1234.5, 1, 'zz')"), '1,234.5');
    });

    test('keeps the old forms', () {
      expect(eval('formatNumber(2481.64, 1)'), '2,481.6');
      expect(eval('formatNumber(2481.64)'), '2,482');
      expect(eval("formatNumber(1234.567, '2')"), '1,234.57');
      expect(eval('formatNumber(1234.5, 1, null)'), '1,234.5');
      expect(eval("formatNumber(1234.5, 1, '')"), '1,234.5');
      expect(eval("formatNumber('abc')"), '');
    });
  });

  group('formatCurrency', () {
    test('writes each currency the locale way', () {
      expect(eval("formatCurrency(1234.5, 'USD', 'en_US')"), r'$1,234.50');
      expect(
        eval("formatCurrency(1234.5, 'EUR', 'fr_FR')"),
        '1${narrowNbsp}234,50$nbsp€',
      );
      expect(eval("formatCurrency(1234.5, 'EUR', 'es_ES')"), '1.234,50$nbsp€');
      expect(eval("formatCurrency(1234.5, 'TRY', 'tr_TR')"), '₺1.234,50');
      expect(
        eval("formatCurrency(1234.5, 'EGP', 'ar_EG')"),
        '$rlm١٬٢٣٤٫٥٠${nbsp}E£',
      );
      expect(
        eval("formatCurrency(1234.5, 'ILS', 'he_IL')"),
        '${rlm}1,234.50$nbsp$rlm₪',
      );
    });

    test('yen has no decimals', () {
      expect(eval("formatCurrency(1500, 'JPY', 'ja_JP')"), '¥1,500');
      expect(eval("formatCurrency(1234.5, 'JPY', 'ja_JP')"), '¥1,235');
      expect(eval("formatCurrency(1234.5, 'JPY')"), '¥1,235');
    });

    test('defaults to en_US, takes decimals and lower-case codes', () {
      expect(eval("formatCurrency(1234.5, 'USD')"), r'$1,234.50');
      expect(eval("formatCurrency(1234.5, 'usd', 'en_US', 0)"), r'$1,235');
      expect(eval("formatCurrency(1234.5, 'USD', 0)"), r'$1,235');
      expect(eval("formatCurrency(-5, 'USD')"), r'-$5.00');
      expect(eval("formatCurrency(1234.5, 'EUR', 'xx')"), '€1,234.50');
    });
  });

  group('formatPercent', () {
    test('writes percentages the locale way', () {
      expect(eval('formatPercent(0.42)'), '42%');
      expect(eval("formatPercent(0.42, 'en_US')"), '42%');
      expect(eval("formatPercent(0.42, 'fr_FR')"), '42$nbsp%');
      expect(eval("formatPercent(0.42, 'es_ES')"), '42$nbsp%');
      expect(eval("formatPercent(0.42, 'ja_JP')"), '42%');
      expect(eval("formatPercent(0.42, 'tr_TR')"), '%42');
      expect(eval("formatPercent(0.42, 'he_IL')"), '42%');
      expect(eval("formatPercent(0.42, 'ar_EG')"), '٤٢٪$alm');
    });

    test('takes decimals', () {
      expect(eval("formatPercent(0.425, 'en', 1)"), '42.5%');
      expect(eval('formatPercent(0.425, 1)'), '42.5%');
    });
  });

  group('formatDate with a locale or style', () {
    test('full, long, medium and short', () {
      expect(
        eval('formatDate($date, "full", "en_US")'),
        'Friday, October 30, 2026',
      );
      expect(eval('formatDate($date, "long", "en_US")'), 'October 30, 2026');
      expect(eval('formatDate($date, "medium", "en_US")'), 'Oct 30, 2026');
      expect(eval('formatDate($date, "short", "en_US")'), '10/30/2026');

      expect(
        eval('formatDate($date, "full", "es_ES")'),
        'viernes, 30 de octubre de 2026',
      );
      expect(eval('formatDate($date, "medium", "es_ES")'), '30 oct 2026');
      expect(eval('formatDate($date, "short", "es_ES")'), '30/10/2026');

      expect(
        eval('formatDate($date, "full", "fr_FR")'),
        'vendredi 30 octobre 2026',
      );
      expect(eval('formatDate($date, "medium", "fr_FR")'), '30 oct. 2026');
      expect(eval('formatDate($date, "short", "fr_FR")'), '30/10/2026');

      expect(eval('formatDate($date, "full", "ja_JP")'), '2026年10月30日金曜日');
      expect(eval('formatDate($date, "medium", "ja_JP")'), '2026年10月30日');
      expect(eval('formatDate($date, "short", "ja_JP")'), '2026/10/30');

      expect(eval('formatDate($date, "full", "tr_TR")'), '30 Ekim 2026 Cuma');
      expect(eval('formatDate($date, "medium", "tr_TR")'), '30 Eki 2026');
      expect(eval('formatDate($date, "short", "tr_TR")'), '30.10.2026');

      expect(
        eval('formatDate($date, "full", "ar_EG")'),
        'الجمعة، ٣٠ أكتوبر ٢٠٢٦',
      );
      expect(eval('formatDate($date, "medium", "ar_EG")'), '٣٠ أكتوبر ٢٠٢٦');
      expect(eval('formatDate($date, "short", "ar_EG")'), '٣٠$rlm/١٠$rlm/٢٠٢٦');

      expect(
        eval('formatDate($date, "full", "he_IL")'),
        'יום שישי, 30 באוקטובר 2026',
      );
      expect(eval('formatDate($date, "medium", "he_IL")'), '30 באוק׳ 2026');
      expect(eval('formatDate($date, "short", "he_IL")'), '30.10.2026');
    });

    test('time, dayMonth, weekday and monthYear', () {
      expect(eval('formatDate($date, "time", "en_US")'), '2:05${narrowNbsp}PM');
      expect(eval('formatDate($date, "time", "fr_FR")'), '14:05');
      expect(eval('formatDate($date, "time", "ar_EG")'), '٢:٠٥ م');
      expect(eval('formatDate($date, "dayMonth", "es_ES")'), '30 de octubre');
      expect(eval('formatDate($date, "dayMonth", "ja_JP")'), '10月30日');
      expect(eval('formatDate($date, "weekday", "tr_TR")'), 'Cuma');
      expect(eval('formatDate($date, "weekday", "he_IL")'), 'יום שישי');
      expect(eval('formatDate($date, "monthYear", "fr_FR")'), 'octobre 2026');
      expect(eval('formatDate($date, "monthYear", "ar_EG")'), 'أكتوبر ٢٠٢٦');
    });

    test('a style without a locale is en_US', () {
      expect(eval('formatDate($date, "full")'), 'Friday, October 30, 2026');
      expect(eval('formatDate($date, "short")'), '10/30/2026');
    });

    test('a custom pattern with a locale', () {
      expect(eval('formatDate($date, "d MMM y", "fr_FR")'), '30 oct. 2026');
      expect(eval('formatDate($date, "d MMM y", "ar_EG")'), '٣٠ أكتوبر ٢٠٢٦');
      expect(
        eval('formatDate($date, "EEEE d MMMM", "es-ES")'),
        'viernes 30 octubre',
      );
      expect(eval('formatDate($date, "EEE d MMM", "xx")'), 'Fri 30 Oct');
      expect(
        eval('formatDate($date, "full", "fr_XX")'),
        'vendredi 30 octobre 2026',
      );
      expect(eval('formatDate("not a date", "full", "fr_FR")'), isNull);
    });

    test('keeps the English pattern formatter without a locale', () {
      expect(
        eval('formatDate($date, "EEE, MMM d · h:mm a")'),
        'Fri, Oct 30 · 2:05 PM',
      );
      expect(eval('formatDate($date, "yyyy-MM-dd")'), '2026-10-30');
      expect(eval('formatDate($date)'), '2026-10-30');
      expect(eval('formatDate($date, "MMMM d", null)'), 'October 30');
      expect(
        FormulaEvaluator.formatDate(DateTime(2026, 10, 30, 14, 5), 'h:mm a'),
        '2:05 PM',
      );
      expect(
        FormulaEvaluator.formatDate(DateTime(2026, 10, 30), 'full', 'fr_FR'),
        'vendredi 30 octobre 2026',
      );
    });
  });

  group('plurals', () {
    test('pluralCategory follows CLDR', () {
      String? c(num n, String l) => eval("pluralCategory($n, '$l')") as String?;
      expect(
        [
          for (final n in [0, 1, 2, 3, 11, 100]) c(n, 'ar'),
        ],
        ['zero', 'one', 'two', 'few', 'many', 'other'],
      );
      expect(c(10, 'ar_EG'), 'few');
      expect(c(99, 'ar_EG'), 'many');
      expect(
        [
          for (final n in [1, 2, 3]) c(n, 'he'),
        ],
        ['one', 'two', 'other'],
      );
      expect(
        [
          for (final n in [1, 2, 3]) c(n, 'he_IL'),
        ],
        ['one', 'two', 'other'],
      );
      expect(
        [
          for (final n in [0, 1, 2]) c(n, 'en'),
        ],
        ['other', 'one', 'other'],
      );
      expect(
        [
          for (final n in [0, 1, 2]) c(n, 'ja'),
        ],
        ['other', 'other', 'other'],
      );
      expect(
        [
          for (final n in [0, 1, 2]) c(n, 'tr'),
        ],
        ['other', 'one', 'other'],
      );
      expect(c(1.5, 'en'), 'other');
      expect(eval('pluralCategory(1)'), 'one');
      expect(eval('pluralCategory(0)'), 'other');
      expect(c(1, 'xx'), 'other');
    });

    test('plural picks a form by category and writes {n} in locale digits', () {
      const String forms = "{one: '{n} phrase', other: '{n} phrases'}";
      expect(eval("plural(1, $forms, 'en')"), '1 phrase');
      expect(eval("plural(3, $forms, 'en')"), '3 phrases');
      expect(eval("plural(0, $forms, 'en')"), '0 phrases');
      expect(eval('plural(1234, $forms)'), '1,234 phrases');
      expect(eval('plural(count, $forms, lang)'), '٣ phrases');

      const String ar =
          "{zero: 'لا عبارات', one: 'عبارة واحدة', two: 'عبارتان', "
          "few: '{n} عبارات', many: '{n} عبارة', other: '{n} عبارة'}";
      expect(eval("plural(0, $ar, 'ar_EG')"), 'لا عبارات');
      expect(eval("plural(1, $ar, 'ar_EG')"), 'عبارة واحدة');
      expect(eval("plural(2, $ar, 'ar_EG')"), 'عبارتان');
      expect(eval("plural(3, $ar, 'ar_EG')"), '٣ عبارات');
      expect(eval("plural(11, $ar, 'ar_EG')"), '١١ عبارة');
      expect(eval("plural(100, $ar, 'ar_EG')"), '١٠٠ عبارة');

      const String he =
          "{one: 'ביטוי אחד', two: 'שני ביטויים', other: '{n} ביטויים'}";
      expect(eval("plural(1, $he, 'he')"), 'ביטוי אחד');
      expect(eval("plural(2, $he, 'he')"), 'שני ביטויים');
      expect(eval("plural(3, $he, 'he')"), '3 ביטויים');

      // A missing category falls back to other; ja has only other.
      expect(eval("plural(2, {one: 'x', other: '{n} y'}, 'ar')"), '2 y');
      expect(eval("plural(1, {one: 'x', other: '{n}件'}, 'ja')"), '1件');
      expect(
        eval("plural(1.5, {one: 'x', other: '{n} km'}, 'fr_FR')"),
        '1,5 km',
      );
    });

    test('the old plural(count, one, many) still works', () {
      expect(eval("plural(2, 'photo')"), 'photos');
      expect(eval("plural(1, 'photo')"), 'photo');
      expect(eval("plural(0, 'person', 'people')"), 'people');
      expect(eval("plural(1, 'person', 'people')"), 'person');
    });

    test('works through \${= } text and the formula regex', () {
      const String expression =
          "plural(3, {one: '{n} phrase', other: '{n} phrases'}, 'en')";
      expect(eval(expression), '3 phrases');
      expect(FormulaEvaluator.parses(expression), isTrue);
      expect(FormulaEvaluator.errorOf(expression), isNull);

      const String text = '\${= $expression}';
      final match = formulaRegex.firstMatch(text);
      expect(match, isNotNull);
      expect(match![0], text);
      expect(match.namedGroup('expr'), ' $expression');
      expect(FormulaEvaluator.exactExpression(text), ' $expression');

      expect(
        FormulaEvaluator.substitute('You saved $text today.', resolve),
        'You saved 3 phrases today.',
      );
      expect(
        FormulaEvaluator.substitute(
          "\${= plural(count, {one: '{n} card', other: '{n} cards'}, lang)} · "
          "\${= fill('{i} of {n}', {i: 1, n: 10})}",
          resolve,
        ),
        '٣ cards · 1 of 10',
      );
    });
  });

  group('text direction', () {
    test('textDirection of a locale or language', () {
      expect(eval("textDirection('ar_EG')"), 'rtl');
      expect(eval("textDirection('ar')"), 'rtl');
      expect(eval("textDirection('he_IL')"), 'rtl');
      expect(eval("textDirection('he')"), 'rtl');
      expect(eval("textDirection('fa-IR')"), 'rtl');
      expect(eval("textDirection('ur')"), 'rtl');
      for (final l in ['en_US', 'es_ES', 'fr_FR', 'ja_JP', 'tr_TR', 'ja']) {
        expect(eval("textDirection('$l')"), 'ltr', reason: l);
      }
      expect(eval("textDirection('')"), 'ltr');
      expect(eval('textDirection(null)'), 'ltr');
    });

    test('textDirectionOf the first strong character', () {
      expect(eval("textDirectionOf('שלום')"), 'rtl');
      expect(eval("textDirectionOf('مرحبا')"), 'rtl');
      expect(eval("textDirectionOf('123 مرحبا')"), 'rtl');
      expect(eval("textDirectionOf('Hello שלום')"), 'ltr');
      expect(eval("textDirectionOf('12 abc')"), 'ltr');
      expect(eval("textDirectionOf('こんにちは')"), 'ltr');
      expect(eval("textDirectionOf('Merhaba')"), 'ltr');
      expect(eval("textDirectionOf('')"), '');
      expect(eval("textDirectionOf('123')"), '');
      expect(eval("textDirectionOf('١٢٣')"), '');
      expect(eval("textDirectionOf('!? …')"), '');
      expect(eval('textDirectionOf(null)'), '');
    });
  });

  group('fill', () {
    test('replaces placeholders from a map or list', () {
      expect(eval("fill('{i} of {n}', {i: 1, n: 10})"), '1 of 10');
      expect(eval("fill('{city}, {nights} nights', trip)"), 'Cairo, 2 nights');
      expect(eval("fill('{t.city}!', {t: trip})"), 'Cairo!');
      expect(eval("fill('{0} → {1}', ['en', 'fr'])"), 'en → fr');
      expect(eval("fill('{a} {missing}', {a: 'x'})"), 'x {missing}');
      expect(eval("fill('{ i }', {i: 2})"), '2');
      expect(eval("fill('{n}', {n: null})"), '');
      expect(eval("fill('no placeholders', {a: 1})"), 'no placeholders');
      expect(
        eval("fill('{n} · {d}', {n: formatNumber(5, 0, 'ar_EG'), d: 'x'})"),
        '٥ · x',
      );
    });
  });

  test('every new function is documented', () {
    final Set<String> documented = {
      for (final doc in FormulaEvaluator.functionDocs) doc.name,
    };
    for (final name in [
      'formatNumber',
      'formatCurrency',
      'formatPercent',
      'formatDate',
      'pluralCategory',
      'plural',
      'textDirection',
      'textDirectionOf',
      'fill',
    ]) {
      expect(FormulaEvaluator.functions, contains(name));
      expect(documented, contains(name));
    }
  });
}
