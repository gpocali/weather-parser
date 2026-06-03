# 🌦️ Alpine Linux Weather Parser Service

A lightweight, daemonized PHP service designed natively for Alpine Linux. It fetches localized National Weather Service (NWS) DWML forecast data, parses it, and automatically serves the output via an integrated web server. 

This tool is highly optimized for NAS environments or low-resource containers, providing both a responsive HTML dashboard and a plain-text format perfectly suited for NVR video overlays.

## ✨ Features

* **Continuous Daemon Execution:** Runs seamlessly in the background, updating forecast data every 10 minutes.
* **Integrated Web Server:** Uses `darkhttpd` to serve the parsed HTML dashboard locally without needing a heavy Apache or Nginx stack.
* **Multi-Format Output:** Generates a Bootstrap-styled web page (`index.html`) and a clean text output (`nvr-display.txt`).
* **Native OpenRC Integration:** Fully managed via Alpine's native `rc-service` init system.
* **Live Git Updates:** Built-in OpenRC command to fetch and apply script updates directly from this repository without tearing down the service.
* **MOTD Integration:** Automatically injects management commands into the server's login message for quick reference.

## 📋 Prerequisites

This service is built specifically for **Alpine Linux**. The installation script will automatically install the following dependencies:
* `php`, `php-simplexml`, `php-openssl`, `php-json`
* `darkhttpd`
* `git`
* `terminus-font`

## 🚀 Installation

You can install and provision the entire service directly from the command line in a single command. 

Run the following as root (or using `sudo`):

```bash
wget -qO- https://raw.githubusercontent.com/gpocali/weather-parser/main/setup.sh | sh -s -- --install

```

**Post-Installation:**
By default, the service installs with generic coordinates for New York City. To get your local weather, you must edit the configuration file generated at `/etc/weather-parser.conf`.

## ⚙️ Configuration

The service is driven by a single configuration file located at `/etc/weather-parser.conf`.

```ini
# /etc/weather-parser.conf
TIMEZONE="US/Eastern"
LATITUDE="40.7128"       # Replace with your local latitude
LONGITUDE="-74.0060"     # Replace with your local longitude
OUTPUT_DIR="/var/www/weather"
WEB_PORT="8080"
GIT_REPO="https://github.com/gpocali/weather-parser.git"

```

After modifying this file, restart the service to apply the changes:

```bash
rc-service weather-parser restart

```

You can view the HTML output by navigating to `http://<YOUR_NAS_IP>:8080` in your web browser.

## 🛠️ Service Management

The application is managed using standard OpenRC commands. A cheat sheet is also added to your terminal's MOTD upon logging in.

* **Start the service:** `rc-service weather-parser start`
* **Stop the service:** `rc-service weather-parser stop`
* **Restart the service:** `rc-service weather-parser restart`
* **Check status:** `rc-service weather-parser status`

### Updating the Scripts

If you push changes to your GitHub repository, you can pull those updates directly into the running application via the init script:

```bash
rc-service weather-parser update

```

*This command will fetch the latest commits, apply the new `weather-parser.php` execution script, and gracefully recycle the daemon threads.*

## 🗑️ Uninstallation

To completely remove the service, configuration files, crons, dependencies, and generated web assets, run the teardown flag:

```bash
wget -qO- https://raw.githubusercontent.com/gpocali/weather-parser/main/setup.sh | sh -s -- --uninstall

```

