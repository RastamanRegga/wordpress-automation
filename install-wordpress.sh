#!/bin/bash
# automation/install/install.sh
# WordPress Installation Automation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="/etc/wordpress-automation/config.conf"
LOG_FILE="/var/log/wordpress-automation.log"

# Default values
DOMAIN=""
WEB_SERVER=""
DATABASE=""
DB_NAME="wordpress_$(date +%s)"
DB_USER="wp_user_$(date +%s)"
DB_PASS=""
WP_ADMIN_USER="admin"
WP_ADMIN_PASS=""
WP_ADMIN_EMAIL=""
INSTALL_PATH="/var/www"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log "[INFO] $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "[WARNING] $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "[ERROR] $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} WordPress Installation Script  ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Create necessary directories
setup_directories() {
    mkdir -p /etc/wordpress-automation
    mkdir -p /var/log
    touch "$LOG_FILE"
}

# Generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Get user input
get_user_input() {
    print_header
    
    echo -e "${BLUE}Please provide the following information:${NC}"
    
    read -p "Domain name (e.g., example.com): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        print_warning "Domain name is required"
        read -p "Domain name (e.g., example.com): " DOMAIN
    done
    
    echo -e "\n${BLUE}Select Web Server:${NC}"
    echo "1) Apache"
    echo "2) Nginx"
    read -p "Choose (1-2): " web_choice
    
    case $web_choice in
        1) WEB_SERVER="apache" ;;
        2) WEB_SERVER="nginx" ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
    
    echo -e "\n${BLUE}Select Database:${NC}"
    echo "1) MySQL/MariaDB"
    echo "2) PostgreSQL"
    read -p "Choose (1-2): " db_choice
    
    case $db_choice in
        1) DATABASE="mysql" ;;
        2) DATABASE="postgresql" ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
    
    read -p "Database name (default: $DB_NAME): " input_db_name
    DB_NAME=${input_db_name:-$DB_NAME}
    
    read -p "Database user (default: $DB_USER): " input_db_user
    DB_USER=${input_db_user:-$DB_USER}
    
    DB_PASS=$(generate_password)
    print_status "Generated database password: $DB_PASS"
    
    read -p "WordPress admin username (default: admin): " input_wp_user
    WP_ADMIN_USER=${input_wp_user:-$WP_ADMIN_USER}
    
    WP_ADMIN_PASS=$(generate_password)
    print_status "Generated WordPress admin password: $WP_ADMIN_PASS"
    
    read -p "WordPress admin email: " WP_ADMIN_EMAIL
    while [[ -z "$WP_ADMIN_EMAIL" ]]; do
        print_warning "Admin email is required"
        read -p "WordPress admin email: " WP_ADMIN_EMAIL
    done
    
    read -p "Installation path (default: $INSTALL_PATH): " input_path
    INSTALL_PATH=${input_path:-$INSTALL_PATH}
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
    
    print_status "Detected OS: $OS $VER"
}

# Update system
update_system() {
    print_status "Updating system packages..."
    
    case $OS in
        ubuntu|debian)
            apt update && apt upgrade -y
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        *)
            print_warning "OS not fully supported, proceeding anyway..."
            ;;
    esac
}

# Install basic requirements
install_basic_requirements() {
    print_status "Installing basic requirements..."
    
    case $OS in
        ubuntu|debian)
            apt install -y curl wget unzip php php-cli php-fpm php-mysql php-pgsql \
                php-xml php-mbstring php-curl php-zip php-gd php-intl php-soap \
                openssl ca-certificates
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y curl wget unzip php php-cli php-fpm php-mysqlnd php-pgsql \
                    php-xml php-mbstring php-curl php-zip php-gd php-intl php-soap \
                    openssl ca-certificates
            else
                yum install -y curl wget unzip php php-cli php-fpm php-mysql php-pgsql \
                    php-xml php-mbstring php-curl php-zip php-gd php-intl php-soap \
                    openssl ca-certificates
            fi
            ;;
    esac
}

