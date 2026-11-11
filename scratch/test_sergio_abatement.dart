import 'dart:convert';
import 'package:http/http.dart' as http;

const firestoreBaseUrl =
    'https://firestore.googleapis.com/v1/projects/organizador-financeiro-f5c22/databases/(default)/documents';

Future<void> main() async {
  final url = Uri.parse('$firestoreBaseUrl/app_state/main_state');
  final resp = await http.get(url);
  final data = jsonDecode(utf8.decode(resp.bodyBytes));
  final debtsJson = data['fields']['debts']['stringValue'];
  final List<dynamic> debts = jsonDecode(debtsJson);

  print('Current debts in Firestore: ${debts.length}');
  
  // Reset payment history for Sergio and apply the exact R$ 1.000,00 payment
  double totalSergioMonth = 0.0;
  for (final d in debts) {
    if (d['personName'].toString().toLowerCase().contains('sergio')) {
      final double inst = (d['installmentValue'] as num?)?.toDouble() ?? (d['totalAmount'] as num).toDouble();
      totalSergioMonth += inst;
      print('Sergio debt: ${d['description']} | inst: $inst | rem: ${d['customRemainingAmount']} | hist: ${d['paymentHistory']}');
    }
  }
  print('Total Sergio Month Gross: $totalSergioMonth');
}
