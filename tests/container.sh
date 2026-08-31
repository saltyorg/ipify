#!/usr/bin/env bash
set -Eeuo pipefail

readonly IMAGE="${IMAGE:-ipify:test}"
readonly CONTAINER_NAME="ipify-test-$$"

container_id=""
tmp_dir="$(mktemp -d)"

cleanup() {
  if [[ -n "$container_id" ]]; then
    docker rm --force "$container_id" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" != "$expected" ]]; then
    fail "$label: expected '$expected', got '$actual'"
  fi
}

assert_body() {
  local expected="$1"
  local label="$2"

  printf '%s' "$expected" >"${tmp_dir}/expected-body"
  if ! cmp --silent "${tmp_dir}/expected-body" "${tmp_dir}/response-body"; then
    printf 'Expected body for %s:\n' "$label" >&2
    od -An -tx1c "${tmp_dir}/expected-body" >&2
    printf 'Actual body for %s:\n' "$label" >&2
    od -An -tx1c "${tmp_dir}/response-body" >&2
    exit 1
  fi
}

request() {
  local path="$1"
  shift

  : >"${tmp_dir}/response-body"
  : >"${tmp_dir}/response-headers"
  RESPONSE_STATUS="$(
    curl \
      --silent \
      --show-error \
      --max-time 5 \
      --output "${tmp_dir}/response-body" \
      --dump-header "${tmp_dir}/response-headers" \
      --write-out '%{http_code}' \
      "$@" \
      "${base_url}${path}"
  )"
}

response_content_type() {
  awk '
    tolower($0) ~ /^content-type:/ {
      sub(/\r$/, "")
      sub(/^[^:]+:[[:space:]]*/, "")
      print
      exit
    }
  ' "${tmp_dir}/response-headers"
}

docker build --pull --tag "$IMAGE" .

configured_user="$(docker image inspect --format '{{.Config.User}}' "$IMAGE")"
case "$configured_user" in
  "" | "0" | "root")
    fail "image must configure a non-root user, got '$configured_user'"
    ;;
esac

configured_ports="$(docker image inspect --format '{{json .Config.ExposedPorts}}' "$IMAGE")"
assert_equal '{"80/tcp":{}}' "$configured_ports" "exposed ports"

docker run --rm --entrypoint nginx "$IMAGE" -t

container_id="$(
  docker run \
    --detach \
    --rm \
    --name "$CONTAINER_NAME" \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    --publish 127.0.0.1::80 \
    "$IMAGE"
)"

host_port="$(
  docker inspect \
    --format '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' \
    "$container_id"
)"
base_url="http://127.0.0.1:${host_port}"

ready="false"
for _ in {1..30}; do
  if curl --silent --fail --max-time 1 --output /dev/null "${base_url}/healthz"; then
    ready="true"
    break
  fi
  sleep 0.2
done
[[ "$ready" == "true" ]] || fail "container did not become ready"

healthy="false"
for _ in {1..20}; do
  health_status="$(docker inspect --format '{{.State.Health.Status}}' "$container_id")"
  case "$health_status" in
    healthy)
      healthy="true"
      break
      ;;
    unhealthy)
      fail "Docker health check reported unhealthy"
      ;;
  esac
  sleep 1
done
[[ "$healthy" == "true" ]] || fail "Docker health check did not become healthy"

request "/" --header "X-Forwarded-For: 192.0.2.10"
assert_equal "200" "$RESPONSE_STATUS" "IPv4 status"
assert_equal "text/plain" "$(response_content_type)" "IPv4 content type"
assert_body $'192.0.2.10\n' "IPv4 response"

request "/" --header "X-Forwarded-For: 2001:db8::10"
assert_equal "200" "$RESPONSE_STATUS" "IPv6 status"
assert_equal "text/plain" "$(response_content_type)" "IPv6 content type"
assert_body $'2001:db8::10\n' "IPv6 response"

request "/" --header "X-Forwarded-For: 198.51.100.20, 10.0.0.1"
assert_equal "200" "$RESPONSE_STATUS" "forwarded chain status"
assert_body $'198.51.100.20\n' "forwarded chain response"

request "/" --header "X-Forwarded-For: 192.0.2.10 invalid, 10.0.0.1"
assert_equal "200" "$RESPONSE_STATUS" "internal whitespace status"
assert_body $'192.0.2.10 invalid\n' "internal whitespace response"

request "/" --header "X-Forwarded-For:    203.0.113.30   , 10.0.0.1"
assert_equal "200" "$RESPONSE_STATUS" "whitespace status"
assert_body $'203.0.113.30\n' "whitespace response"

request "/"
assert_equal "400" "$RESPONSE_STATUS" "missing header status"

request "/" --header "X-Forwarded-For;"
assert_equal "400" "$RESPONSE_STATUS" "empty header status"

request "/healthz"
assert_equal "200" "$RESPONSE_STATUS" "health status"
assert_equal "text/plain" "$(response_content_type)" "health content type"
assert_body $'ok\n' "health response"

request "/not-found"
assert_equal "404" "$RESPONSE_STATUS" "not-found status"

docker stop --time 10 "$container_id" >/dev/null
container_id=""

printf 'All container tests passed.\n'
