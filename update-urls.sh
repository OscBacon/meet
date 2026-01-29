#!/bin/bash

# Configuration script to change URLs from localhost to leto-meet.exe.xyz
# This script will:
# 1. Backup original files
# 2. Replace all localhost URLs with your domain
# 3. Show what was changed

set -e  # Exit on error

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Meet Configuration Update Script${NC}"
echo -e "${BLUE}  Changing localhost → https://leto-meet.exe.xyz${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Configuration
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

# Update backend environment file
echo -e "${YELLOW}Updating $BACKEND_ENV...${NC}"

# Email settings
sed -i "s|DJANGO_EMAIL_LOGO_IMG=http://localhost:3000/|DJANGO_EMAIL_LOGO_IMG=https://$DOMAIN/|g" "$BACKEND_ENV"
sed -i "s|DJANGO_EMAIL_DOMAIN=localhost:3000|DJANGO_EMAIL_DOMAIN=$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|DJANGO_EMAIL_APP_BASE_URL=http://localhost:3000|DJANGO_EMAIL_APP_BASE_URL=https://$DOMAIN|g" "$BACKEND_ENV"

# Backend URL
sed -i "s|MEET_BASE_URL=\"http://localhost:8072\"|MEET_BASE_URL=\"https://$DOMAIN:8072\"|g" "$BACKEND_ENV"

# OIDC endpoints (user-facing only, keep nginx:8083 unchanged)
sed -i "s|OIDC_OP_AUTHORIZATION_ENDPOINT=http://localhost:8083|OIDC_OP_AUTHORIZATION_ENDPOINT=https://$DOMAIN:8083|g" "$BACKEND_ENV"
sed -i "s|OIDC_OP_URL=http://localhost:8083|OIDC_OP_URL=https://$DOMAIN:8083|g" "$BACKEND_ENV"

# Login/Logout redirects
sed -i "s|LOGIN_REDIRECT_URL=http://localhost:3000|LOGIN_REDIRECT_URL=https://$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|LOGIN_REDIRECT_URL_FAILURE=http://localhost:3000|LOGIN_REDIRECT_URL_FAILURE=https://$DOMAIN|g" "$BACKEND_ENV"
sed -i "s|LOGOUT_REDIRECT_URL=http://localhost:3000|LOGOUT_REDIRECT_URL=https://$DOMAIN|g" "$BACKEND_ENV"

# OIDC allowed hosts
sed -i "s|OIDC_REDIRECT_ALLOWED_HOSTS=localhost:8083,localhost:3000|OIDC_REDIRECT_ALLOWED_HOSTS=$DOMAIN:8083,$DOMAIN|g" "$BACKEND_ENV"

# Recording downloads
sed -i "s|RECORDING_DOWNLOAD_BASE_URL=http://localhost:3000/recording|RECORDING_DOWNLOAD_BASE_URL=https://$DOMAIN/recording|g" "$BACKEND_ENV"

# External API settings
sed -i "s|APPLICATION_JWT_AUDIENCE=http://localhost:8071/|APPLICATION_JWT_AUDIENCE=https://$DOMAIN:8071/|g" "$BACKEND_ENV"
sed -i "s|APPLICATION_BASE_URL=http://localhost:3000|APPLICATION_BASE_URL=https://$DOMAIN|g" "$BACKEND_ENV"

echo -e "${GREEN}✓ Backend configuration updated${NC}\n"

# Update frontend environment file
echo -e "${YELLOW}Updating $FRONTEND_ENV...${NC}"
sed -i "s|VITE_API_BASE_URL=http://localhost:8071/|VITE_API_BASE_URL=https://$DOMAIN:8071/|g" "$FRONTEND_ENV"
echo -e "${GREEN}✓ Frontend configuration updated${NC}\n"

# Update docker-compose file
echo -e "${YELLOW}Updating $COMPOSE_FILE...${NC}"

# Keycloak hostname settings
sed -i "s|--hostname-url=http://localhost:8083|--hostname-url=https://$DOMAIN:8083|g" "$COMPOSE_FILE"
sed -i "s|--hostname-admin-url=http://localhost:8083/|--hostname-admin-url=https://$DOMAIN:8083/|g" "$COMPOSE_FILE"

# Frontend build args
sed -i 's|VITE_API_BASE_URL: "http://localhost:8071"|VITE_API_BASE_URL: "https://'"$DOMAIN"':8071"|g' "$COMPOSE_FILE"

echo -e "${GREEN}✓ Docker Compose configuration updated${NC}\n"

# Show summary
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All configurations updated successfully!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review the changes:"
echo -e "     ${BLUE}git diff${NC}"
echo -e ""
echo -e "  2. Rebuild and restart services:"
echo -e "     ${BLUE}make build-frontend${NC}"
echo -e "     ${BLUE}make down && make run${NC}"
echo -e ""
echo -e "  3. Update Keycloak client settings:"
echo -e "     - URL: ${BLUE}https://$DOMAIN:8083${NC}"
echo -e "     - Login: ${BLUE}admin/admin${NC}"
echo -e "     - Add redirect URI: ${BLUE}https://$DOMAIN/*${NC}"
echo -e ""
echo -e "${YELLOW}Backups created:${NC}"
echo -e "  - $BACKEND_ENV.backup.*"
echo -e "  - $FRONTEND_ENV.backup.*"
echo -e "  - $COMPOSE_FILE.backup.*"
echo -e ""
