# Nexus — iOS Banking App Features

## 🏦 Core Features

### Card Management
- **Card Dashboard** – View all cards (debit/credit) with last 4 digits, card art, and status indicators (active, frozen, expired)
- **Card Controls** – Freeze/unfreeze cards instantly, report lost/stolen, request replacement
- **PIN Management** – View PIN (biometric protected), change/reset PIN with verification
- **Card Personalization** – Customize card color/design/theme for virtual cards

### Balance & Transactions
- **Real-Time Balances** – Display current balance, available balance, and credit limits
- **Transaction History** – List of recent and pending transactions with date, merchant, amount, and category
- **Search & Filter** – Filter transactions by date range, category, amount, or status (pending/cleared)
- **Transaction Details** – Deep view showing merchant info, location, and transaction ID

### Payments
- **Credit Card Payments** – Pay minimum, full balance, or custom amount from linked account
- **Payment Confirmation** – Confirmation screens with transaction receipts

---

## 🔒 Security Features

- **Biometric Authentication** – Face ID / Touch ID for login and sensitive actions (view PIN, approve payments)
- **App Lock** – Auto-lock when backgrounded, requiring re-authentication
- **Session Timeout** – Auto-logout after inactivity (e.g., 2 minutes)
- **Secure PIN Entry** – Custom numeric keypad with obfuscation

---

## 📱 iOS-Specific Integrations

- **Apple Pay Provisioning** – "Add to Apple Wallet" button using `PKAddPaymentPassViewController` (In-App Provisioning)
- **Apple Wallet Issuer Extension** – Discover and add cards from Wallet app (extension target)
- **Biometric Login** – Native Face ID/Touch ID authentication

---

## 🛡️ Controls & Alerts

- **Spending Limits** – Set daily/weekly/monthly spending limits per card
- **Real-Time Alerts** – Push notifications for transactions, large purchases, low balance (simulated with `simctl push`)

---

## 📊 Insights & Tools

- **Virtual Card Numbers** – Generate virtual card numbers for online purchases
- **Card Replacement Tracking** – Track status of replacement card requests

---

## 🎨 UX/UI Features

- **Dark/Light Mode Support** – Full iOS appearance support
- **Haptic Feedback** – Feedback for key actions (payments, card controls)
- **Accessibility** – Dynamic Type, VoiceOver support
- **Card Swipe/Carousel** – Swipeable card carousel on dashboard

---

## 📝 Demo-Specific Features

- **Mock Data** – Pre-populated transactions, cards, and balances for demonstration
- **Simulated Network Calls** – Show loading states, success/error states without real backend
- **State Persistence** – Demo state is in-memory with a reset-to-default action (no network/Keychain/disk in `-demoMode`). Durable live-mode persistence is SwiftData; credentials live in Keychain. Scope conflict resolved in `ROADMAP.md` §5 — architecture.md wins.
- **Reset Demo** – Reset all data to default state for repeated demonstrations

---