# Install web server
install_web_server() {
    print_status "Installing $WEB_SERVER..."
    
    case $OS in
        ubuntu|debian)
            if [[ "$WEB_SERVER" == "apache" ]]; then
                apt install -y apache2 libapache2-mod-php
                systemctl enable apache2
                a2enmod rewrite
                a2enmod ssl
            else
                apt install -y nginx
                systemctl enable nginx
            fi
            ;;
        centos|rhel|fedora)
            if [[ "$WEB_SERVER" == "apache" ]]; then
                if command -v dnf &> /dev/null; then
                    dnf install -y httpd php
                else
                    yum install -y httpd php
                fi
                systemctl enable httpd
            else
                if command -v dnf &> /dev/null; then
                    dnf install -y nginx
                else
                    yum install -y nginx
                fi
                systemctl enable nginx
            fi
            ;;
    esac
}

# Install database
install_database() {
    print_status "Installing $DATABASE..."
    
    case $OS in
        ubuntu|debian)
            if [[ "$DATABASE" == "mysql" ]]; then
                apt install -y mariadb-server mariadb-client
                systemctl enable mariadb
                systemctl start mariadb
                mysql_secure_installation
            else
                apt install -y postgresql postgresql-contrib
                systemctl enable postgresql
                systemctl start postgresql
            fi
            ;;
        centos|rhel|fedora)
            if [[ "$DATABASE" == "mysql" ]]; then
                if command -v dnf &> /dev/null; then
                    dnf install -y mariadb-server mariadb
                else
                    yum install -y mariadb-server mariadb
                fi
                systemctl enable mariadb
                systemctl start mariadb
                mysql_secure_installation
            else
                if command -v dnf &> /dev/null; then
                    dnf install -y postgresql-server postgresql-contrib
                else
                    yum install -y postgresql-server postgresql-contrib
                fi
                postgresql-setup initdb
                systemctl enable postgresql
                systemctl start postgresql
            fi
            ;;
    esac
}

# Create database and user
setup_database() {
    print_status "Setting up database..."
    
    if [[ "$DATABASE" == "mysql" ]]; then
        mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
        mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
        mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
        mysql -e "FLUSH PRIVILEGES;"
    else
        sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
        sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"
    fi
    
    print_status "Database setup completed"
}

