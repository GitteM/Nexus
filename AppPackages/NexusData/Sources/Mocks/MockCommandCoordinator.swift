#if DEBUG
    import Entities

    /// Plays the backend's command echo for demo mode and tests.
    ///
    /// The live contract: a `CardCommand` is sent on `card.commands`, the
    /// backend applies it, and the resulting state returns on
    /// `card.events.{cardId}` — the action repository itself never mutates
    /// the status store (see `MockActionRepository`). Something has to stand
    /// in for that backend in demo mode and in tests that need the full
    /// round trip; this coordinator is that stand-in, installed once at the
    /// composition root (and in tests) on top of the shared mock store
    /// graph:
    ///
    /// - `.freeze` / `.unfreeze` / `.reportLost` / `.reportStolen` update
    ///   the stored `Card` *and* publish the resulting `CardState` through
    ///   `MockStatusRepository.publish` — the same path demo/test wiring
    ///   uses, so every live subscription (dashboard and detail) reconciles
    ///   and a reload keeps the state.
    /// - `.setSpendingLimit` persists the new amount onto the stored `Card`
    ///   so `getCards` reflects it after a reload (the per-period ledger
    ///   itself lives in the screen model for the session).
    /// - `.requestReplacement` publishes a replacement `CardOffer` into the
    ///   offers store; the dashboard's offer→card add path turns it into a
    ///   managed card. The old card stays `lost`.
    ///
    /// Commands arrive through `MockActionRepository.onExecute`, which fires
    /// only after a successful `execute` — the failure knobs throw first, so
    /// a rejected command never echoes state.
    @MainActor
    public final class MockCommandCoordinator {
        private let actionRepository: MockActionRepository
        private let cardRepository: MockCardRepository
        private let statusRepository: MockStatusRepository
        private let offersRepository: MockOffersRepository
        private var isStarted = false

        public init(
            actionRepository: MockActionRepository,
            cardRepository: MockCardRepository,
            statusRepository: MockStatusRepository,
            offersRepository: MockOffersRepository,
        ) {
            self.actionRepository = actionRepository
            self.cardRepository = cardRepository
            self.statusRepository = statusRepository
            self.offersRepository = offersRepository
        }

        /// Installs the command hook. Idempotent: repeated calls keep one
        /// subscription.
        public func start() {
            guard !isStarted else { return }
            isStarted = true
            actionRepository.onExecute = { [weak self] command in
                self?.apply(command)
            }
        }

        private func apply(_ command: CardCommand) {
            switch command.type {
            case .freeze:
                reflectStatus(.frozen, for: command)
            case .unfreeze:
                reflectStatus(.active, for: command)
            case .reportLost, .reportStolen:
                reflectStatus(.lost, for: command)
            case .setSpendingLimit:
                guard let amount = command.amount else { return }
                guard let index = cardRepository.cards.firstIndex(where: { $0.id == command.cardId }) else {
                    return
                }
                let card = cardRepository.cards[index]
                cardRepository.updateCard(
                    Card(
                        id: card.id,
                        cardholderName: card.cardholderName,
                        lastFourDigits: card.lastFourDigits,
                        type: card.type,
                        status: card.status,
                        currency: card.currency,
                        spendingLimit: amount,
                    ),
                )
            case .requestReplacement:
                offerReplacement(for: command.cardId)
            case .unknown:
                break
            }
        }

        /// The status-command echo: persist onto the stored card and push
        /// the frame to every live subscriber of the card's channel.
        private func reflectStatus(_ status: CardStatus, for command: CardCommand) {
            guard let index = cardRepository.cards.firstIndex(where: { $0.id == command.cardId }) else {
                return
            }
            let card = cardRepository.cards[index]
            cardRepository.updateCard(card.withStatus(status))
            statusRepository.publish(CardState(cardId: command.cardId, status: status))
        }

        /// The replacement echo: the backend mints a new offer for the lost
        /// card (its type and currency) and pushes a new `card.offers`
        /// snapshot. Duplicate requests are no-ops — the offer already
        /// exists.
        private func offerReplacement(for cardID: String) {
            guard let card = cardRepository.cards.first(where: { $0.id == cardID }) else {
                return
            }
            let offerID = "offer-replacement-\(cardID)"
            guard !offersRepository.offers.contains(where: { $0.id == offerID }) else {
                return
            }
            let numberTail = card.lastFourDigits.isEmpty ? "" : " ending \(card.lastFourDigits)"
            let offer = CardOffer(
                id: offerID,
                title: "Replacement Card",
                subtitle: "Replacement for your \(card.type.displayName.lowercased())\(numberTail)",
                type: card.type,
                currency: card.currency,
                annualFee: nil,
                benefits: ["Replaces your lost card"],
            )
            offersRepository.publish([offer] + offersRepository.offers)
        }
    }
#endif
