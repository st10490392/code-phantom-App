#!/bin/sh
# Refuses to build the web app with unsafe or missing public configuration.
set -eu
case "${APP_ENV:-}" in
  staging|production) ;;
  *) echo "APP_ENV must be staging or production (got '${APP_ENV:-}')" >&2; exit 1 ;;
esac
case "${API_BASE_URL:-}" in
  https://*/api/v1) ;;
  *) echo "API_BASE_URL must be https://<backend host>/api/v1" >&2; exit 1 ;;
esac
if [ -n "${AUTH_REDIRECT_URL:-}" ]; then
  case "$AUTH_REDIRECT_URL" in
    https://*/auth/callback) ;;
    *) echo "AUTH_REDIRECT_URL must be https://<web host>/auth/callback" >&2; exit 1 ;;
  esac
fi
case "${SCANNER_REVIEW_ACTIONS:-false}" in
  true|false) ;;
  *) echo "SCANNER_REVIEW_ACTIONS must be true or false" >&2; exit 1 ;;
esac
# Staging and production must not point at each other's backend.
case "$APP_ENV:$API_BASE_URL" in
  production:*staging*) echo "A production web build cannot use a staging API_BASE_URL" >&2; exit 1 ;;
  staging:*) case "$API_BASE_URL" in *staging*|*stage*) ;; *) echo "A staging web build must use a staging API_BASE_URL" >&2; exit 1 ;; esac ;;
esac
echo "Web build config OK: APP_ENV=$APP_ENV API_BASE_URL=$API_BASE_URL"
