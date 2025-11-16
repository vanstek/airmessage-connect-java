#!/bin/bash
# Quick deployment script for production server
# Run this on your production server after copying files

set -e

echo "AirMessage Connect - Quick Deployment Script"
echo "=============================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  This script needs sudo access. Run with: sudo ./quick-deploy.sh"
    exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$USER}

echo "📦 Installing dependencies..."
apt-get update
apt-get install -y openjdk-11-jdk nginx certbot python3-certbot-nginx

echo ""
echo "👤 Creating airmessage user..."
useradd -r -s /bin/false airmessage 2>/dev/null || echo "User already exists"

echo ""
echo "📁 Setting up directories..."
mkdir -p /opt/airmessage-connect/logs
cp -v airmessage-connect.jar /opt/airmessage-connect/ 2>/dev/null || echo "JAR not found in current directory"
chown -R airmessage:airmessage /opt/airmessage-connect

echo ""
read -p "Enter your domain name (e.g., airmessage.vanstek.dev): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "❌ Domain name is required!"
    exit 1
fi

echo ""
echo "🔧 Configuring Nginx..."
cat > /etc/nginx/sites-available/airmessage-connect <<EOF
upstream airmessage_connect {
    server 127.0.0.1:1259;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    location / {
        proxy_pass http://airmessage_connect;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/airmessage-connect /etc/nginx/sites-enabled/
nginx -t

echo ""
echo "🔐 Setting up SSL certificate..."
echo "⚠️  Make sure your domain's DNS is pointing to this server!"
read -p "Press Enter to continue with SSL setup, or Ctrl+C to abort..."

certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email || {
    echo "⚠️  SSL setup failed. You can run this later: sudo certbot --nginx -d $DOMAIN"
}

echo ""
echo "🔧 Setting up systemd service..."
cat > /etc/systemd/system/airmessage-connect.service <<EOF
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
StandardOutput=journal
StandardError=journal
SyslogIdentifier=airmessage-connect

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable airmessage-connect
systemctl start airmessage-connect

echo ""
echo "🔥 Configuring firewall..."
ufw allow 80/tcp 2>/dev/null || echo "ufw not available"
ufw allow 443/tcp 2>/dev/null || echo "ufw not available"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Check service status: sudo systemctl status airmessage-connect"
echo "2. View logs: sudo journalctl -u airmessage-connect -f"
echo "3. Test connection: curl https://$DOMAIN"
echo "4. Update your AirMessage clients to use: wss://$DOMAIN"
echo ""
echo "Configuration files:"
echo "- Service: /etc/systemd/system/airmessage-connect.service"
echo "- Nginx: /etc/nginx/sites-available/airmessage-connect"
echo "- App: /opt/airmessage-connect/"
echo ""
