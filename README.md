# ParasiticDesignDatabaseIntegration

Host-only persistence integration for corner-bound canonical `ParasiticIR`.

| Product | Responsibility |
|---|---|
| `ParasiticDesignDatabaseSchema` | Canonical parasitic state, source bindings, validation, and paging |
| `ParasiticDesignDatabaseRuntimeAdapter` | Exact-base import planning and bounded snapshot reads |

PEX execution reports remain evidence produced by the flow runtime. Canonical parasitic
state records the exact PDK and layout roots that produced it; mismatched bindings fail
closed and publish no candidate.

## Verification

```bash
swift build --build-tests -j 4 \
  -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types
```
