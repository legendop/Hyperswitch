# SPEC.md: BIN-Based Routing Algorithm

## Objective
Route Indian domestic RuPay cards to a domestic acquirer and international cards to a global acquirer by evaluating the card's 6-digit Bank Identification Number (BIN) through a configurable routing algorithm.

## Architecture
BIN routing is a new `StaticRoutingAlgorithm::BinRouting` variant that participates in the normal routing pipeline — same level as `Priority`, `VolumeSplit`, or `Advanced`. It is NOT a post-routing filter or override.

### Data Model
```json
{
  "type": "bin_routing",
  "data": {
    "rules": [
      { "bin_prefix": "60", "connector": { "connector": "phonypay", "merchant_connector_id": "mca_xxx" } }
    ],
    "default": { "connector": "stripe_test", "merchant_connector_id": "mca_yyy" }
  }
}
```

### Flow
1. Merchant creates a `BinRouting` algorithm via `POST /routing`
2. Algorithm is stored in DB as JSON blob, kind = `advanced` (no DB migration needed)
3. On payment, `perform_bin_routing()` extracts `card_bin` from `backend_input`
4. Matches against configured rules (prefix match, top-to-bottom)
5. Returns matching `RoutableConnectorChoice` (with `merchant_connector_id`) or default
6. Result flows through normal eligibility analysis

## Guardrails
1. **PII Security:** Only the 6-digit BIN prefix is logged, never the full card number
2. **Fail-Open:** Missing/short BIN returns default connector; no default returns empty list
3. **Configurable:** BIN mappings are API-driven, not hardcoded
4. **Pipeline Integrity:** Preserves `merchant_connector_id`, runs through eligibility analysis
