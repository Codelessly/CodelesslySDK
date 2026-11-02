import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? eval(String expression) => FormulaEvaluator.evaluate(expression, (path) => null);

  group('currency', () {
    test('writes each currency its own way', () {
      expect(eval('currency(1234.5, "USD")'), r'$1,234.50');
      expect(eval('currency(1234.5, "EUR")'), '1.234,50 €');
      expect(eval('currency(1234.5, "GBP")'), '£1,234.50');
      expect(eval('currency(123456.7, "JPY")'), '¥123,457');
      expect(eval('currency(1234.5, "CHF")'), 'CHF 1’234.50');
      expect(eval('currency(5, "XYZ")'), 'XYZ 5.00');
      expect(eval('currency(5, "usd")'), r'$5.00');
    });

    test('negatives get a true minus, signed puts + on positives', () {
      expect(eval('currency(-6.25, "USD")'), '−\$6.25');
      expect(eval('currency(-6.25, "USD", "ascii")'), r'-$6.25');
      expect(eval('currency(42, "GBP", "signed")'), '+£42.00');
      expect(eval('currency(0, "USD", "signed")'), r'$0.00');
      expect(eval('currency(-0.001, "USD")'), r'$0.00');
    });

    test('whole, compact and plain', () {
      expect(eval('currency(4839.6, "USD", "whole")'), r'$4,840');
      expect(eval('currency(12400, "USD", "compact")'), r'$12k');
      expect(eval('currency(1500, "EUR", "compact")'), '1,5k €');
      expect(eval('currency(2500000, "USD", "compact")'), r'$2.5M');
      expect(eval('currency(-1234.5, "EUR", "plain")'), '−1.234,50');
      expect(eval('currency(10, "USD", "signed whole")'), r'+$10');
    });
  });

  group('amount input', () {
    test('parseAmount reads the currency marks', () {
      expect(eval('parseAmount("1.234,50", "EUR")'), 1234.5);
      expect(eval('parseAmount("1,234.50", "USD")'), 1234.5);
      expect(eval('parseAmount("\$12", "USD")'), 12);
      expect(eval('parseAmount("abc", "USD")'), null);
      expect(eval('parseAmount("", "USD")'), null);
      expect(eval('parseAmount("12,345", "JPY")'), 12345);
    });

    test('formatAmount groups as you type and caps decimals', () {
      expect(eval('formatAmount("12345.6", "USD")'), '12,345.6');
      expect(eval('formatAmount("12345.678", "USD")'), '12,345.67');
      expect(eval('formatAmount("1234,5", "EUR")'), '1.234,5');
      expect(eval('formatAmount("1234.5", "EUR")'), '1.234,5');
      expect(eval('formatAmount("12345.678", "JPY")'), '12,345');
      expect(eval('formatAmount("007", "USD")'), '7');
      expect(eval('formatAmount(".5", "USD")'), '0.5');
      expect(eval('formatAmount("", "USD")'), '');
    });

    test('the currency text field formatter keeps the caret from the end', () {
      final f = CurrencyAmountInputFormatter('USD');
      final v = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12345', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(v.text, '12,345');
      expect(v.selection.extentOffset, 6);
      final eur = CurrencyAmountInputFormatter('EUR').formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234.5', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(eur.text, '1.234,5');
      expect(
        const CurrencyTextInputFormatterModel(currencyCode: r'${acct.currency}')
            .toFlutterFormatter(resolve: (s) => 'JPY')!
            .formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '1000.5'))
            .text,
        '1,000',
      );
      expect(
        TextInputFormatterModel.fromJson(
          const CurrencyTextInputFormatterModel(currencyCode: 'GBP').toJson().cast<String, dynamic>(),
        ),
        const CurrencyTextInputFormatterModel(currencyCode: 'GBP'),
      );
    });

    test('symbol and decimals', () {
      expect(eval('currencySymbol("EUR")'), '€');
      expect(eval('currencyDecimals("JPY")'), 0);
    });
  });
}
