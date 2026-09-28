# CodePhantom web app: Flutter web build served by nginx.
#
# Build arguments are PUBLIC configuration compiled into the JavaScript that
# every visitor downloads. Never pass secrets here (service-role keys,
# database URLs, payment secrets, peppers, signing material).
#
#   APP_ENV                staging | production
#   API_BASE_URL           https://<backend host>/api/v1   (required)
#   AUTH_REDIRECT_URL      https://<this web host>/auth/callback (optional;
#                          defaults to the serving page's own origin)
#   SCANNER_REVIEW_ACTIONS true to enable Scanner approve/reject/edit
#                          (default false while the backtest is unvalidated)


FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.47.5
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt \
 && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"


WORKDIR /app
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .


ARG APP_ENV=staging
ARG API_BASE_URL
ARG AUTH_REDIRECT_URL=
ARG SCANNER_REVIEW_ACTIONS=false
RUN deploy/web/check_build_config.sh \
 && flutter build web --release --no-web-resources-cdn \
      --dart-define=APP_ENV="${APP_ENV}" \
      --dart-define=API_BASE_URL="${API_BASE_URL}" \
      --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL}" \
      --dart-define=SCANNER_REVIEW_ACTIONS="${SCANNER_REVIEW_ACTIONS}" \
 && find build/web -name '*.map' -delete \
 && echo "${API_BASE_URL}" | sed -E 's#^(https?://[^/]+).*#\1#' > /app/api_origin


FROM nginx:1.27-alpine
COPY deploy/web/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html
COPY --from=build /app/api_origin /etc/codephantom/api_origin
COPY deploy/web/api-origin-env.sh /docker-entrypoint.d/15-codephantom-api-origin.envsh
# Railway (and most PaaS hosts) provide PORT; 8080 when run locally.
ENV PORT=8080
EXPOSE 8080
