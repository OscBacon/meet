#!/bin/bash

# Configuration script to change URLs for nginx reverse proxy setup
# This configures path-based routing instead of port-based routing

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Meet Nginx Proxy Configuration Script${NC}"
echo -e "${BLUE}  Setting up path-based routing for leto-meet.exe.xyz${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

DOMAIN="leto-meet.exe.xyz"
BACKEND_ENV="env.d/development/common"
FRONTEND_ENV="src/frontend/.env.development"
COMPOSE_FILE="compose.yml"

# Create backups
echo -e "${YELLOW}Creating backups...${NC}"
cp "$BACKEND_ENV" "$BACKEND_ENV.backup.$(date +%Y%m%d_%H%M%S)"
cp "$FRONTEND_ENV" "$FRONTEND_ENV.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$COMPOSE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓ Backups created${NC}\n"

echo -e "${YELLOW}Updating $BACKEND_ENV for nginx proxy...${NC}"

# Email settings
sed -i "s|DJANGO_EMAIL_LOGO_IMG=.*|DJANGO_EMAIL_LOGO_IMG=https://$DOMAIN/assets/logo-suite-numerique.png|g" "$BACKEND_ENV"
sed -i "s|DJANGO_EMAIL_DOMAIN=.*|DJANGO_EMAIL_DOMAIN=$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|DJANGO_EMAIL_APP_BASE_URL=.*|DJANGO_EMAIL_APP_BASE_URL=https://$DOMAIN|g" "$BACKEND_ENV"

# Backend URL (no port, uses /api path)
sed -i "s|MEET_BASE_URL=.*|MEET_BASE_URL=\"https://$DOMAIN\"|g" "$BACKEND_ENV"

# OIDC endpoints (uses /auth path)
sed -i "s|OIDC_OP_AUTHORIZATION_ENDPOINT=.*|OIDC_OP_AUTHORIZATION_ENDPOINT=https://$DOMAIN/auth/realms/meet/protocol/openid-connect/auth|g" "$BACKEND_ENV"
sed -i "s|OIDC_OP_URL=.*|OIDC_OP_URL=https://$DOMAIN/auth/realms/meet|g" "$BACKEND_ENV"

# Login/Logout redirects
sed -i "s|LOGIN_REDIRECT_URL=.*|LOGIN_REDIRECT_URL=https://$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|LOGIN_REDIRECT_URL_FAILURE=.*|LOGIN_REDIRECT_URL_FAILURE=https://$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|LOGOUT_REDIRECT_URL=.*|LOGOUT_REDIRECT_URL=https://$DOMAIN|g" "$BACKEND_ENV"

# OIDC allowed hosts (no ports needed)
sed -i "s|OIDC_REDIRECT_ALLOWED_HOSTS=.*|OIDC_REDIRECT_ALLOWED_HOSTS=$DOMAIN|g" "$BACKEND_ENV"

# CSRF trusted origins (no ports needed)
sed -i "s|DJANGO_CSRF_TRUSTED_ORIGINS=.*|DJANGO_CSRF_TRUSTED_ORIGINS=https://$DOMAIN|g" "$BACKEND_ENV"

# Recording downloads
sed -i "s|RECORDING_DOWNLOAD_BASE_URL=.*|RECORDING_DOWNLOAD_BASE_URL=https://$DOMAIN/recording|g" "$BACKEND_ENV"

# External API settings (uses /api path)
sed -i "s|APPLICATION_JWT_AUDIENCE=.*|APPLICATION_JWT_AUDIENCE=https://$DOMAIN/api/external-api/v1.0/|g" "$BACKEND_ENV"
sed -i "s|APPLICATION_BASE_URL=.*|APPLICATION_BASE_URL=https://$DOMAIN|g" "$BACKEND_ENV"

# LiveKit URL (uses /livekit path)
sed -i "s|LIVEKIT_API_URL=.*|LIVEKIT_API_URL=https://$DOMAIN/livekit|g" "$BACKEND_ENV"

echo -e "${GREEN}✓ Backend configuration updated${NC}\n"

# Update frontend environment file
echo -e "${YELLOW}Updating $FRONTEND_ENV...${NC}"
sed -i "s|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=https://$DOMAIN/api/|g" "$FRONTEND_ENV"
echo -e "${GREEN}✓ Frontend configuration updated${NC}\n"

# Update docker-compose file
echo -e "${YELLOW}Updating $COMPOSE_FILE...${NC}"

# Keycloak hostname (uses /auth path)
sed -i "s|--hostname-url=.*|--hostname-url=https://$DOMAIN/auth|g" "$COMPOSE_FILE"
sed -i "s|--hostname-admin-url=.*|--hostname-admin-url=https://$DOMAIN/auth/|g" "$COMPOSE_FILE"

# Frontend build args
sed -i 's|VITE_API_BASE_URL: ".*"|VITE_API_BASE_URL: "https://'"$DOMAIN"'/api/"|g' "$COMPOSE_FILE"

echo -e "${GREEN}✓ Docker Compose configuration updated${NC}\n"

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Configuration updated for nginx reverse proxy!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}URL Structure:${NC}"
echo -e "  Frontend:  ${BLUE}https://$DOMAIN/${NC}"
echo -e "  Backend:   ${BLUE}https://$DOMAIN/api/${NC}"
echo -e "  Keycloak:  ${BLUE}https://$DOMAIN/auth/${NC}"
echo -e "  LiveKit:   ${BLUE}https://$DOMAIN/livekit/${NC}"
echo -e ""

echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Setup nginx (see nginx-setup-guide.md)"
echo -e "  2. Configure SSL certificates"
echo -e "  3. Rebuild frontend:"
echo -e "     ${BLUE}make build-frontend${NC}"
echo -e "  4. Restart services:"
echo -e "     ${BLUE}make down && make run${NC}"
echo -e "  5. Update Keycloak client redirect URIs to:"
echo -e "     ${BLUE}https://$DOMAIN/*${NC}"
echo -e ""
