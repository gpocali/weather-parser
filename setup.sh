#!/bin/sh

# Setup/Teardown Engine for Weather Parser Service
CONFIG_PATH="/etc/weather-parser.conf"
BIN_PATH="/usr/libexec/weather-parser.php"
INIT_PATH="/etc/init.d/weather-parser"
REPO_SRC_DIR="/usr/share/weather-parser"

# Define your public repository URL here so the script knows where to pull from
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

    echo "==> Provisioning Workspace Paths and Fetching Source..."
    mkdir -p "/var/www/weather"
    mkdir -p "$REPO_SRC_DIR"

    # Clone the repository directly to grab the execution and init files
    rm -rf "$REPO_SRC_DIR"
    git clone "$GIT_REPO_URL" "$REPO_SRC_DIR"

    # Copy files from the repository root to their operational directories
    cp "$REPO_SRC_DIR/weather-parser.php" "$BIN_PATH"
    cp "$REPO_SRC_DIR/weather-parser.init" "$INIT_PATH"

    # Apply executable masks
    chmod +x "$BIN_PATH"
    chmod +x "$INIT_PATH"

    echo "==> Setting up login instructions (MOTD)..."
    # Add to the static MOTD (if not already there)
    if ! grep -q "Weather Parser Service" /etc/motd 2>/dev/null; then
        echo "" >> /etc/motd
        echo "--- Weather Parser Service Commands ---" >> /etc/motd
        echo "Manage: rc-service weather-parser {start|stop|restart|status}" >> /etc/motd
        echo "Update: rc-service weather-parser update" >> /etc/motd
        echo "---------------------------------------" >> /etc/motd
    fi

    # Create the dynamic fallback script
    cat << 'EOF' > /etc/profile.d/weather_motd.sh
#!/bin/sh
# If the static MOTD was overwritten, print the instructions dynamically
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
        rm -f "$CONFIG_PATH"
    fi

    rm -f "$BIN_PATH"
    rm -rf "$REPO_SRC_DIR"
    
    echo "==> Cleaning up login instructions (MOTD)..."
    if grep -q "Weather Parser Service" /etc/motd 2>/dev/null; then
        sed -i '/--- Weather Parser Service Commands ---/,/---------------------------------------/d' /etc/motd
    fi
    rm -f /etc/profile.d/weather_motd.sh
    
    echo "------------------------------------------------------"
    echo "Uninstallation Complete!"
    echo "All configuration files, cron dependencies, and web assets have been removed."
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
    echo "If running via curl/wget pipe, use: wget -qO- https://raw.github.../setup.sh | sh -s -- --install"
    exit 1
    ;;
esac