IMAGE ?= ipify:test

.PHONY: build lint test check clean

build:
	docker build --pull --tag "$(IMAGE)" .

lint:
	shellcheck tests/*.sh

test:
	IMAGE="$(IMAGE)" ./tests/container.sh

check: lint test

clean:
	docker image rm --force "$(IMAGE)" 2>/dev/null || true
