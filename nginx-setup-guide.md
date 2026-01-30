# Nginx Reverse Proxy Setup Guide

This guide helps you set up nginx as a reverse proxy for Meet, serving all services under `https://leto-meet.exe.xyz` with path-based routing.

## Architecture

Instead of accessing services via different ports:
- ~~https://leto-meet.exe.xyz:3000~~ (frontend)
- ~~https://leto-meet.exe.xyz:8071~~ (backend)
- ~~https://leto-meet.exe.xyz:8083~~ (keycloak)

Everything is served under the main domain:
- `https://leto-meet.exe.xyz/` → Frontend
- `https://leto-meet.exe.xyz/api/` → Backend API
- `https://leto-meet.exe.xyz/auth/` → Keycloak
- `https://leto-meet.exe.xyz/livekit/` → LiveKit WebRTC

## Prerequisites

- Nginx installed on your server
- SSL certificates for `leto-meet.exe.xyz`
- Docker services running on localhost ports

## Step 1: Install Nginx

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# Check nginx is running
sudo systemctl status nginx
```

## Step 2: Obtain SSL Certificates

### Option A: Let's Encrypt (Recommended for production)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d leto-meet.exe.xyz

# Certbot will automatically configure nginx
```

### Option B: Self-signed certificates (Development only)

```bash
# Create directory for certificates
sudo mkdir -p /etc/ssl/private

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/leto-meet.exe.xyz.key \
  -out /etc/ssl/certs/leto-meet.exe.xyz.crt \
  -subj "/CN=leto-meet.exe.xyz"

# Set permissions
sudo chmod 600 /etc/ssl/private/leto-meet.exe.xyz.key
```

## Step 3: Configure Nginx

```bash
# Copy the provided config
sudo cp nginx-proxy.conf /etc/nginx/sites-available/meet

# Update SSL certificate paths in the config if needed
sudo nano /etc/nginx/sites-available/meet

# Remove existing symlink if it exists (prevents ln errors)
sudo rm -f /etc/nginx/sites-enabled/meet

# Enable the site
sudo ln -s /etc/nginx/sites-available/meet /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx
```

## Step 4: Update Meet Configuration

```bash
# Run the URL update script
chmod +x update-urls-nginx.sh
./update-urls-nginx.sh

# Rebuild frontend with new API URLs
make build-frontend

# Restart all services
make down
make run
```

## Step 5: Update Keycloak Client Settings

1. Access Keycloak admin: `https://leto-meet.exe.xyz/auth`
2. Login with: `admin` / `admin`
3. Navigate to: **Realms → meet → Clients → meet**
4. Update these settings:
   - **Root URL**: `https://leto-meet.exe.xyz`
   - **Valid Redirect URIs**: `https://leto-meet.exe.xyz/*`
   - **Web Origins**: `https://leto-meet.exe.xyz`
   - **Admin URL**: `https://leto-meet.exe.xyz`
5. Click **Save**

## Step 6: Update LiveKit Configuration (if needed)

If LiveKit needs to know its public URL, update `docker/livekit/config/livekit-server.yaml`:

```yaml
port: 7880
rtc:
  # Use public HTTPS URL
  use_external_ip: true
  # If behind nginx, configure TURN servers appropriately
```

## Verification

Test each service:

```bash
# Frontend
curl -I https://leto-meet.exe.xyz/

# Backend API
curl -I https://leto-meet.exe.xyz/api/v1.0/config/

# Keycloak
curl -I https://leto-meet.exe.xyz/auth/

# LiveKit (may return 404 if endpoint doesn't exist, that's ok)
curl -I https://leto-meet.exe.xyz/livekit/
```

Expected response: `HTTP/2 200` or similar (not connection refused)

## Troubleshooting

### 502 Bad Gateway
- Check services are running: `docker compose ps`
- Check nginx can reach localhost ports
- Check nginx error log: `sudo tail -f /var/log/nginx/error.log`

### Certificate Errors
- Verify certificate paths in `/etc/nginx/sites-available/meet`
- Check certificate validity: `sudo openssl x509 -in /etc/ssl/certs/leto-meet.exe.xyz.crt -text -noout`

### CORS Errors
- Verify `DJANGO_CSRF_TRUSTED_ORIGINS` in `env.d/development/common`
- Check `X-Forwarded-Proto` header is set in nginx config
- Check Django logs: `make logs`

### Keycloak Redirect Errors
- Verify Keycloak client redirect URIs match `https://leto-meet.exe.xyz/*`
- Check `--hostname-url` in `compose.yml` is set to `https://leto-meet.exe.xyz/auth`

### WebSocket Connection Issues (LiveKit)
- Verify nginx has WebSocket support (Upgrade/Connection headers)
- Check LiveKit logs for connection issues
- Ensure firewall allows WebSocket connections

## Firewall Configuration

Only port 443 (HTTPS) and 80 (HTTP redirect) need to be open:

```bash
# Using UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Services on localhost ports (3000, 8071, 8083, 7880)
# should NOT be exposed to the internet
```

## Monitoring

Check nginx access logs:
```bash
sudo tail -f /var/log/nginx/access.log
```

Check nginx error logs:
```bash
sudo tail -f /var/log/nginx/error.log
```

## SSL Certificate Renewal (Let's Encrypt)

Certbot automatically renews certificates. Test renewal:

```bash
sudo certbot renew --dry-run
```

## Alternative: Using Docker Nginx

If you prefer running nginx in Docker, create a `docker-compose.override.yml`:

```yaml
services:
  nginx-proxy:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/ssl/certs/leto-meet.exe.xyz.crt:/etc/ssl/certs/leto-meet.exe.xyz.crt:ro
      - /etc/ssl/private/leto-meet.exe.xyz.key:/etc/ssl/private/leto-meet.exe.xyz.key:ro
      - ./data/static:/data/static:ro
      - ./data/media:/data/media:ro
    depends_on:
      - frontend
      - app-dev
      - keycloak
      - livekit
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Then update `nginx-proxy.conf` to use `host.docker.internal` instead of `localhost` for upstream servers.

## Complete Setup Summary

```bash
# 1. Get SSL certificates
sudo certbot --nginx -d leto-meet.exe.xyz

# 2. Setup nginx
sudo cp nginx-proxy.conf /etc/nginx/sites-available/meet
sudo rm -f /etc/nginx/sites-enabled/meet
sudo ln -s /etc/nginx/sites-available/meet /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 3. Update Meet URLs
./update-urls-nginx.sh

# 4. Rebuild and restart
make build-frontend
make down && make run

# 5. Update Keycloak client settings (via web UI)
```

Your Meet instance should now be accessible at `https://leto-meet.exe.xyz/`!
