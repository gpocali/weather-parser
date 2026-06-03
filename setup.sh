#!/bin/sh

# Setup/Teardown Engine for Weather Parser Service
CONFIG_PATH="/opt/weather-parser.conf"
BIN_PATH="/usr/libexec/weather-parser.php"
INIT_PATH="/etc/init.d/weather-parser"
REPO_SRC_DIR="/etc/weather-parser"

# Remote Tracking Git Repository
GIT_REPO_URL="https://github.com/gpocali/weather-parser.git"

install_dependencies() {
    echo "==> Verifying System Prerequisites and Installing Dependencies..."
    apk update
    apk add php php-simplexml php-openssl php-json darkhttpd git terminus-font

    echo "==> Generating Default Configuration (New York City)..."
    cat << EOF > "$CONFIG_PATH"
# Weather Parser Configuration
# PLEASE EDIT THIS FILE TO SET YOUR SPECIFIC LOCATION AND PREFERENCES
TIMEZONE="US/Eastern"
LATITUDE="40.7128"
LONGITUDE="-74.0060"
OUTPUT_DIR="/var/www/weather"
WEB_PORT="8080"
GIT_REPO="$GIT_REPO_URL"
EOF

    echo "==> Configuring Alpine LBU Tracking for /opt configuration..."
    if command -v lbu >/dev/null 2>&1; then
        lbu include "$CONFIG_PATH"
        echo "Added $CONFIG_PATH to LBU persistence."
    fi

    echo "==> Provisioning Workspace Paths and Fetching Source..."
    mkdir -p "/var/www/weather"
    
    # Clone the repository into /etc so LBU tracks the source tree by default
    rm -rf "$REPO_SRC_DIR"
    git clone "$GIT_REPO_URL" "$REPO_SRC_DIR"

    # Copy files from the repository root to their operational directories
    cp "$REPO_SRC_DIR/weather-parser.php" "$BIN_PATH"
    cp "$REPO_SRC_DIR/weather-parser.init" "$INIT_PATH"

    # Dynamically patch the hardcoded config paths in the source files
    echo "==> Patching source files for new /opt config path..."
    sed -i "s|/etc/weather-parser.conf|$CONFIG_PATH|g" "$BIN_PATH"
    sed -i "s|/etc/weather-parser.conf|$CONFIG_PATH|g" "$INIT_PATH"

    # Apply executable masks
    chmod +x "$BIN_PATH"
    chmod +x "$INIT_PATH"
    
    lbu add "$BIN_PATH" "$INIT_PATH"

    echo "==> Setting up login instructions (MOTD)..."
    if ! grep -q "Weather Parser Service" /etc/motd 2>/dev/null; then
        echo "" >> /etc/motd
        echo "--- Weather Parser Service Commands ---" >> /etc/motd
        echo "Manage: rc-service weather-parser {start|stop|restart|status}" >> /etc/motd
        echo "Update: rc-service weather-parser update" >> /etc/motd
        echo "---------------------------------------" >> /etc/motd
    fi

    cat << 'EOF' > /etc/profile.d/weather_motd.sh
#!/bin/sh
if ! grep -q "Weather Parser Service" /etc/motd 2>/dev/null; then
    echo ""
    echo "--- Weather Parser Service Commands ---"
    echo "Manage: rc-service weather-parser {start|stop|restart|status}"
    echo "Update: rc-service weather-parser update"
    echo "---------------------------------------"
fi
EOF
    chmod +x /etc/profile.d/weather_motd.sh

    echo "==> Starting Services..."
    rc-update add weather-parser default
    rc-service weather-parser start

    echo "------------------------------------------------------"
    echo "Installation Complete!"
    echo "The weather-parser service has been started and enabled on boot."
    echo ""
    echo "IMPORTANT: The service is currently running with default NYC coordinates."
    echo "Please edit the configuration file to match your exact location:"
    echo "  nano $CONFIG_PATH"
    echo ""
    echo "Run 'rc-service weather-parser restart' after saving changes."
    echo "If using a diskless Alpine install, remember to run 'lbu commit -d'"
    echo "Web Interface operational at: http://localhost:8080"
    echo "------------------------------------------------------"
}

uninstall_dependencies() {
    echo "==> Initializing System Teardown Protocol..."
    
    if [ -f "$INIT_PATH" ]; then
        echo "Stopping service runtime threads..."
        rc-service weather-parser stop 2>/dev/null
        rc-update del weather-parser default 2>/dev/null
        rm -f "$INIT_PATH"
    fi

    if [ -f "$CONFIG_PATH" ]; then
        . "$CONFIG_PATH"
        if [ -d "$OUTPUT_DIR" ]; then
            echo "Removing generated web assets directory ($OUTPUT_DIR)..."
            rm -rf "$OUTPUT_DIR"
        fi
        
        # Remove config from LBU tracking before deleting
    #    if command -v lbu >/dev/null 2>&1; then
    #        lbu exclude "$CONFIG_PATH" 2>/dev/null
    #    fi
        
    #    rm -f "$CONFIG_PATH"
    fi

    rm -f "$BIN_PATH"
    rm -rf "$REPO_SRC_DIR"
    
    lbu exclude "$BIN_PATH" "$INIT_PATH"
    
    echo "==> Cleaning up login instructions (MOTD)..."
    if grep -q "Weather Parser Service" /etc/motd 2>/dev/null; then
        sed -i '/--- Weather Parser Service Commands ---/,/---------------------------------------/d' /etc/motd
    fi
    rm -f /etc/profile.d/weather_motd.sh
    
    echo "------------------------------------------------------"
    echo "Uninstallation Complete!"
    echo "Assets have been removed but config file remains."
    echo "If using a diskless Alpine install, remember to run 'lbu commit -d'"
    echo "------------------------------------------------------"
}

# Command line argument parsing
case "$1" in
  --install)
    install_dependencies
    ;;
  --uninstall)
    uninstall_dependencies
    ;;
  *)
    echo "Weather Parser Setup Utility"
    echo "Usage: $0 {--install|--uninstall}"
    echo "If running via curl/wget pipe, use: wget -qO- https://raw.githubusercontent.com/gpocali/weather-parser/main/setup.sh | sh -s -- --install"
    exit 1
    ;;
esac