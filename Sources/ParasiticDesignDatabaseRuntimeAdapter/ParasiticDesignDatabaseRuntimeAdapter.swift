import CircuiteFoundation
import CircuiteFoundationCrypto
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime
import Foundation
import LayoutDesignDatabaseRuntimeAdapter
import LayoutDesignDatabaseSchema
import ParasiticDesignDatabaseSchema
import PDKDesignDatabaseRuntimeAdapter
import PDKDesignDatabaseSchema

public struct ParasiticDesignDatabaseRuntimeAdapter:
    DesignDatabaseRuntimeMutationAdapter,
    Sendable
{
    public let schemaID: DesignSchemaID
    public let schemaVersion = SchemaVersion.v1
    public let adapterVersion = ParasiticDesignDatabaseSchema.adapterVersion
    public let supportedFacets: Set<DesignFacetID>

    public init() throws {
        schemaID = try ParasiticDesignDatabaseSchema.schemaID
        supportedFacets = [try ParasiticDatabaseFacet.parasitics.designFacetID]
    }

    public func contribution() throws -> DesignDatabaseRuntimeContribution {
        let bindingDigest = try ParasiticDatabaseDigesting.sha256(
            Array(ParasiticDesignDatabaseSchema.bindingManifest.utf8)
        )
        return try DesignDatabaseRuntimeContribution(
            id: DesignDatabaseRuntimeContributionID("lsi.parasitic-design-database"),
            designSchemaMember: DesignSchemaBundleMember(
                schemaID: schemaID,
                version: schemaVersion,
                canonicalDigest: bindingDigest
            ),
            bindingDigest: bindingDigest,
            entities: [try ParasiticDatabaseFacetPage.schemaEntity],
            entityRuntimes: [
                try DatabaseFrameworkRuntime.entity(ParasiticDatabaseFacetPage.self),
            ],
            mutationAdapter: self,
            physicalWriteReclaimers: [self]
        )
    }

    public func validate(
        _ segment: DesignMutationPlanSegment,
        in context: DesignDatabaseRuntimeMutationValidation
    ) async throws(DesignDatabaseRuntimeMutationAdapterError)
        -> DesignDatabaseRuntimeValidatedMutation {
        let facetID: DesignFacetID
        do {
            facetID = try ParasiticDatabaseFacet.parasitics.designFacetID
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard segment.schemaID == schemaID,
              segment.schemaVersion == schemaVersion,
              segment.adapterVersion == adapterVersion,
              segment.targetFacet == facetID else {
            throw .invalidPayload(
                reason: "The parasitic segment binding is not registered."
            )
        }
        let state: ParasiticDatabaseState
        do {
            state = try ParasiticDatabaseCanonicalCodec.decode(Data(segment.payload))
        } catch ParasiticDatabaseSchemaError.invalidParasiticIR(let errors) {
            throw .validationFailed(
                diagnostics: errors.map {
                    DesignDiagnostic(
                        code: .trusted("PARASITIC_IR_INVALID"),
                        severity: .error,
                        summary: $0
                    )
                },
                diagnosticsDigest: segment.payloadDigest
            )
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        try validateBindings(
            state,
            context: context,
            diagnosticsDigest: segment.payloadDigest
        )
        let layout: LayoutDatabaseState
        let pdk: PDKDatabaseProcessState
        do {
            layout = try await LayoutDatabaseRuntimeStateReader().read(
                expectedRoot: state.sourceLayout.sourceRootDigest,
                from: context.reads,
                budget: LayoutDatabaseReadBudget()
            )
            pdk = try await PDKDatabaseRuntimeProcessReader().read(
                expectedRoot: state.sourcePDK.sourceRootDigest,
                from: context.reads,
                budget: PDKDatabaseReadBudget()
            )
        } catch DesignDatabaseRuntimeReadError.budgetExceeded(
            let limit,
            let requested
        ) {
            throw .budgetExceeded(limit: limit, requested: requested)
        } catch {
            throw .invalidPayload(
                reason: "The exact layout or PDK source state could not be read: \(error)"
            )
        }
        guard layout.sourcePDK == state.sourcePDK else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("PARASITIC_TRANSITIVE_PDK_MISMATCH"),
                        severity: .error,
                        summary: "The parasitic PDK binding differs from the exact layout PDK binding."
                    ),
                ],
                diagnosticsDigest: segment.payloadDigest
            )
        }
        try validateCornerAndNets(
            state,
            layout: layout,
            pdk: pdk,
            diagnosticsDigest: segment.payloadDigest
        )
        let document: ParasiticDatabaseCanonicalDocument
        do {
            document = try ParasiticDatabaseCanonicalDocument(state: state)
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard document.pages.count == segment.expectedWriteCount else {
            throw .invalidPayload(
                reason: "The declared write count does not match the canonical page count."
            )
        }
        let observed: ContentDigest
        do {
            observed = try DesignMutationPlanDigest.payload(
                segment.payload,
                using: SHA256ContentDigester()
            )
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard observed == segment.payloadDigest,
              document.facetRootDigest == segment.payloadDigest else {
            throw .invalidPayload(
                reason: "The canonical parasitic payload digest does not match the segment."
            )
        }
        return DesignDatabaseRuntimeValidatedMutation(
            segmentID: segment.id,
            materializationPayload: segment.payload
        )
    }

    public func materializeValidatedMutation(
        _ validation: DesignDatabaseRuntimeValidatedMutationRecord,
        for segment: DesignMutationPlanSegment,
        in context: DesignDatabaseRuntimeMutationRestoration
    ) throws(DesignDatabaseRuntimeMutationAdapterError)
        -> any DesignDatabaseRuntimePreparedMutation {
        _ = context
        do {
            guard validation.materializationPayloadDigest
                    == validation.segmentPayloadDigest else {
                throw DesignDatabaseRuntimeMutationAdapterError.invalidPayload(
                    reason: "The validated parasitic capsule is not the canonical segment payload."
                )
            }
            let materialization = try ParasiticDatabaseCanonicalDocument
                .materializeValidated(
                    canonicalData: Data(validation.materializationPayload)
                )
            guard UInt64(materialization.pages.count) == segment.expectedWriteCount,
                  materialization.facetRootDigest == segment.payloadDigest else {
                throw DesignDatabaseRuntimeMutationAdapterError.invalidPayload(
                    reason: "The materialized parasitic pages do not match the validated segment."
                )
            }
            return ParasiticPreparedMutation(
                segmentID: validation.segmentID,
                pages: materialization.pages,
                facetRootDigest: materialization.facetRootDigest,
                changeContributionDigest: materialization.facetRootDigest
            )
        } catch let error as DesignDatabaseRuntimeMutationAdapterError {
            throw error
        } catch {
            throw .invalidPayload(
                reason: "The validated parasitic input could not be materialized: \(error)"
            )
        }
    }

    private func validateBindings(
        _ state: ParasiticDatabaseState,
        context: DesignDatabaseRuntimeMutationValidation,
        diagnosticsDigest: ContentDigest
    ) throws(DesignDatabaseRuntimeMutationAdapterError) {
        guard state.sourceLayout.sourceRevision == context.baseRevision,
              state.sourcePDK.sourceRevision == context.baseRevision else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("PARASITIC_SOURCE_REVISION_MISMATCH"),
                        severity: .error,
                        summary: "Parasitics must bind layout and PDK at the exact base revision."
                    ),
                ],
                diagnosticsDigest: diagnosticsDigest
            )
        }
        let layoutFacetID: DesignFacetID
        let pdkFacetID: DesignFacetID
        do {
            layoutFacetID = try LayoutDatabaseFacet.layout.designFacetID
            pdkFacetID = try PDKDatabaseFacet.process.designFacetID
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        let actualLayoutRoot = context.baseFacetRoots.first(where: {
            $0.facetID == layoutFacetID
        })?.digest
        let actualPDKRoot = context.baseFacetRoots.first(where: {
            $0.facetID == pdkFacetID
        })?.digest
        guard actualLayoutRoot == state.sourceLayout.sourceRootDigest,
              actualPDKRoot == state.sourcePDK.sourceRootDigest else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("PARASITIC_SOURCE_ROOT_MISMATCH"),
                        severity: .error,
                        summary: "The parasitic source roots do not match the exact base revision."
                    ),
                ],
                diagnosticsDigest: diagnosticsDigest
            )
        }
    }

    private func validateCornerAndNets(
        _ state: ParasiticDatabaseState,
        layout: LayoutDatabaseState,
        pdk: PDKDatabaseProcessState,
        diagnosticsDigest: ContentDigest
    ) throws(DesignDatabaseRuntimeMutationAdapterError) {
        var diagnostics: [DesignDiagnostic] = []
        if !pdk.corners.contains(where: {
            $0.cornerID == state.parasitics.cornerID.value
        }) {
            diagnostics.append(
                DesignDiagnostic(
                    code: .trusted("PARASITIC_PDK_CORNER_MISSING"),
                    severity: .error,
                    summary: "The parasitic corner does not resolve in the exact PDK state.",
                    detail: state.parasitics.cornerID.value
                )
            )
        }
        var layoutNetNames = Set<String>()
        for cell in layout.document.cells {
            layoutNetNames.formUnion(cell.nets.map(\.name))
        }
        for net in state.parasitics.nets where !layoutNetNames.contains(net.name.value) {
            diagnostics.append(
                DesignDiagnostic(
                    code: .trusted("PARASITIC_LAYOUT_NET_MISSING"),
                    severity: .error,
                    summary: "A parasitic net does not resolve in the exact layout state.",
                    detail: net.name.value
                )
            )
        }
        guard diagnostics.isEmpty else {
            throw .validationFailed(
                diagnostics: diagnostics,
                diagnosticsDigest: diagnosticsDigest
            )
        }
    }
}
