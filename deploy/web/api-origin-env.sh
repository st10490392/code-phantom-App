# Sourced by the nginx image entrypoint before templates are rendered:
# exposes the backend origin baked in at build time for the CSP.
API_ORIGIN="$(cat /etc/codephantom/api_origin)"
export API_ORIGIN
