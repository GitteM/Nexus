#if DEBUG
    import Entities
    import RepositoryProtocols

    /// In-memory `CardActionRepositoryProtocol` double shared by previews,
    /// model tests, and demo mode.
    ///
    /// The mock records every executed `CardCommand` so model tests can
    /// assert what the UI asked the backend to do (`executedCommands`,
    /// `executeCallCount`). The resulting state change is *not* applied
    /// here: in the live architecture the new state arrives back on the
    /// per-card event channel through the status repository, so a mock
    /// action repository that silently mutated status would model a backend
    /// that does not exist. Demo/test wiring that needs the follow-up state
    /// pushes it through `MockStatusRepository.publish`.
    ///
    /// The `onExecute` hook is the concrete seam for that pairing: demo
    /// wiring (and tests that want the full round trip) installs a closure
    /// that pushes the follow-up state through the shared store graph — see
    /// `MockCommandCoordinator`. The hook fires only on a successful
    /// `execute`, so a failing command never echoes state.
    ///
    /// Failure knobs: `shouldThrowError` throws `thrownError` (default
    /// `.cardActionFailed` — the model's action-error state),
    /// `shouldNeverComplete` parks the call forever (loading state).
    @MainActor
    public final class MockActionRepository: CardActionRepositoryProtocol {
        public var shouldThrowError = false
        public var shouldNeverComplete = false
        /// Error thrown when `shouldThrowError` is set; defaults to the
        /// action-rejected case a command execution surfaces.
        public var thrownError: AppError = .cardActionFailed(action: "cardAction")

        /// Called after a successful `execute` with the command that ran.
        /// The repository itself stays a pure recorder — this is the hook
        /// demo/test composition uses to publish the backend's follow-up
        /// state.
        public var onExecute: (@MainActor (CardCommand) -> Void)?

        public private(set) var executeCallCount = 0
        /// Commands passed to `execute`, oldest first.
        public private(set) var executedCommands: [CardCommand] = []

        public init() {}

        /// The most recently executed command, for one-line assertions.
        public var lastCommand: CardCommand? {
            executedCommands.last
        }

        public func execute(_ command: CardCommand) async throws {
            executeCallCount += 1
            executedCommands.append(command)
            try await checkFailureMode()
            onExecute?(command)
        }

        private func checkFailureMode() async throws {
            if shouldNeverComplete {
                // Park the call like a request that never gets an answer.
                // Sleeping on a practically infinite interval (UInt64.max
                // nanoseconds ≈ 584 years) also mirrors a real transport:
                // cancelling the caller's task throws CancellationError and
                // the mock call ends instead of leaking.
                try await Task.sleep(nanoseconds: UInt64.max)
            }
            if shouldThrowError {
                throw thrownError
            }
        }
    }
#endif