# Download and extract WordPress
download_wordpress() {
    print_status "Downloading WordPress..."
    
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    
    SITE_PATH="$INSTALL_PATH/$DOMAIN"
    mkdir -p "$SITE_PATH"
    cp -r wordpress/* "$SITE_PATH/"
    
    chown -R www-data:www-data "$SITE_PATH"
    chmod -R 755 "$SITE_PATH"
    
    print_status "WordPress files extracted to $SITE_PATH"
}

# Configure WordPress
configure_wordpress() {
    print_status "Configuring WordPress..."
    
    SITE_PATH="$INSTALL_PATH/$DOMAIN"
    
    # Create wp-config.php
    cp "$SITE_PATH/wp-config-sample.php" "$SITE_PATH/wp-config.php"
    
    if [[ "$DATABASE" == "mysql" ]]; then
        sed -i "s/database_name_here/$DB_NAME/" "$SITE_PATH/wp-config.php"
        sed -i "s/username_here/$DB_USER/" "$SITE_PATH/wp-config.php"
        sed -i "s/password_here/$DB_PASS/" "$SITE_PATH/wp-config.php"
        sed -i "s/localhost/localhost/" "$SITE_PATH/wp-config.php"
    else
        # For PostgreSQL, we need to modify the config
        cat > "$SITE_PATH/wp-config.php" << EOF
<?php
define('DB_NAME', '$DB_NAME');
define('DB_USER', '$DB_USER');
define('DB_PASSWORD', '$DB_PASS');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

// PostgreSQL specific
define('DB_TYPE', 'pgsql');
EOF
        # Add the rest of wp-config content
        grep -v "<?php" "$SITE_PATH/wp-config-sample.php" | grep -v "DB_" >> "$SITE_PATH/wp-config.php"
    fi
    
    # Generate salts
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    sed -i '/put your unique phrase here/d' "$SITE_PATH/wp-config.php"
    echo "$SALTS" >> "$SITE_PATH/wp-config.php"
    
    print_status "WordPress configuration completed"
}

# Configure web server
configure_web_server() {
    print_status "Configuring $WEB_SERVER..."
    
    SITE_PATH="$INSTALL_PATH/$DOMAIN"
    
    if [[ "$WEB_SERVER" == "apache" ]]; then
        # Apache configuration
        cat > "/etc/apache2/sites-available/$DOMAIN.conf" << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $SITE_PATH
    
    <Directory $SITE_PATH>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF
        
        a2ensite "$DOMAIN.conf"
        a2dissite 000-default
        systemctl restart apache2
        
    else
        # Nginx configuration
        cat > "/etc/nginx/sites-available/$DOMAIN" << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_PATH;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
        
        ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/"
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        systemctl restart php*-fpm
    fi
    
    print_status "$WEB_SERVER configuration completed"
}

# Install WP-CLI
install_wp_cli() {
    print_status "Installing WP-CLI..."
    
    curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/bin/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    
    print_status "WP-CLI installed successfully"
}

# Complete WordPress installation
complete_wordpress_installation() {
    print_status "Completing WordPress installation..."
    
    SITE_PATH="$INSTALL_PATH/$DOMAIN"
    cd "$SITE_PATH"
    
    # Install WordPress
    sudo -u www-data wp core install \
        --url="http://$DOMAIN" \
        --title="WordPress Site" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASS" \
        --admin_email="$WP_ADMIN_EMAIL"
    
    print_status "WordPress installation completed"
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
DOMAIN=$DOMAIN
WEB_SERVER=$WEB_SERVER
DATABASE=$DATABASE
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
WP_ADMIN_USER=$WP_ADMIN_USER
WP_ADMIN_PASS=$WP_ADMIN_PASS
WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL
INSTALL_PATH=$INSTALL_PATH
SITE_PATH=$INSTALL_PATH/$DOMAIN
INSTALL_DATE=$(date)
EOF
    
    print_status "Configuration saved to $CONFIG_FILE"
}

# Display final information
display_final_info() {
    echo -e "\n${GREEN}================================${NC}"
    echo -e "${GREEN} Installation Completed! ${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "${BLUE}Site URL:${NC} http://$DOMAIN"
    echo -e "${BLUE}Admin URL:${NC} http://$DOMAIN/wp-admin"
    echo -e "${BLUE}Admin Username:${NC} $WP_ADMIN_USER"
    echo -e "${BLUE}Admin Password:${NC} $WP_ADMIN_PASS"
    echo -e "${BLUE}Database:${NC} $DATABASE"
    echo -e "${BLUE}Database Name:${NC} $DB_NAME"
    echo -e "${BLUE}Database User:${NC} $DB_USER"
    echo -e "${BLUE}Database Password:${NC} $DB_PASS"
    echo -e "${BLUE}Installation Path:${NC} $INSTALL_PATH/$DOMAIN"
    echo -e "${BLUE}Configuration File:${NC} $CONFIG_FILE"
    echo -e "${BLUE}Log File:${NC} $LOG_FILE"
    echo -e "\n${YELLOW}Please save this information securely!${NC}"
}

# Main function
main() {
    check_root
    setup_directories
    get_user_input
    detect_os
    update_system
    install_basic_requirements
    install_web_server
    install_database
    setup_database
    download_wordpress
    configure_wordpress
    configure_web_server
    install_wp_cli
    complete_wordpress_installation
    save_config
    display_final_info
}

# Run main function
main "$@"