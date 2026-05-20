# DECISIONS.md

## 1. Scope & Implementation Details
- Implemented `BinRouting` as a first-class `StaticRoutingAlgorithm` variant that integrates into the normal routing pipeline
- BIN-to-connector mappings are fully configurable via the API — not hardcoded in Rust match arms
- `perform_bin_routing()` extracts `card_bin` from `backend_input.payment.card_bin` (already populated by `make_dsl_input()`)
- Logs only the BIN prefix slice via `[BIN_ROUTER]` — never the full card number

## 2. Pragmatic Engineering Trade-offs
- **Algorithm vs. Post-Routing Filter:** Chose a new algorithm variant over a post-routing connector reorder. A filter would discard the routing pipeline's connector selection and lose `merchant_connector_id`. An algorithm runs within the pipeline, preserving all guarantees.
- **Reuse `RoutingAlgorithmKind::Advanced`:** Mapping `BinRouting` to `Advanced` avoids a PostgreSQL enum migration (new DB enum variant). The JSON `"type"` tag differentiates them at the application layer.
- **Skip Decision Engine Sync:** `BinRouting` is handled natively by Hyperswitch. The Decision Engine (Euclid DE) doesn't understand BIN routing, so it's skipped during DE sync — same pattern as `ThreeDsDecisionRule`.

## 3. Future Polish
- **Multiple BIN ranges:** Add support for BIN range patterns (e.g., `"600000-609999"`) instead of just prefix matching
- **Card network detection:** Auto-populate rules based on card network (RuPay, Visa, Mastercard) instead of manual BIN prefixes
- **Admin UI:** Visual editor for BIN routing rules in the merchant dashboard
