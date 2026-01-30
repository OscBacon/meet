#!/bin/bash

# Configuration script for HTTP-only nginx setup (no SSL)
# Use this for local development or testing

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Meet HTTP-Only Nginx Configuration Script${NC}"
echo -e "${BLUE}  Setting up path-based routing WITHOUT SSL${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}⚠️  WARNING: This configures HTTP (not HTTPS)${NC}"
echo -e "${YELLOW}   Use this ONLY for local development or testing${NC}"
echo -e "${YELLOW}   For production, use update-urls-nginx.sh with SSL${NC}\n"

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

DOMAIN="leto-meet.exe.xyz"
PORT="9080"
BASE_URL="$BASE_URL:$PORT"
BACKEND_ENV="env.d/development/common"
FRONTEND_ENV="src/frontend/.env.development"
COMPOSE_FILE="compose.yml"

# Create backups
echo -e "${YELLOW}Creating backups...${NC}"
cp "$BACKEND_ENV" "$BACKEND_ENV.backup.$(date +%Y%m%d_%H%M%S)"
cp "$FRONTEND_ENV" "$FRONTEND_ENV.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$COMPOSE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓ Backups created${NC}\n"

echo -e "${YELLOW}Updating $BACKEND_ENV for HTTP nginx proxy...${NC}"

# Email settings (HTTP)
sed -i "s|DJANGO_EMAIL_LOGO_IMG=.*|DJANGO_EMAIL_LOGO_IMG=$BASE_URL/assets/logo-suite-numerique.png|g" "$BACKEND_ENV"
sed -i "s|DJANGO_EMAIL_DOMAIN=.*|DJANGO_EMAIL_DOMAIN=$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|DJANGO_EMAIL_APP_BASE_URL=.*|DJANGO_EMAIL_APP_BASE_URL=$BASE_URL/meet|g" "$BACKEND_ENV"

# Backend URL (HTTP, no port, uses /api path)
sed -i "s|MEET_BASE_URL=.*|MEET_BASE_URL=\"$BASE_URL\"|g" "$BACKEND_ENV"

# OIDC endpoints (HTTP, uses /auth path)
sed -i "s|OIDC_OP_AUTHORIZATION_ENDPOINT=.*|OIDC_OP_AUTHORIZATION_ENDPOINT=$BASE_URL/auth/realms/meet/protocol/openid-connect/auth|g" "$BACKEND_ENV"
sed -i "s|OIDC_OP_URL=.*|OIDC_OP_URL=$BASE_URL/auth/realms/meet|g" "$BACKEND_ENV"

# Login/Logout redirects (HTTP)
sed -i "s|LOGIN_REDIRECT_URL=.*|LOGIN_REDIRECT_URL=$BASE_URL/meet|g" "$BACKEND_ENV"
sed -i "s|LOGIN_REDIRECT_URL_FAILURE=.*|LOGIN_REDIRECT_URL_FAILURE=$BASE_URL/meet|g" "$BACKEND_ENV"
sed -i "s|LOGOUT_REDIRECT_URL=.*|LOGOUT_REDIRECT_URL=$BASE_URL/meet|g" "$BACKEND_ENV"

# OIDC allowed hosts (no ports needed)
sed -i "s|OIDC_REDIRECT_ALLOWED_HOSTS=.*|OIDC_REDIRECT_ALLOWED_HOSTS=$DOMAIN|g" "$BACKEND_ENV"

# CSRF trusted origins (HTTP)
sed -i "s|DJANGO_CSRF_TRUSTED_ORIGINS=.*|DJANGO_CSRF_TRUSTED_ORIGINS=$BASE_URL|g" "$BACKEND_ENV"

# Recording downloads (HTTP)
sed -i "s|RECORDING_DOWNLOAD_BASE_URL=.*|RECORDING_DOWNLOAD_BASE_URL=$BASE_URL/recording|g" "$BACKEND_ENV"

# External API settings (HTTP, uses /api path)
sed -i "s|APPLICATION_JWT_AUDIENCE=.*|APPLICATION_JWT_AUDIENCE=$BASE_URL/api/external-api/v1.0/|g" "$BACKEND_ENV"
sed -i "s|APPLICATION_BASE_URL=.*|APPLICATION_BASE_URL=$BASE_URL|g" "$BACKEND_ENV"

# LiveKit URL (HTTP, uses /livekit path)
sed -i "s|LIVEKIT_API_URL=.*|LIVEKIT_API_URL=$BASE_URL/livekit|g" "$BACKEND_ENV"

echo -e "${GREEN}✓ Backend configuration updated${NC}\n"

# Update frontend environment file
echo -e "${YELLOW}Updating $FRONTEND_ENV...${NC}"
sed -i "s|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=$BASE_URL/api/|g" "$FRONTEND_ENV"
echo -e "${GREEN}✓ Frontend configuration updated${NC}\n"

# Update docker-compose file
echo -e "${YELLOW}Updating $COMPOSE_FILE...${NC}"

# Keycloak hostname (HTTP, uses /auth path)
sed -i "s|--hostname-url=.*|--hostname-url=$BASE_URL/auth|g" "$COMPOSE_FILE"
sed -i "s|--hostname-admin-url=.*|--hostname-admin-url=$BASE_URL/auth/|g" "$COMPOSE_FILE"

# Frontend build args (HTTP)
sed -i 's|VITE_API_BASE_URL: ".*"|VITE_API_BASE_URL: "'"$BASE_URL"'/api/"|g' "$COMPOSE_FILE"

echo -e "${GREEN}✓ Docker Compose configuration updated${NC}\n"

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Configuration updated for HTTP nginx reverse proxy!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}URL Structure (HTTP):${NC}"
echo -e "  Frontend:  ${BLUE}$BASE_URL/meet${NC}"
echo -e "  Backend:   ${BLUE}$BASE_URL/api/${NC}"
echo -e "  Keycloak:  ${BLUE}$BASE_URL/auth/${NC}"
echo -e "  LiveKit:   ${BLUE}$BASE_URL/livekit/${NC}"
echo -e ""

echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Setup nginx:"
echo -e "     ${BLUE}sudo cp nginx-proxy-http.conf /etc/nginx/sites-available/meet${NC}"
echo -e "     ${BLUE}sudo rm -f /etc/nginx/sites-enabled/meet${NC}"
echo -e "     ${BLUE}sudo ln -s /etc/nginx/sites-available/meet /etc/nginx/sites-enabled/${NC}"
echo -e "     ${BLUE}sudo nginx -t && sudo systemctl reload nginx${NC}"
echo -e ""
echo -e "  2. Rebuild frontend:"
echo -e "     ${BLUE}make build-frontend${NC}"
echo -e ""
echo -e "  3. Restart services:"
echo -e "     ${BLUE}make down && make run${NC}"
echo -e ""
echo -e "  4. Update Keycloak client redirect URIs to:"
echo -e "     ${BLUE}$BASE_URL/*${NC}"
echo -e ""
echo -e "${RED}⚠️  Remember: This is HTTP only (no encryption)${NC}"
echo -e "${RED}   Not suitable for production use!${NC}"
echo -e ""
