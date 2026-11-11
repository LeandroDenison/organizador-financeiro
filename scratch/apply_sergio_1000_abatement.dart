import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/organizador-financeiro-d77b4/databases/(default)/documents/organizador_financeiro/main_state');

  // 1. Fetch current document
  final getReq = await client.getUrl(url);
  final getRes = await getReq.close();
  final body = await getRes.transform(utf8.decoder).join();
  final doc = jsonDecode(body);
  final payload = jsonDecode(doc['fields']['payloadJson']['stringValue']);
  final List<dynamic> debts = payload['debts'] ?? [];

  print('Existing debts count: ${debts.length}');

  // Clean all previous test payment history on Sergio's debts
  for (var d in debts) {
    if (d['personName'].toString().toLowerCase().contains('sergio')) {
      d['paymentHistory'] = [];
      d['isSettled'] = false;
    }
  }

  // Now record the R$ 1.000,00 payment distributed across this month's dues
  // 641.78 to Jim.Com + 120.04 to ML 120 + 219.15 to LATAM + 19.03 to ML MERC = R$ 1.000,00
  final now = DateTime.now().toIso8601String();
  final p1 = {'id': 'pix_1000_1', 'date': now, 'amount': 641.78, 'installmentNumber': 1, 'note': 'Transferência Recebida via Pix (09/11)'};
  final p2 = {'id': 'pix_1000_2', 'date': now, 'amount': 120.04, 'installmentNumber': 1, 'note': 'Transferência Recebida via Pix (09/11)'};
  final p3 = {'id': 'pix_1000_3', 'date': now, 'amount': 219.15, 'installmentNumber': 2, 'note': 'Transferência Recebida via Pix (09/11)'};
  final p4 = {'id': 'pix_1000_4', 'date': now, 'amount': 19.03, 'installmentNumber': 13, 'note': 'Transferência Recebida via Pix (09/11)'};

  for (var d in debts) {
    final desc = d['description'].toString();
    if (desc.contains('Jim.Com')) {
      d['paymentHistory'] = [p1];
    } else if (desc.contains('Compra Sergio') || desc.contains('120')) {
      d['paymentHistory'] = [p2];
    } else if (desc.contains('LATAM')) {
      d['paymentHistory'] = [p3];
    } else if (desc.contains('MERCADOLIVRE*MERC')) {
      d['paymentHistory'] = [p4];
    }
  }

  payload['debts'] = debts;
  final updatedPayloadJson = jsonEncode(payload);

  final patchUrl = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/organizador-financeiro-d77b4/databases/(default)/documents/organizador_financeiro/main_state?updateMask.fieldPaths=payloadJson&updateMask.fieldPaths=updatedAt');
  final patchReq = await client.patchUrl(patchUrl);
  patchReq.headers.contentType = ContentType.json;
  patchReq.write(jsonEncode({
    'fields': {
      'payloadJson': {'stringValue': updatedPayloadJson},
      'updatedAt': {'stringValue': DateTime.now().toUtc().toIso8601String()},
    }
  }));

  final patchRes = await patchReq.close();
  print('Patch response status: ${patchRes.statusCode}');
  client.close();
}
