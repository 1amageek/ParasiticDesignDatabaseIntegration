import Foundation

public enum ParasiticDatabaseCanonicalCodec {
    public static func encode(
        _ state: ParasiticDatabaseState
    ) throws(ParasiticDatabaseSchemaError) -> Data {
        try state.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(state)
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
    }

    public static func decode(
        _ data: Data,
        requireCanonicalEncoding: Bool = true
    ) throws(ParasiticDatabaseSchemaError) -> ParasiticDatabaseState {
        let state: ParasiticDatabaseState
        do {
            state = try JSONDecoder().decode(ParasiticDatabaseState.self, from: data)
        } catch {
            throw .decodingFailed(reason: String(describing: error))
        }
        try state.validate()
        if requireCanonicalEncoding {
            guard try encode(state) == data else {
                throw .nonCanonicalPayload
            }
        }
        return state
    }
}
