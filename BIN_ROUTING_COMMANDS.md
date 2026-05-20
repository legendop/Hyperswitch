# BIN Routing - Setup & Run Commands

## Prerequisites

Ensure `cargo` and `just` are on your PATH:

```bash
export PATH="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$HOME/.cargo/bin:$PATH"
```

## 1. Start Superposition (Configuration Service)

```bash
just superposition-up
just superposition-seed
```

## 2. Compile & Run the Application

```bash
cargo run
```

## 3. Verify Server is Running

```bash
curl --head --request GET 'http://localhost:8080/health'
```

## 4. Create a Merchant Account and API Key

The `/routing` endpoint requires a **merchant API key** (not the admin key). Create a merchant and an API key first.

```bash
# Create a merchant account (uses admin key)
curl -X POST 'http://localhost:8080/accounts' \
  -H 'Content-Type: application/json' \
  -H 'api-key: test_admin' \
  -d '{"merchant_id": "merchant_test_001"}'
```

Save the `default_profile` value from the response (e.g. `pro_7PdChn9ZtU2TVIjx02fw`).

```bash
# Create an API key for that merchant (uses admin key)
curl -X POST 'http://localhost:8080/api_keys/merchant_test_001' \
  -H 'Content-Type: application/json' \
  -H 'api-key: test_admin' \
  -d '{"name": "test_key", "expiration": "never"}'
```

Save the `api_key` value from the response — you'll use it as the `api-key` header below.

## 5. Create Connector Accounts

Connectors must be registered for the merchant profile before they can be used in routing rules. The local dev build includes dummy connectors (`stripe_test`, `phonypay`, `fauxpay`, `pretendpay`).

```bash
# Create stripe_test connector
curl -X POST 'http://localhost:8080/account/merchant_test_001/connectors' \
  -H 'Content-Type: application/json' \
  -H 'api-key: <your_merchant_api_key>' \
  -d '{
    "connector_name": "stripe_test",
    "connector_account_details": {"auth_type": "HeaderKey", "api_key": "test_key"},
    "test_mode": true,
    "profile_id": "<profile_id>",
    "connector_type": "payment_processor"
  }'

# Create phonypay connector
curl -X POST 'http://localhost:8080/account/merchant_test_001/connectors' \
  -H 'Content-Type: application/json' \
  -H 'api-key: <your_merchant_api_key>' \
  -d '{
    "connector_name": "phonypay",
    "connector_account_details": {"auth_type": "HeaderKey", "api_key": "test_key"},
    "test_mode": true,
    "profile_id": "<profile_id>",
    "connector_type": "payment_processor"
  }'
```

Save the `merchant_connector_id` values from each response — you'll use them in the routing rules.

## 6. Create a BIN Routing Algorithm

BIN-to-connector mappings are configured via the routing API, not hardcoded. Each rule maps a card BIN prefix to a connector with its `merchant_connector_id`. The `default` connector is used when no rule matches.

```bash
curl -X POST 'http://localhost:8080/routing' \
  -H 'Content-Type: application/json' \
  -H 'api-key: <your_merchant_api_key>' \
  -d '{
    "name": "bin_based_routing",
    "description": "Route RuPay domestic BINs to phonypay, others to stripe_test",
    "profile_id": "<profile_id>",
    "algorithm": {
      "type": "bin_routing",
      "data": {
        "rules": [
          {
            "bin_prefix": "60",
            "connector": { "connector": "phonypay", "merchant_connector_id": "<phonypay_mca_id>" }
          }
        ],
        "default": { "connector": "stripe_test", "merchant_connector_id": "<stripe_test_mca_id>" }
      }
    }
  }'
```

Save the `id` from the response (e.g. `routing_NlbPcDkXEg6nSN5F4yT1`).

### How BIN matching works

- **Exact 6-digit match**: `"602228"` matches cards whose BIN is exactly `602228`
- **Prefix match**: `"60"` matches any card whose BIN starts with `60` (covers all RuPay BINs in the 600000–609999 range)
- **Single digit**: `"4"` matches all Visa cards (BINs starting with 4)
- Rules are evaluated top-to-bottom; first match wins
- If no rule matches, the `default` connector is used
- If `default` is `null` and no rule matches, the algorithm returns no connectors (fail-open to the next routing stage)

## 7. Activate the BIN Routing Algorithm

After creating the algorithm, activate it for the profile so it's used during payment routing.

```bash
curl -X POST 'http://localhost:8080/routing/<algorithm_id>/activate' \
  -H 'Content-Type: application/json' \
  -H 'api-key: <your_merchant_api_key>' \
  -d '{"transaction_type": "payment"}'
```

## 8. Test with Card Payments

### RuPay BIN (starts with 60) — should route to phonypay

```bash
curl -X POST 'http://localhost:8080/payments' \
  -H 'Content-Type: application/json' \
  -H 'api-key: <your_merchant_api_key>' \
  -d '{
    "amount": 1500,
    "currency": "INR",
    "payment_method": "card",
    "payment_method_data": {
      "card": {
        "card_number": "6022280000000009",
        "card_exp_month": "12",
        "card_exp_year": "2030",
        "card_cvc": "123"
      }
    },
    "capture_method": "automatic",
    "confirm": true
  }'
```

Expected in response: `"connector": "phonypay"`, `"card_isin": "602228"`

### Visa BIN (no rule match) — should route to stripe_test (default)

```bash
curl -X POST 'http://localhost:8080/payments' \
  -H 'Content-Type: application/json' \
  -H 'api-key: <your_merchant_api_key>' \
  -d '{
    "amount": 2500,
    "currency": "USD",
    "payment_method": "card",
    "payment_method_data": {
      "card": {
        "card_number": "4111111111111111",
        "card_exp_month": "12",
        "card_exp_year": "2030",
        "card_cvc": "123"
      }
    },
    "capture_method": "automatic",
    "confirm": true
  }'
```

Expected in response: `"connector": "stripe_test"`, `"card_isin": "411111"`

Note: The payment may fail with "Card not supported" at the connector level because these aren't valid test cards for the dummy connectors. That's a connector-side issue — the **routing decision is correct** as shown by the `connector` and `merchant_connector_id` fields in the response.

## 9. Run Unit Tests

```bash
cargo test --package router --lib core::payments::routing::tests
```

## 10. Compilation Check (no run)

```bash
cargo check -p router
```

## 11. Stop Superposition

```bash
just superposition-down
```
