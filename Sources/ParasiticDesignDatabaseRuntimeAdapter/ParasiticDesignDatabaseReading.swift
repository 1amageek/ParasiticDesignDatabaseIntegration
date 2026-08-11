import DesignDatabaseCore

public protocol ParasiticDesignDatabaseReading: Sendable {
    func readState(
        from snapshot: any DesignReadSnapshot,
        budget: ParasiticDatabaseReadBudget
    ) async throws -> ParasiticSnapshotState
}
