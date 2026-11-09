# 💰 Organizador Financeiro Multiplataforma

Aplicativo financeiro multiplataforma desenvolvido em **Flutter** para **Web / Desktop** e **Android**, com sincronização em nuvem via **Firebase**, importação de extratos bancários e captura automática de compras no crédito via notificações.

---

## 🚀 Funcionalidades Principais

### 1. 📊 Dashboard & Gestão de Finanças
- **Visão Geral**: Saldo consolidado, receitas totais, despesas do mês e saldo pendente a receber.
- **Gráficos Interativos**: Distribuição de despesas por categoria com `fl_chart`.
- **Extrato Completo**: Filtros por receitas, despesas, categorias e busca por palavra-chave.
- **Bancos Suportados**: Identificação visual e cores dedicadas para **Nubank**, **Itaú**, **Mercado Pago**, entre outros.

### 2. 🤝 "Quem me Deve" (Empréstimos & Parcelas)
- **Atribuição de Pessoas**: Cadastre quem pegou dinheiro emprestado ou dividiu uma compra.
- **Controle de Parcelas**:
  - Seleção do número total de parcelas e **parcelas restantes** que ainda faltam pagar.
  - Cálculo automático do valor de cada parcela mensal.
  - Definição do dia de vencimento mensal.
- **Amortização e Quitação**:
  - Botão de ação rápida **"Receber Parcela"**: debita 1 parcela restante, adiciona ao histórico da dívida e registra automaticamente uma receita no seu extrato.
  - Botão **"Quitar Tudo"** para quitações antecipadas integrais.
  - Ajuste rápido do contador de parcelas (+ / -).

### 3. 📄 Leitura de Extratos (Nubank, Itaú e Mercado Pago)
- **Formatos Aceitos**:
  - **.OFX (Open Financial Exchange)**: Padrão bancário oficial suportado pelo Nubank e Itaú.
  - **.CSV**: Planilhas de movimentações e faturas do Nubank e Mercado Pago.
- **Pré-visualização e Seleção**: Antes de salvar, visualize todas as transações identificadas, selecione apenas as desejadas e veja o somatório de créditos e débitos.
- **Modelos de Teste Imediato**: O app inclui botões para testar na hora com modelos reais de extrato do Nubank, Itaú e Mercado Pago.
- **Guia Passo a Passo**: Instruções integradas na tela explicando como exportar o extrato dentro de cada aplicativo bancário.

### 4. 📱 Captura Automática de Notificações (Android)
- **Serviço Nativo Android**: Implementado com `NotificationListenerService` (`FinancialNotificationListener.kt`).
- **Detecção Inteligente**:
  - Reconhece compras aprovadas, transferências Pix e pagamentos dos pacotes `com.nu.production` (Nubank), `com.itau` (Itaú) e `com.mercadopago.wallet` (Mercado Pago).
  - Extração de valores (R$) e nome do estabelecimento via regex.
- **Modo Automático**: Opção de adicionar a compra diretamente ao extrato assim que a notificação chega, ou deixar como pendente para aprovação com 1 clique.
- **Simulador Integrado**: Permite disparar simulações de compras no navegador ou no celular para testar sem precisar fazer uma compra real.

### 5. ☁️ Conexão Firebase & Modo Offline
- **Offline-First**: Funciona perfeitamente de forma local mesmo sem internet ou sem conta no Firebase (usando persistência local segura via `SharedPreferences`).
- **Cloud Firestore**: Sincronização em tempo real entre o celular e o desktop.
  - Coleção de transações: `/users/{userId}/transactions`
  - Coleção de devedores: `/users/{userId}/debts`
  - Coleção de notificações: `/users/{userId}/notifications`
- Configuração simplificada diretamente na tela de Configurações do app.

---

## 🛠️ Como Executar o Projeto

### Pré-requisitos
- Flutter SDK 3.19+ instalado.
- Android Studio ou Google Chrome para execução.

### Executar no Navegador / Desktop (Web)
```bash
# Baixar dependências
flutter pub get

# Iniciar em modo de desenvolvimento no Chrome
flutter run -d chrome

# Ou compilar a versão de produção
flutter build web --release
```

### Executar no Celular Android
```bash
# Conecte seu aparelho via USB ou inicie um emulador
flutter run -d android
```

> **Importante para Notificações no Android**:
> Ao abrir o app no celular, vá até a aba **Captura Android** e toque em **"Ativar no Android"**. O sistema abrirá a tela de **Acesso a Notificações** do Android; marque a permissão para o aplicativo.

---

## 📁 Estrutura do Código

```
lib/
├── main.dart                          # Inicialização do MultiProvider e temas
├── models/
│   ├── transaction_model.dart         # Modelo de transações e fontes (OFX, CSV, Notificação)
│   ├── debt_model.dart                # Modelo de devedores, parcelas e histórico de amortização
│   └── notification_event_model.dart  # Modelo de eventos de notificação capturados
├── services/
│   ├── storage_service.dart           # Persistência local offline
│   ├── firebase_service.dart          # Conector Cloud Firestore
│   ├── ofx_parser_service.dart        # Parser SGML/XML para extratos OFX (Nubank, Itaú)
│   ├── csv_parser_service.dart        # Parser de planilhas CSV bancárias
│   ├── notification_service.dart      # Extração regex e bridge de notificações Android
│   └── sample_data_service.dart       # Dados demonstrativos iniciais
├── providers/
│   ├── finance_provider.dart          # Gerenciamento de saldo, extrato e filtros
│   ├── debt_provider.dart             # Gerenciamento de pessoas e parcelas restantes
│   ├── notification_provider.dart     # Gerenciamento de notificações capturadas
│   └── app_state_provider.dart        # Controle de abas e tema claro/escuro
├── utils/
│   ├── currency_formatter.dart        # Formatação de moedas (pt_BR R$) e datas
│   └── constants.dart                 # Cores dos bancos, categorias e ícones
└── views/
    ├── main_layout.dart               # Layout responsivo (Sidebar no desktop / BottomNav no mobile)
    ├── dashboard/                     # Visão geral, gráficos e KPIs
    ├── transactions/                  # Extrato com busca e filtros
    ├── debts/                         # Tela "Quem me deve", parcelas e quitação
    ├── bank_import/                   # Importador de OFX/CSV com preview e modelos
    ├── notifications/                 # Status da captura Android e simulador
    └── settings/                      # Configurações do Firebase e preferências
```
