# AirMessage Connect Setup Guide

## Quick Start - Local Testing

### 1. Build the project
```bash
./gradlew shadowJar
```

### 2. Run in test mode (no SSL, no authentication)
```bash
chmod +x run-local-test.sh
./run-local-test.sh
```

The server will start on `ws://localhost:1259`

## Production Deployment to airmessage.vanstek.dev

### Prerequisites
- SSL certificate for your domain (from Let's Encrypt or other CA)
- Firebase project (optional but recommended for authentication)
- Reverse proxy (nginx, Apache, or Caddy)

### Option 1: Run with SSL directly (no reverse proxy)

1. **Prepare SSL Certificate**
   
   Convert your certificate to PEM format (if not already):
   ```bash
   cat your-cert.crt your-private-key.key > certificate.pem
   ```

2. **Set environment variable**
   ```bash
   export SERVER_CERTIFICATE=/path/to/certificate.pem
   ```

3. **Run the server**
   ```bash
   # With authentication (requires Firebase)
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-key.json
   java -jar build/libs/airmessage-connect.jar
   
   # Without authentication (testing only)
   java -jar build/libs/airmessage-connect.jar unlinked
   ```

### Option 2: Run behind reverse proxy (recommended)

This is the recommended approach as it:
- Lets your reverse proxy handle SSL termination
- Simplifies certificate management (auto-renewal with Let's Encrypt)
- Allows you to manage multiple services on the same server

1. **Run AirMessage Connect in insecure mode**
   
   The reverse proxy will handle SSL, so the backend runs without it:
   ```bash
   # With authentication
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-key.json
   java -jar build/libs/airmessage-connect.jar insecure
   
   # Without authentication (for testing)
   java -jar build/libs/airmessage-connect.jar insecure unlinked
   ```

2. **Configure your reverse proxy** (see reverse-proxy-configs/ directory)

### Nginx Reverse Proxy Configuration

Create `/etc/nginx/sites-available/airmessage-connect`:

```nginx
upstream airmessage_connect {
    server 127.0.0.1:1259;
}

server {
    listen 80;
    server_name airmessage.vanstek.dev;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name airmessage.vanstek.dev;
    
    # SSL configuration (adjust paths to your certificates)
    ssl_certificate /etc/letsencrypt/live/airmessage.vanstek.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/airmessage.vanstek.dev/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # WebSocket proxy configuration
    location / {
        proxy_pass http://airmessage_connect;
        proxy_http_version 1.1;
        
        # WebSocket headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts for long-lived WebSocket connections
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/airmessage-connect /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Systemd Service (for automatic startup)

Create `/etc/systemd/system/airmessage-connect.service`:

```ini
[Unit]
Description=AirMessage Connect WebSocket Server
After=network.target

[Service]
Type=simple
User=airmessage
Group=airmessage
WorkingDirectory=/opt/airmessage-connect
ExecStart=/usr/bin/java -jar /opt/airmessage-connect/airmessage-connect.jar insecure unlinked
Restart=on-failure
RestartSec=10

# Environment variables (adjust paths as needed)
#Environment="GOOGLE_APPLICATION_CREDENTIALS=/opt/airmessage-connect/firebase-key.json"

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=airmessage-connect

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable airmessage-connect
sudo systemctl start airmessage-connect
sudo systemctl status airmessage-connect
```

### Testing WebSocket Connection

You can test the WebSocket connection with `websocat` or a simple JavaScript client:

```bash
# Install websocat
cargo install websocat

# Test local connection
websocat ws://localhost:1259

# Test through reverse proxy
websocat wss://airmessage.vanstek.dev
```

Or use a browser console:
```javascript
const ws = new WebSocket('wss://airmessage.vanstek.dev');
ws.onopen = () => console.log('Connected!');
ws.onmessage = (event) => console.log('Received:', event.data);
ws.onerror = (error) => console.error('Error:', error);
```

## Firebase Setup (Optional)

If you want full authentication support:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Enable these services:
   - Firebase Authentication (enable Google sign-in)
   - Cloud Firestore
   - Firebase Cloud Messaging
4. Generate service account key:
   - Settings > Service Accounts
   - Click "Generate new private key"
5. Save the JSON file and set `GOOGLE_APPLICATION_CREDENTIALS` to its path

## Monitoring and Logs

Logs are saved to `logs/latest.log` in the working directory.

View live logs:
```bash
tail -f logs/latest.log
```

With systemd:
```bash
journalctl -u airmessage-connect -f
```

## Security Considerations

1. **Never run in production with these flags:**
   - `insecure` - Disables SSL/TLS encryption
   - `unlinked` - Disables authentication

2. **Firewall configuration:**
   ```bash
   # If running behind reverse proxy, only allow local connections to 1259
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   # Port 1259 should NOT be exposed externally
   ```

3. **Use Let's Encrypt for SSL certificates:**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d airmessage.vanstek.dev
   ```

## Troubleshooting

### Server won't start
- Check Java version: `java -version` (needs Java 11+)
- Check if port 1259 is in use: `sudo netstat -tlnp | grep 1259`
- Check logs in `logs/latest.log`

### WebSocket connection fails
- Verify server is running: `curl http://localhost:1259`
- Check nginx configuration: `sudo nginx -t`
- Check firewall: `sudo ufw status`
- Verify SSL certificate is valid: `openssl s_client -connect airmessage.vanstek.dev:443`

### Authentication issues
- Ensure `GOOGLE_APPLICATION_CREDENTIALS` is set correctly
- Verify Firebase service account has required permissions
- Check Firestore rules allow read/write access
