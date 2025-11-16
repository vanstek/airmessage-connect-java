# Deploying AirMessage Connect to airmessage.vanstek.dev

## Current Status
✅ **Server built and tested successfully!**
- JAR file: `build/libs/airmessage-connect.jar`
- Running on port 1259
- WebSocket server responding correctly

## Deployment Steps

### 1. Prepare the Production Server

Copy the JAR file and support files to your production server:

```bash
# On your server, create the deployment directory
sudo mkdir -p /opt/airmessage-connect
sudo chown $USER:$USER /opt/airmessage-connect

# From your development machine, copy files
scp build/libs/airmessage-connect.jar user@your-server:/opt/airmessage-connect/
scp airmessage-connect.service user@your-server:/opt/airmessage-connect/
scp -r reverse-proxy-configs user@your-server:/opt/airmessage-connect/
```

### 2. Install Java on Production Server

```bash
sudo apt update
sudo apt install openjdk-11-jdk
java -version  # Should show Java 11
```

### 3. Option A: Deploy with Nginx (Recommended)

#### 3.1 Install Nginx
```bash
sudo apt install nginx
```

#### 3.2 Set up SSL with Let's Encrypt
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d airmessage.vanstek.dev
```

#### 3.3 Configure Nginx
```bash
sudo cp /opt/airmessage-connect/reverse-proxy-configs/nginx.conf /etc/nginx/sites-available/airmessage-connect
sudo ln -s /etc/nginx/sites-available/airmessage-connect /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 3.4 Update the nginx config paths
Edit `/etc/nginx/sites-available/airmessage-connect` and ensure SSL certificate paths match your Let's Encrypt setup (usually already correct at `/etc/letsencrypt/live/airmessage.vanstek.dev/`).

### 4. Set up AirMessage Connect Service

#### 4.1 Create dedicated user (recommended for security)
```bash
sudo useradd -r -s /bin/false airmessage
sudo chown -R airmessage:airmessage /opt/airmessage-connect
```

#### 4.2 Install systemd service
```bash
sudo cp /opt/airmessage-connect/airmessage-connect.service /etc/systemd/system/
```

#### 4.3 Edit the service file if needed
```bash
sudo nano /etc/systemd/system/airmessage-connect.service
```

**For testing without Firebase (simpler):**
- Keep the line: `ExecStart=/usr/bin/java -jar /opt/airmessage-connect/airmessage-connect.jar insecure unlinked`
- The `insecure` flag is OK here since nginx handles SSL
- The `unlinked` flag disables Firebase authentication (testing only)

**For production with Firebase:**
- Change to: `ExecStart=/usr/bin/java -jar /opt/airmessage-connect/airmessage-connect.jar insecure`
- Uncomment and set: `Environment="GOOGLE_APPLICATION_CREDENTIALS=/opt/airmessage-connect/firebase-key.json"`
- Download Firebase service account key and copy to `/opt/airmessage-connect/firebase-key.json`

#### 4.4 Start the service
```bash
sudo systemctl daemon-reload
sudo systemctl enable airmessage-connect
sudo systemctl start airmessage-connect
sudo systemctl status airmessage-connect
```

### 5. Configure Firewall

```bash
# Allow HTTP/HTTPS through firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Verify port 1259 is NOT exposed externally
sudo ufw status
```

### 6. Verify Deployment

#### 6.1 Check service is running
```bash
sudo systemctl status airmessage-connect
sudo journalctl -u airmessage-connect -n 50
```

#### 6.2 Check nginx is proxying correctly
```bash
curl -i http://localhost:1259  # Should respond
curl -i https://airmessage.vanstek.dev  # Should upgrade to WebSocket
```

#### 6.3 Test WebSocket connection
```bash
# Install websocat (WebSocket CLI tool)
cargo install websocat
# Or: wget https://github.com/vi/websocat/releases/download/v1.12.0/websocat.x86_64-unknown-linux-musl
# chmod +x websocat.x86_64-unknown-linux-musl && sudo mv websocat.x86_64-unknown-linux-musl /usr/local/bin/websocat

# Test connection (should reject without proper params - this is correct!)
websocat wss://airmessage.vanstek.dev
```

