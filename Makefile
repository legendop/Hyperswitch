# = Parameters
# Override envars using -e

#
# = Common
#

# Checks two given strings for equality.
eq = $(if $(or $(1),$(2)),$(and $(findstring $(1),$(2)),\
                                $(findstring $(2),$(1))),1)


ROOT_DIR_WITH_SLASH := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
ROOT_DIR := $(realpath $(ROOT_DIR_WITH_SLASH))

#
# = Targets
#

.PHONY : \
	doc \
	fmt \
	clippy \
	test \
	audit \
	git.sync \
	build \
	push \
	shell \
	run \
	start \
	stop \
	rm \
	release


# Check a local package and all of its dependencies for errors
#
# Usage :
#	make check
check:
	cargo check


# Compile application for running on local machine
#
# Usage :
#	make build
build :
	cargo build

# Generate crates documentation from Rust sources.
#
# Usage :
#	make doc [private=(yes|no)] [open=(yes|no)] [clean=(no|yes)]

doc :
ifeq ($(clean),yes)
	@rm -rf target/doc/
endif
	cargo doc --all-features --package router \
		$(if $(call eq,$(private),no),,--document-private-items) \
		$(if $(call eq,$(open),no),,--open)

# Format Rust sources with rustfmt.
#
# Usage :
#	make fmt [dry_run=(no|yes)]

fmt :
	cargo +nightly fmt --all $(if $(call eq,$(dry_run),yes),-- --check,)

# Lint Rust sources with Clippy.
#
# Usage :
#	make clippy

clippy :
	cargo clippy --all-features --all-targets -- -D warnings

# Build the DSL crate as a WebAssembly JS library
#
# Usage :
# 	make euclid-wasm

euclid-wasm:
	wasm-pack build --target web --out-dir $(ROOT_DIR)/wasm --out-name euclid $(ROOT_DIR)/crates/euclid_wasm  -- --features dummy_connector,v1

# Run Rust tests of project.
#
# Usage :
#	make test

test :
	cargo test --all-features


# Next-generation test runner for Rust.
# cargo nextest ignores the doctests at the moment. So if you are using it locally you also have to run `cargo test --doc`.
# Usage:
# 	make nextest

nextest:
	cargo nextest run

# Run format clippy test and tests.
#
# Usage :
#	make precommit

precommit : fmt clippy test


hack:
	cargo hack check --workspace --each-feature --all-targets --exclude-features 'v2 payment_v2'


# = BIN Routing Commands
#
# Usage:
#   make bin-test          Run BIN routing unit tests
#   make bin-check         Verify compilation
#   make bin-demo-rupay    Send test RuPay BIN payment (routes to phonypay)
#   make bin-demo-visa     Send test Visa BIN payment (routes to stripe_test)
.PHONY: bin-test bin-check bin-demo-rupay bin-demo-visa

bin-test:
	cargo test --package router --lib core::payments::routing::tests

bin-check:
	cargo check -p router

bin-demo-rupay:
	@echo "=== Sending RuPay BIN Payment (602228 -> phonypay) ==="
	curl -s -X POST 'http://localhost:8080/payments' \
		-H 'Content-Type: application/json' \
		-H 'api-key: $(API_KEY)' \
		-d '{"amount":1500,"currency":"INR","payment_method":"card","payment_method_data":{"card":{"card_number":"6022280000000009","card_exp_month":"12","card_exp_year":"2030","card_cvc":"123"}},"capture_method":"automatic","confirm":true}'

bin-demo-visa:
	@echo "=== Sending Visa BIN Payment (411111 -> stripe_test) ==="
	curl -s -X POST 'http://localhost:8080/payments' \
		-H 'Content-Type: application/json' \
		-H 'api-key: $(API_KEY)' \
		-d '{"amount":2500,"currency":"USD","payment_method":"card","payment_method_data":{"card":{"card_number":"4111111111111111","card_exp_month":"12","card_exp_year":"2030","card_cvc":"123"}},"capture_method":"automatic","confirm":true}'
