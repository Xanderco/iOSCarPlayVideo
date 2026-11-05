# DashCast — convenience targets. CI and the Mac agent both use `make verify`.
.PHONY: verify verify-fast test-unit test-ui generate clean

verify:            ## Everything: build, unit, network, StoreKit, CarPlay, UI tests, coverage
	Scripts/verify-all.sh

verify-fast:       ## Same without UI tests (local loop only; not Definition of Done)
	Scripts/verify-all.sh --skip-ui

test-unit:
	Scripts/verify-all.sh --only unit,network,storekit,carplay

test-ui:
	Scripts/verify-all.sh --only ui

generate:
	xcodegen generate

clean:
	rm -rf build DashCast.xcodeproj
