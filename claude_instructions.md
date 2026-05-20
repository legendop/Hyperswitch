# MISSION SPECIFICATION: BIN-BASED ROUTING ALGORITHM

## 1. CONTEXT & ARCHITECTURAL OBJECTIVE
Implement a Bank Identification Number (BIN) routing algorithm as a first-class `StaticRoutingAlgorithm` variant within Hyperswitch. This rule dynamically evaluates the first 6 digits of an incoming card number to route domestic RuPay cards to a domestic acquirer and international cards to a global acquirer.

This must integrate into the existing routing pipeline as a proper algorithm — not a post-routing override — preserving `merchant_connector_id`, eligibility analysis, and the full connector selection flow.

---

## 2. STRICT CODE QUALITY & COMPLIANCE GUARDRAILS
* **Fail-Open Pattern:** If card objects or card numbers are absent, short, or unparseable, the algorithm returns the configured `default` connector. If no default exists, returns an empty list (fail-open to the next routing stage). Transactions must never be blocked.
* **Zero Panic Risk:** No `.unwrap()`, `.expect()`, or unhandled index slices. All optional values and string slicing use explicit pattern matching and boundary checks.
* **No Hardcoded Connector Mappings:** BIN-to-connector rules are configured via the API and stored in the database, not hardcoded in Rust match arms.
* **PII Compliance Guardrail:** Log ONLY the extracted 6-digit BIN prefix. NEVER log the raw card number string.

---

## 3. PATH-SPECIFIC EXECUTION MATRIX

### PHASE 1: CODEBASE RECONNAISSANCE
* Locate the `StaticRoutingAlgorithm` enum in `crates/api_models/src/routing.rs`
* Trace how `CachedAlgorithm` dispatches in `crates/router/src/core/payments/routing.rs`
* Understand how `backend_input.payment.card_bin` is populated by `make_dsl_input()`
* Identify how `RoutableConnectorChoice` carries `merchant_connector_id`

### PHASE 2: IMPLEMENTATION
* Add `BinRoutingConfig` and `BinRoutingRule` structs to `crates/api_models/src/routing.rs`
* Add `StaticRoutingAlgorithm::BinRouting(BinRoutingConfig)` variant
* Add `CachedAlgorithm::BinRouting` and `perform_bin_routing()` to the routing pipeline
* Wire up dispatch arms in `static_routing_v1`, `perform_static_routing_v1`, `refresh_routing_cache_v1`, `perform_session_routing_for_pm_type`
* Add `BinRouting` handling in `helpers.rs` and `utils.rs`
* Skip Decision Engine sync for `BinRouting` (it's handled natively)
* Map `BinRouting` to `RoutingAlgorithmKind::Advanced` to avoid a DB migration

### PHASE 3: TESTING
* Add unit tests for `perform_bin_routing()`: matched BIN, prefix match, unmatched BIN (default), no card_bin (default), no default (empty), short BIN (default)
