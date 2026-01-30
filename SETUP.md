# Meet Application Setup Guide

Complete guide to bootstrap and run the Meet application with nginx reverse proxy.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Bootstrap](#initial-bootstrap)
3. [Basic Configuration](#basic-configuration)
4. [Nginx Setup](#nginx-setup)
5. [Running the Application](#running-the-application)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Docker**: 20.10+ with Docker Compose v2
- **Git**: For cloning the repository
- **Make**: For running build commands
- **Nginx**: For reverse proxy (we'll install this)
- **Domain**: A domain pointing to your server (e.g., `leto-meet.exe.xyz`)

### Install Docker and Docker Compose

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect

# Verify installation
docker --version
docker compose version
```

### Install Required Tools

```bash
# Install make and git
sudo apt install -y make git

# Install nginx
sudo apt install -y nginx

# Install certbot for SSL certificates
sudo apt install -y certbot python3-certbot-nginx
```

---

## Initial Bootstrap

### 1. Clone the Repository

```bash
# Clone from your fork or the original repository
git clone git@github.com:suitenumerique/meet.git
cd meet
```

### 2. Run Bootstrap

The bootstrap process will:
- Create environment configuration files from templates
- Build Docker images
- Run database migrations
- Create demo data
- Compile translations
- Build email templates

```bash
make bootstrap
```

This will take several minutes on first run. You should see output like:

```
Creating env files...
Building Docker images...
Running migrations...
Creating demo data...
✓ Bootstrap complete!
```

### 3. Verify Bootstrap

Check that Docker containers are built:

```bash
docker images | grep meet
```

You should see:
- `meet:backend-development`
- `meet:backend-production`
- `meet:frontend-development`

---

## Basic Configuration

### 1. Understand Environment Files

The bootstrap process created these files in `env.d/development/`:

- **common** - Main application settings (Django, URLs, OIDC, etc.)
- **postgresql** - Database credentials
- **kc_postgresql** - Keycloak database credentials
- **summary** - AI summary service settings (optional)
- **crowdin** - Translation service settings (optional)

### 2. Review Default Configuration

Check the default settings:

```bash
cat env.d/development/common
```

Key settings to note:
- `DJANGO_ALLOWED_HOSTS=*` - Allow all hosts (development only)
- `MEET_BASE_URL` - Backend API URL
- `LOGIN_REDIRECT_URL` - Where to redirect after login
- `OIDC_*` - Authentication settings
- `LIVEKIT_*` - Video conferencing settings

### 3. Test Basic Startup (Without Nginx)

Before setting up nginx, verify the application works on localhost:

```bash
# Start all services
make run

# Check status
make status
```

You should see containers running:
- `postgresql`
- `redis`
- `app-dev` (Django backend)
- `celery-dev`
- `keycloak`
- `frontend`
- `livekit`
- `minio` (file storage)

### 4. Test Localhost Access

Open in your browser:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8071/api/v1.0/config/
- Keycloak: http://localhost:8083

If these work, you're ready for nginx setup!

---

## Nginx Setup

### 1. Obtain SSL Certificate

#### Option A: Let's Encrypt (Production)

```bash
# Make sure your domain points to this server
# Check with: dig leto-meet.exe.xyz

# Get certificate
sudo certbot certonly --nginx -d leto-meet.exe.xyz

# Certificate will be saved to:
# - /etc/letsencrypt/live/leto-meet.exe.xyz/fullchain.pem
# - /etc/letsencrypt/live/leto-meet.exe.xyz/privkey.pem
```

#### Option B: Self-Signed Certificate (Development)

```bash
# Create certificate directory
sudo mkdir -p /etc/ssl/private

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/leto-meet.exe.xyz.key \
  -out /etc/ssl/certs/leto-meet.exe.xyz.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=Meet/CN=leto-meet.exe.xyz"

# Set proper permissions
sudo chmod 600 /etc/ssl/private/leto-meet.exe.xyz.key
sudo chmod 644 /etc/ssl/certs/leto-meet.exe.xyz.crt
```

#### Option C: HTTP Only (No SSL)

⚠️ **For local development/testing only** - Not secure for production!

If you want to test nginx setup without dealing with SSL certificates first:

```bash
# Use the HTTP-only nginx configuration
# No certificate setup needed!

# Skip to step 2 and use nginx-proxy-http.conf instead
# Then use update-urls-nginx-http.sh script (see step 3)
```

**Advantages:**
- Faster to set up (no certificates needed)
- Good for testing nginx routing
- Works on local networks without DNS

**Disadvantages:**
- ⚠️ No encryption (credentials sent in plain text)
- ⚠️ Not suitable for production
- ⚠️ Browser security warnings for modern features

### 2. Configure Nginx

**Ports Used:**
- HTTP: Port **9080** (instead of standard port 80)
- HTTPS: Port **9443** (instead of standard port 443)

Using non-standard ports avoids requiring root/sudo privileges for nginx and prevents conflicts with other web servers.

Choose the appropriate configuration based on your certificate choice:

#### For HTTPS (Let's Encrypt or Self-Signed)

**If using Let's Encrypt**, edit `nginx-proxy.conf`:

```bash
# Edit the SSL certificate paths
nano nginx-proxy.conf
```

Change these lines:
```nginx
ssl_certificate /etc/letsencrypt/live/leto-meet.exe.xyz/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/leto-meet.exe.xyz/privkey.pem;
```

**If using self-signed**, the paths in `nginx-proxy.conf` are already correct:
```nginx
ssl_certificate /etc/ssl/certs/leto-meet.exe.xyz.crt;
ssl_certificate_key /etc/ssl/private/leto-meet.exe.xyz.key;
```

Install the HTTPS configuration:

```bash
# Copy HTTPS config to nginx sites-available
sudo cp nginx-proxy.conf /etc/nginx/sites-available/meet
```

#### For HTTP Only (No SSL)

**If testing without SSL**, use the HTTP-only configuration:

```bash
# Copy HTTP-only config to nginx sites-available
sudo cp nginx-proxy-http.conf /etc/nginx/sites-available/meet
```

#### Enable Nginx Site

```bash
# Remove existing symlink if it exists (prevents ln errors)
sudo rm /etc/nginx/sites-enabled/meet

# Enable the site
sudo ln -s /etc/nginx/sites-available/meet /etc/nginx/sites-enabled/

# Disable default site
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t
```

Expected output:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

#### Reload nginx

```bash
sudo systemctl reload nginx
```

### 3. Update Application URLs

Run the appropriate URL update script based on your setup:

#### For HTTPS Setup

```bash
# Make script executable if not already
chmod +x update-urls-nginx.sh

# Run the HTTPS script
./update-urls-nginx.sh
```

This configures URLs with `https://` on port 9443:
- Frontend: `https://leto-meet.exe.xyz:9443/meet`
- Backend: `https://leto-meet.exe.xyz:9443/api/`
- Keycloak: `https://leto-meet.exe.xyz:9443/auth/`
- LiveKit: `https://leto-meet.exe.xyz:9443/livekit/`

#### For HTTP-Only Setup

```bash
# Make script executable if not already
chmod +x update-urls-nginx-http.sh

# Run the HTTP script
./update-urls-nginx-http.sh
```

This configures URLs with `http://` on port 9080 (no SSL):
- Frontend: `http://leto-meet.exe.xyz:9080/meet`
- Backend: `http://leto-meet.exe.xyz:9080/api/`
- Keycloak: `http://leto-meet.exe.xyz:9080/auth/`
- LiveKit: `http://leto-meet.exe.xyz:9080/livekit/`

**Both scripts update:**
- `env.d/development/common` - Backend URLs
- `src/frontend/.env.development` - Frontend API URL
- `compose.yml` - Keycloak and frontend build args

### 4. Rebuild Frontend with New URLs

The frontend needs to be rebuilt to use the new API URL:

```bash
make build-frontend
```

### 5. Restart All Services

```bash
# Stop everything
make down

# Start with new configuration
make run

# Check status
make status
```

### 6. Configure Keycloak Client

Keycloak needs to know about the new URLs:

1. Access Keycloak admin console: `https://leto-meet.exe.xyz:9443/auth` (or `:9080` for HTTP)
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. Navigate to: **Realms → meet → Clients → meet**
4. Update the following settings (use port 9443 for HTTPS or 9080 for HTTP):

   ```
   Root URL: https://leto-meet.exe.xyz:9443/meet
   Home URL: https://leto-meet.exe.xyz:9443/meet
   Valid Redirect URIs: https://leto-meet.exe.xyz:9443/meet/*
   Valid post logout redirect URIs: https://leto-meet.exe.xyz:9443/meet/*
   Web Origins: https://leto-meet.exe.xyz:9443
   Admin URL: https://leto-meet.exe.xyz:9443/meet
   ```

5. Click **Save**

---

## Running the Application

### Start Services

```bash
# Start all services
make run
```

This starts:
- PostgreSQL database
- Redis cache
- Django backend (port 8071)
- Celery workers
- Keycloak authentication (port 8083)
- React frontend (port 3000)
- LiveKit video server (port 7880)
- Minio file storage
- Summary service (optional)

### Stop Services

```bash
# Stop all services
make stop

# Or stop and remove containers
make down
```

### View Logs

```bash
# Follow backend logs
make logs

# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f frontend
docker compose logs -f app-dev
docker compose logs -f keycloak
```

### Common Commands

```bash
# Rebuild backend
make build-backend

# Rebuild frontend
make build-frontend

# Run database migrations
make migrate

# Create a superuser
make superuser

# Reset database with demo data
make demo

# Run backend tests
make test

# Check service status
make status
```

---

## Verification

### 1. Check Nginx

```bash
# Test nginx config
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# View nginx error logs
sudo tail -f /var/log/nginx/error.log

# View nginx access logs
sudo tail -f /var/log/nginx/access.log
```

### 2. Test Each Service

```bash
# Test frontend (should return HTML)
curl -I https://leto-meet.exe.xyz:9443/

# Test backend API (should return JSON config)
curl https://leto-meet.exe.xyz:9443/api/v1.0/config/

# Test Keycloak (should return HTML)
curl -I https://leto-meet.exe.xyz:9443/auth/

# Test health endpoints
curl https://leto-meet.exe.xyz:9443/api/__heartbeat__
```

### 3. Browser Testing

1. **Frontend**: Open `https://leto-meet.exe.xyz:9443/meet`
   - Should see the Meet login page
   - No console errors (press F12)

2. **Login Flow**: Click "Sign In"
   - Should redirect to Keycloak
   - Should redirect back after login

3. **Create a Room**:
   - Create a test room
   - Verify video/audio permissions work
   - Check WebRTC connection status

### 4. Check Docker Services

```bash
# All containers should be "Up"
docker compose ps

# Check resource usage
docker stats --no-stream
```

---

## Troubleshooting

### 502 Bad Gateway

**Problem**: Nginx returns 502 error

**Solutions**:
```bash
# Check if services are running
docker compose ps

# If not running, start them
make run

# Check if ports are listening
sudo netstat -tlnp | grep -E '3000|8071|8083|7880'

# Check nginx can reach localhost
curl http://localhost:3000
curl http://localhost:8071/api/v1.0/config/
```

### CORS / CSRF Errors

**Problem**: "CORS policy" or "CSRF" errors in browser console

**Solutions**:
```bash
# Verify CSRF trusted origins in env.d/development/common
grep CSRF_TRUSTED_ORIGINS env.d/development/common

# Should contain: DJANGO_CSRF_TRUSTED_ORIGINS=https://leto-meet.exe.xyz

# Restart backend
docker compose restart app-dev celery-dev

# Check Django settings are loaded
docker compose exec app-dev python -c "
from django.conf import settings
print('CSRF_TRUSTED_ORIGINS:', settings.CSRF_TRUSTED_ORIGINS)
print('CORS_ALLOW_ALL_ORIGINS:', settings.CORS_ALLOW_ALL_ORIGINS)
"
```

### Certificate Errors

**Problem**: Browser shows SSL certificate error

**Solutions**:

For Let's Encrypt:
```bash
# Verify certificate
sudo certbot certificates

# Renew if needed
sudo certbot renew

# Check certificate expiry
echo | openssl s_client -servername leto-meet.exe.xyz \
  -connect leto-meet.exe.xyz:9443 2>/dev/null | \
  openssl x509 -noout -dates
```

For self-signed certificates:
```bash
# Browser will show warning - this is expected
# Click "Advanced" → "Proceed to site"

# Or regenerate certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/leto-meet.exe.xyz.key \
  -out /etc/ssl/certs/leto-meet.exe.xyz.crt \
  -subj "/CN=leto-meet.exe.xyz"
```

### Keycloak Redirect Issues

**Problem**: After login, redirects to wrong URL

**Solutions**:
```bash
# Check Keycloak hostname settings in compose.yml
grep "hostname-url" compose.yml

# Should be: --hostname-url=https://leto-meet.exe.xyz/auth

# Update Keycloak client redirect URIs (see section 6 of Nginx Setup)

# Restart Keycloak
docker compose restart keycloak nginx
```

### Database Connection Issues

**Problem**: Backend can't connect to database

**Solutions**:
```bash
# Check PostgreSQL is running
docker compose ps postgresql

# Check database credentials
cat env.d/development/postgresql

# Test connection
docker compose exec postgresql psql -U dinum -d meet -c "SELECT 1;"

# Reset database
make resetdb
```

### Frontend Build Fails

**Problem**: `make build-frontend` fails

**Solutions**:
```bash
# Check frontend environment file
cat src/frontend/.env.development

# Should contain correct API URL
# VITE_API_BASE_URL=https://leto-meet.exe.xyz/api/

# Clear node modules and rebuild
docker compose run --rm node sh -c "cd src/frontend && rm -rf node_modules && npm install"
make build-frontend

# Check for port conflicts
sudo netstat -tlnp | grep 3000
```

### LiveKit WebRTC Issues

**Problem**: Video/audio not working

**Solutions**:
```bash
# Check LiveKit is running
docker compose ps livekit

# Check LiveKit logs
docker compose logs -f livekit

# Verify LiveKit URL in env.d/development/common
grep LIVEKIT_API_URL env.d/development/common

# Should be: LIVEKIT_API_URL=https://leto-meet.exe.xyz:9443/livekit

# Check firewall allows WebSocket connections
sudo ufw status
sudo ufw allow 9443/tcp
```

### Ports Already in Use

**Problem**: Can't start services, ports already bound

**Solutions**:
```bash
# Find what's using the ports
sudo netstat -tlnp | grep -E '3000|8071|8083|7880|5432'

# Kill conflicting processes or change ports in compose.yml

# For example, to use different PostgreSQL port:
# Edit compose.yml and change:
# ports:
#   - "15433:5432"  # Instead of 15432:5432
```

### View All Environment Variables

```bash
# Check backend environment
docker compose exec app-dev env | grep -E "DJANGO|MEET|OIDC|LIVEKIT"

# Check what Django sees
docker compose exec app-dev python manage.py shell -c "
from django.conf import settings
import json
print(json.dumps({
    'DEBUG': settings.DEBUG,
    'ALLOWED_HOSTS': settings.ALLOWED_HOSTS,
    'CSRF_TRUSTED_ORIGINS': settings.CSRF_TRUSTED_ORIGINS,
    'CORS_ALLOW_ALL_ORIGINS': settings.CORS_ALLOW_ALL_ORIGINS,
}, indent=2))
"
```

---

## Quick Reference

### URL Structure

| Service | External URL | Nginx Port | Internal Port |
|---------|--------------|------------|---------------|
| Nginx (HTTP) | http://leto-meet.exe.xyz:9080 | 9080 | - |
| Nginx (HTTPS) | https://leto-meet.exe.xyz:9443 | 9443 | - |
| Frontend | :9443/meet | via nginx | 3000 |
| Backend API | :9443/api/ | via nginx | 8071 |
| Keycloak | :9443/auth/ | via nginx | 8083 |
| LiveKit | :9443/livekit/ | via nginx | 7880 |

### Important Files

```
meet/
├── Makefile                      # Build and run commands
├── compose.yml                   # Docker services definition
├── nginx-proxy.conf              # Nginx HTTPS reverse proxy config
├── nginx-proxy-http.conf         # Nginx HTTP-only config (no SSL)
├── update-urls-nginx.sh          # URL configuration script (HTTPS)
├── update-urls-nginx-http.sh     # URL configuration script (HTTP)
├── SETUP.md                      # This guide
├── nginx-setup-guide.md          # Detailed nginx guide
├── env.d/development/
│   ├── common                    # Main app configuration
│   ├── postgresql                # Database credentials
│   └── kc_postgresql             # Keycloak DB credentials
├── src/
│   ├── backend/
│   │   └── meet/settings.py      # Django settings
│   └── frontend/
│       └── .env.development      # Frontend config
└── data/
    ├── media/                    # Uploaded files
    └── static/                   # Static assets
```

**Nginx Configuration Files:**
- `nginx-proxy.conf` - Use for HTTPS with SSL certificates
- `nginx-proxy-http.conf` - Use for HTTP without SSL (development/testing only)

### Essential Commands Cheatsheet

```bash
# Start everything
make run

# Stop everything
make down

# View logs
make logs

# Rebuild frontend
make build-frontend

# Rebuild backend
make build-backend

# Run migrations
make migrate

# Reset database
make resetdb

# Run tests
make test

# Check nginx
sudo nginx -t
sudo systemctl reload nginx

# View nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart specific service
docker compose restart app-dev
docker compose restart frontend
docker compose restart keycloak
```

### Default Credentials

**Django Admin** (after `make superuser`):
- URL: https://leto-meet.exe.xyz/api/admin/
- Username: `admin@example.com`
- Password: `admin`

**Keycloak Admin**:
- URL: https://leto-meet.exe.xyz/auth/
- Username: `admin`
- Password: `admin`

**PostgreSQL**:
- Host: `localhost:15432`
- Database: `meet`
- Username: `dinum`
- Password: `pass`

---

## Security Notes for Production

⚠️ **Before deploying to production**:

1. **Change default passwords**:
   ```bash
   # Update in env.d/development/common (or create production env)
   DJANGO_SUPERUSER_PASSWORD=<strong-password>
   DJANGO_SECRET_KEY=<generate-new-key>
   OIDC_RP_CLIENT_SECRET=<generate-new-secret>
   ```

2. **Use real SSL certificates** (Let's Encrypt, not self-signed)

3. **Restrict allowed hosts**:
   ```bash
   DJANGO_ALLOWED_HOSTS=leto-meet.exe.xyz
   ```

4. **Disable debug mode**:
   ```bash
   # Use Production configuration instead of Development
   DJANGO_CONFIGURATION=Production
   ```

5. **Set up firewall**:
   ```bash
   sudo ufw enable
   sudo ufw allow 9080/tcp  # HTTP
   sudo ufw allow 9443/tcp  # HTTPS
   sudo ufw allow 22/tcp    # SSH
   ```

6. **Enable HTTPS redirect** in Django (already in Production config)

7. **Regular updates**:
   ```bash
   git pull
   make build
   make migrate
   make down && make run
   ```

---

## Additional Resources

- **Main Documentation**: See README.md
- **Nginx Setup Details**: See nginx-setup-guide.md
- **Development Guide**: See CONTRIBUTING.md (if available)
- **API Documentation**: https://leto-meet.exe.xyz/api/schema/swagger-ui/

---

## Support

If you encounter issues not covered in this guide:

1. Check application logs: `make logs`
2. Check nginx logs: `sudo tail -f /var/log/nginx/error.log`
3. Check Docker logs: `docker compose logs -f <service-name>`
4. Review the troubleshooting section above
5. Check GitHub issues: https://github.com/suitenumerique/meet/issues

---

**Last Updated**: 2026-01-29
**Version**: 1.5.0
