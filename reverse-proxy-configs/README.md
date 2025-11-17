# Reverse Proxy Configuration Guide

This directory contains sample configurations for popular reverse proxy servers to run AirMessage Connect behind SSL/TLS termination.

## Why use a reverse proxy?

Running AirMessage Connect behind a reverse proxy is the recommended production setup because:

1. **Simplified SSL/TLS management** - Your reverse proxy handles certificates, including automatic renewal with Let's Encrypt
2. **Better security** - Reverse proxies are battle-tested for handling HTTPS traffic
3. **Flexibility** - Easy to add rate limiting, IP filtering, or other features
4. **Multi-service hosting** - Run multiple services on the same server/domain

## Available Configurations

### 1. Nginx (nginx.conf)
**Recommended for:** High performance, most popular choice

**Installation:**
```bash
sudo apt install nginx
sudo cp nginx.conf /etc/nginx/sites-available/airmessage-connect
sudo ln -s /etc/nginx/sites-available/airmessage-connect /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 2. Apache (apache.conf)
**Recommended for:** Existing Apache users, .htaccess support

**Installation:**
```bash
sudo apt install apache2
sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers rewrite
sudo cp apache.conf /etc/apache2/sites-available/airmessage-connect.conf
sudo a2ensite airmessage-connect
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### 3. Caddy (Caddyfile)
**Recommended for:** Simplicity, automatic HTTPS with zero configuration

**Installation:**
```bash
# Install Caddy (see https://caddyserver.com/docs/install)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Add configuration to Caddyfile
sudo cat Caddyfile >> /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

## SSL Certificate Setup

### Option 1: Let's Encrypt (Recommended)

**For Nginx:**
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d airmessage.vanstek.dev
```

**For Apache:**
```bash
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d airmessage.vanstek.dev
```

**For Caddy:**
No setup needed! Caddy automatically obtains certificates from Let's Encrypt.

### Option 2: Custom Certificate

If you have your own SSL certificate:

1. Copy your certificate files to the server:
   - `fullchain.pem` - Your certificate + intermediate certificates
   - `privkey.pem` - Your private key

2. Update the paths in your chosen configuration file:
   - Nginx: `ssl_certificate` and `ssl_certificate_key`
   - Apache: `SSLCertificateFile` and `SSLCertificateKeyFile`
   - Caddy: `tls /path/to/fullchain.pem /path/to/privkey.pem`

## Testing Your Configuration

### 1. Check backend is running
```bash
curl -i http://localhost:1259
```
You should see a WebSocket upgrade response.

### 2. Test WebSocket connection
```bash
# Install websocat
cargo install websocat

# Test connection
websocat wss://airmessage.vanstek.dev
```

### 3. Browser test
Open your browser console and run:
```javascript
const ws = new WebSocket('wss://airmessage.vanstek.dev');
ws.onopen = () => console.log('Connected successfully!');
ws.onmessage = (event) => console.log('Message:', event.data);
ws.onerror = (error) => console.error('Error:', error);
ws.onclose = () => console.log('Connection closed');
```

### 4. SSL test
Check your SSL configuration:
```bash
# Test SSL certificate
openssl s_client -connect airmessage.vanstek.dev:443 -servername airmessage.vanstek.dev

# Or use online tools
# https://www.ssllabs.com/ssltest/analyze.html?d=airmessage.vanstek.dev
```

## Firewall Configuration

Make sure your firewall allows HTTPS traffic:

```bash
# For ufw (Ubuntu/Debian)
sudo ufw allow 80/tcp    # HTTP (for Let's Encrypt)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# For firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

**Important:** Port 1259 should NOT be exposed to the internet. The reverse proxy handles all external traffic.

## Monitoring

### Check reverse proxy logs

**Nginx:**
```bash
sudo tail -f /var/log/nginx/airmessage-connect-access.log
sudo tail -f /var/log/nginx/airmessage-connect-error.log
```

**Apache:**
```bash
sudo tail -f /var/log/apache2/airmessage-connect-access.log
sudo tail -f /var/log/apache2/airmessage-connect-error.log
```

**Caddy:**
```bash
sudo journalctl -u caddy -f
# Or if using file logging:
sudo tail -f /var/log/caddy/airmessage-connect.log
```

## Troubleshooting

### WebSocket upgrade fails
- Check that your reverse proxy supports WebSocket (nginx: proxy_http_version 1.1, Apache: mod_proxy_wstunnel)
- Verify `Upgrade` and `Connection` headers are being passed through
- Check backend is running: `curl http://localhost:1259`

### 502 Bad Gateway
- Backend is not running on port 1259
- Check backend logs: `tail -f logs/latest.log`
- Verify connection: `telnet localhost 1259`

### SSL certificate issues
- Certificate not found: Check file paths in config
- Certificate expired: Renew with `certbot renew`
- Certificate not trusted: Ensure you're using fullchain.pem (includes intermediates)

### Connection timeout
- Increase proxy timeout values (they're already set high in provided configs)
- Check if firewall is blocking connections
- Verify DNS is pointing to your server

## Performance Tuning

For high-traffic deployments, consider:

1. **Connection pooling** - Already configured with `keepalive` in nginx config
2. **Rate limiting** - Add to reverse proxy config to prevent abuse
3. **Load balancing** - Run multiple AirMessage Connect instances
4. **CDN/DDoS protection** - Use Cloudflare or similar (with WebSocket support)

## Security Best Practices

1. ✅ Always use HTTPS in production
2. ✅ Keep software updated (reverse proxy, SSL libraries)
3. ✅ Use strong SSL/TLS settings (TLS 1.2+, modern ciphers)
4. ✅ Enable HSTS header
5. ✅ Restrict access to port 1259 (localhost only)
6. ✅ Monitor logs for unusual activity
7. ✅ Enable Firebase authentication (remove `unlinked` flag)
8. ✅ Regular security audits with SSL Labs, etc.