You should see a 404 error with "WebSocket Upgrade Failure" - this is **normal**! The server only accepts connections with specific protocol parameters from AirMessage clients.

#### 6.4 Check logs
```bash
# AirMessage Connect logs
sudo journalctl -u airmessage-connect -f

# Nginx logs
sudo tail -f /var/log/nginx/airmessage-connect-access.log
sudo tail -f /var/log/nginx/airmessage-connect-error.log
```

### 7. Update AirMessage Client Configuration

Now you need to update your AirMessage clients (server, Android app, web app) to point to your new domain.

#### For AirMessage Server:
Edit `connectauth/secrets.js` and update:
```javascript
export const connectEndpoint = "wss://airmessage.vanstek.dev";
```

Or in `src/main/resources/secrets.properties`:
```properties
CONNECT_ENDPOINT=wss://airmessage.vanstek.dev
```

#### For AirMessage Android:
Edit `secrets.properties`:
```properties
CONNECT_ENDPOINT=wss://airmessage.vanstek.dev
```

#### For AirMessage Web:
Edit `src/secrets.ts`:
```typescript
export const connectHostname = "airmessage.vanstek.dev";
```

### 8. Monitoring and Maintenance

#### Auto-renew SSL certificates
Certbot sets up automatic renewal. Verify it works:
```bash
sudo certbot renew --dry-run
```

#### Monitor service health
```bash
# Check if service is running
sudo systemctl status airmessage-connect

# View recent logs
sudo journalctl -u airmessage-connect -n 100 --no-pager

# Follow logs in real-time
sudo journalctl -u airmessage-connect -f
```

#### Restart service after updates
```bash
# After rebuilding JAR:
sudo systemctl restart airmessage-connect
```

#### Check disk space (logs can grow)
```bash
df -h
du -sh /opt/airmessage-connect/logs/*
```

## Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u airmessage-connect -n 50

# Check Java is installed
java -version

# Check file permissions
ls -la /opt/airmessage-connect/
```

### Can't connect to domain
```bash
# Verify DNS is pointing to your server
dig airmessage.vanstek.dev

# Check nginx is running
sudo systemctl status nginx

# Check nginx config
sudo nginx -t

# Check firewall
sudo ufw status
```

### SSL certificate issues
```bash
# Check certificate
sudo certbot certificates

# Test SSL connection
openssl s_client -connect airmessage.vanstek.dev:443 -servername airmessage.vanstek.dev

# Renew manually if needed
sudo certbot renew --force-renewal
```

### WebSocket connections failing
```bash
# Check backend is running
curl http://localhost:1259

# Check nginx WebSocket config
grep -i upgrade /etc/nginx/sites-available/airmessage-connect

# Test from server itself
websocat ws://localhost:1259
```

## Security Checklist

- [ ] SSL/TLS certificates installed and auto-renewing
- [ ] Firewall configured (ports 80, 443 open; 1259 local only)
- [ ] Running as dedicated user (not root)
- [ ] `unlinked` flag removed in production (Firebase auth enabled)
- [ ] Logs monitored regularly
- [ ] System and packages kept up to date

## Performance Tuning

For high traffic, consider:
- Running multiple instances behind load balancer
- Increasing ulimit for file descriptors
- Tuning nginx worker processes
- Adding Redis for session management
- Implementing rate limiting in nginx

## Backup

Important files to backup:
- `/opt/airmessage-connect/` (entire directory)
- `/etc/nginx/sites-available/airmessage-connect`
- `/etc/systemd/system/airmessage-connect.service`
- `/etc/letsencrypt/` (SSL certificates)

## Quick Commands Reference

```bash
# Service management
sudo systemctl status airmessage-connect
sudo systemctl start airmessage-connect
sudo systemctl stop airmessage-connect
sudo systemctl restart airmessage-connect
sudo journalctl -u airmessage-connect -f

# Nginx management
sudo systemctl status nginx
sudo nginx -t
sudo systemctl reload nginx

# SSL certificate
sudo certbot certificates
sudo certbot renew

# Firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```
