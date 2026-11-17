const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Endpoint de Webhook da Pluggy
 * Recebe notificações push sobre atualizações de itens e criação de transações.
 * Suporta eventos: item/created, item/updated, item/error, transactions/created
 */
exports.pluggyWebhook = onRequest(
  {
    region: "southamerica-east1",
    cors: true,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const payload = req.body;
      logger.info("Pluggy Webhook recebido:", { payload });

      const event = payload.event;
      const itemId = payload.itemId || (payload.data && payload.data.itemId);
      const triggeredBy = payload.triggeredBy;

      // Log estruturado no Firestore para auditoria e histórico
      await db.collection("pluggy_webhook_events").add({
        event: event || "unknown",
        itemId: itemId || null,
        triggeredBy: triggeredBy || null,
        payload: payload,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      switch (event) {
        case "item/updated":
        case "item/created": {
          logger.info(`Item atualizado na Pluggy: ${itemId}`);
          // Registra o status do item atualizado
          if (itemId) {
            await db.collection("connected_bank_items").doc(itemId).set(
              {
                status: payload.status || "UPDATED",
                lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                executionStatus: payload.executionStatus || "SUCCESS",
              },
              { merge: true }
            );
          }
          break;
        }

        case "transactions/created": {
          logger.info(`Novas transações detectadas para o item: ${itemId}`);
          // Salva sinalização de novas transações prontas para o app
          if (itemId) {
            await db.collection("bank_sync_signals").doc(itemId).set(
              {
                hasNewTransactions: true,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
          break;
        }

        case "item/error": {
          logger.warn(`Erro reportado na conexão do item ${itemId}:`, payload.error);
          if (itemId) {
            await db.collection("connected_bank_items").doc(itemId).set(
              {
                status: "ERROR",
                error: payload.error || "UNKNOWN_ERROR",
                lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
          break;
        }

        default:
          logger.info(`Evento não tratado explicitamente: ${event}`);
      }

      // Pluggy requer retorno 200 rápido para confirmar recebimento
      res.status(200).json({ status: "success", received: true });
    } catch (err) {
      logger.error("Erro ao processar webhook Pluggy:", err);
      // Retorna 200 para evitar retentativas agressivas da Pluggy se o erro for de parser interno
      res.status(200).json({ status: "error_logged", message: err.message });
    }
  }
);
