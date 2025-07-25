#!/bin/bash
# WordPress Auto Installer
# Supports Ubuntu/Debian with Apache/Nginx and MySQL/PostgreSQL

set -e

# Colors for output
print_green() {
    echo -e "\e[32m$1\e[0m"
}

print_red() {
    echo -e "\e[31m$1\e[0m"
}

print_yellow() {
    echo -e "\e[33m$1\e[0m"
}

print_blue() {
    echo -e "\e[34m$1\e[0m"
}

# Check if command exists
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        print_red "Error: Command '$cmd' not found."
        exit 1
    fi
}

# Generate random password
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-12
}

# Check OS compatibility
check_os() {
    if ! grep -E "Ubuntu|Debian" /etc/os-release > /dev/null; then
        print_red "This script only supports Ubuntu or Debian."
        exit 1
    fi
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_red "This script must be run as root."
        exit 1
    fi
}

# Get user input
get_user_input() {
    print_blue "=== WordPress Installation Configuration ==="
    
    # Domain name
    read -p "Enter domain name (e.g., example.com): " domain_name
    while [[ -z "$domain_name" ]]; do
        print_yellow "Domain name is required!"
        read -p "Enter domain name: " domain_name
    done
    
    # Web server choice
    echo ""
    print_blue "Choose Web Server:"
    echo "1) Apache"
    echo "2) Nginx"
    read -p "Select (1-2): " web_server_choice
    
    case $web_server_choice in
        1) web_server="apache" ;;
        2) web_server="nginx" ;;
        *) print_red "Invalid choice!"; exit 1 ;;
    esac
    
    # Database choice
    echo ""
    print_blue "Choose Database:"
    echo "1) MySQL/MariaDB"
    echo "2) PostgreSQL"
    read -p "Select (1-2): " db_choice
    
    case $db_choice in
        1) database="mysql" ;;
        2) database="postgresql" ;;
        *) print_red "Invalid choice!"; exit 1 ;;
    esac
    
    # Database credentials
    echo ""
    print_blue "Database Configuration:"
    read -p "Database name (default: wordpress_$(date +%s)): " wp_db
    wp_db=${wp_db:-"wordpress_$(date +%s)"}
    
    read -p "Database username (default: wp_user_$(date +%s)): " wp_user
    wp_user=${wp_user:-"wp_user_$(date +%s)"}
    
    wp_pass=$(generate_password)
    print_green "Generated database password: $wp_pass"
    
    # WordPress admin credentials
    echo ""
    print_blue "WordPress Admin Configuration:"
    read -p "Admin username (default: admin): " wp_admin_user
    wp_admin_user=${wp_admin_user:-"admin"}
    
    wp_admin_pass=$(generate_password)
    print_green "Generated admin password: $wp_admin_pass"
    
    read -p "Admin email: " wp_admin_email
    while [[ -z "$wp_admin_email" ]]; do
        print_yellow "Admin email is required!"
        read -p "Admin email: " wp_admin_email
    done
    
    # Installation path
    read -p "Installation path (default: /var/www/$domain_name): " install_path
    install_path=${install_path:-"/var/www/$domain_name"}
}

# Update system packages
update_system() {
    print_green "Updating system packages..."
    apt update && apt upgrade -y
}

# Install web server and PHP
install_web_server() {
    print_green "Installing $web_server and PHP..."
    
    if [[ $web_server == "apache" ]]; then
        apt install -y apache2 libapache2-mod-php php php-cli
        check_command "apache2"
        
        # Enable required Apache modules
        a2enmod rewrite
        a2enmod ssl
        a2enmod headers
        
    else
        apt install -y nginx php-fpm php-cli
        check_command "nginx"
    fi
    
    # Install PHP extensions
    apt install -y php-mysql php-pgsql php-xml php-mbstring php-curl php-zip \
        php-common php-json php-gd php-intl php-soap php-bcmath
    
    check_command "php"
    print_green "Web server and PHP installed successfully"
}

# Install and configure database
install_database() {
    print_green "Installing and configuring $database..."
    
    if [[ $database == "mysql" ]]; then
        apt install -y mysql-server mysql-client
        check_command "mysql"
        
        # Secure MySQL installation
        print_yellow "Securing MySQL installation..."
        mysql_secure_installation
        
        # Create database and user
        print_green "Creating WordPress database and user..."
        mysql -e "CREATE DATABASE IF NOT EXISTS $wp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        mysql -e "CREATE USER IF NOT EXISTS '$wp_user'@'localhost' IDENTIFIED BY '$wp_pass';"
        mysql -e "GRANT ALL PRIVILEGES ON $wp_db.* TO '$wp_user'@'localhost';"
        mysql -e "FLUSH PRIVILEGES;"
        
    else
        apt install -y postgresql postgresql-contrib
        check_command "psql"
        
        # Start PostgreSQL service
        systemctl start postgresql
        systemctl enable postgresql
        
        # Create database and user
        print_green "Creating WordPress database and user..."
        sudo -u postgres psql -c "CREATE DATABASE $wp_db;"
        sudo -u postgres psql -c "CREATE USER $wp_user WITH PASSWORD '$wp_pass';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $wp_db TO $wp_user;"
        sudo -u postgres psql -c "ALTER USER $wp_user CREATEDB;"
    fi
    
    print_green "Database installed and configured successfully"
}

# Download and setup WordPress
setup_wordpress() {
    print_green "Downloading and setting up WordPress..."
    
    # Create installation directory
    mkdir -p "$install_path"
    
    # Download WordPress
    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar xzf latest.tar.gz
    
    # Move WordPress files
    cp -r wordpress/* "$install_path/"
    rm -rf wordpress latest.tar.gz
    
    # Create wp-config.php
    cp "$install_path/wp-config-sample.php" "$install_path/wp-config.php"
    
    # Configure database connection
    if [[ $database == "mysql" ]]; then
        sed -i "s/database_name_here/$wp_db/" "$install_path/wp-config.php"
        sed -i "s/username_here/$wp_user/" "$install_path/wp-config.php"
        sed -i "s/password_here/$wp_pass/" "$install_path/wp-config.php"
        sed -i "s/localhost/localhost/" "$install_path/wp-config.php"
    else
        # For PostgreSQL, we need to install additional plugin
        wget -q https://downloads.wordpress.org/plugin/postgresql-for-wordpress.zip -P /tmp/
        apt install -y unzip
        unzip -q /tmp/postgresql-for-wordpress.zip -d "$install_path/wp-content/plugins/"
        
        # Configure for PostgreSQL
        sed -i "s/database_name_here/$wp_db/" "$install_path/wp-config.php"
        sed -i "s/username_here/$wp_user/" "$install_path/wp-config.php"
        sed -i "s/password_here/$wp_pass/" "$install_path/wp-config.php"
        sed -i "s/localhost/localhost/" "$install_path/wp-config.php"
        
        # Add PostgreSQL specific configuration
        cat >> "$install_path/wp-config.php" << EOF

// PostgreSQL Configuration
define('DB_TYPE', 'pgsql');
define('PG4WP_ROOT', ABSPATH.'wp-content/plugins/postgresql-for-wordpress/');
EOF
    fi
    
    # Generate WordPress salts
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    # Remove the existing salt placeholders and add new ones
    sed -i '/AUTH_KEY\|SECURE_AUTH_KEY\|LOGGED_IN_KEY\|NONCE_KEY\|AUTH_SALT\|SECURE_AUTH_SALT\|LOGGED_IN_SALT\|NONCE_SALT/d' "$install_path/wp-config.php"
    
    # Add new salts before the table prefix line
    sed -i "/table_prefix/i\\$SALTS" "$install_path/wp-config.php"
    
    # Set proper permissions
    chown -R www-data:www-data "$install_path"
    find "$install_path" -type d -exec chmod 755 {} \;
    find "$install_path" -type f -exec chmod 644 {} \;
    
    print_green "WordPress downloaded and configured successfully"
}

# Configure web server
configure_web_server() {
    print_green "Configuring $web_server for $domain_name..."
    
    if [[ $web_server == "apache" ]]; then
        # Apache configuration
        cat > "/etc/apache2/sites-available/$domain_name.conf" << EOF
<VirtualHost *:80>
    ServerName $domain_name
    ServerAlias www.$domain_name
    DocumentRoot $install_path
    
    <Directory $install_path>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
    
    # Security headers
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    
    # Hide sensitive files
    <Files "wp-config.php">
        Require all denied
    </Files>
    
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>
    
    ErrorLog \${APACHE_LOG_DIR}/${domain_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain_name}_access.log combined
</VirtualHost>
EOF
        
        # Enable site and disable default
        a2ensite "$domain_name.conf"
        a2dissite 000-default.conf 2>/dev/null || true
        
        # Test and restart Apache
        apache2ctl configtest
        systemctl restart apache2
        systemctl enable apache2
        
    else
        # Nginx configuration
        php_fpm_socket=$(find /var/run/php/ -name "php*-fpm.sock" | head -n 1)
        
        cat > "/etc/nginx/sites-available/$domain_name" << EOF
server {
    listen 80;
    server_name $domain_name www.$domain_name;
    root $install_path;
    index index.php index.html index.htm;

    # Security
    server_tokens off;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # WordPress specific rules
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # PHP processing
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$php_fpm_socket;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Security rules
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~* /wp-config.php {
        deny all;
    }

    location ~* /wp-content/uploads/.*\.php\$ {
        deny all;
    }

    # Static files caching
    location ~* \.(css|gif|ico|jpeg|jpg|js|png|svg|webp|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/css
        text/javascript
        text/xml
        text/plain
        application/javascript
        application/xml+rss
        application/json;
}
EOF
        
        # Enable site and disable default
        ln -sf "/etc/nginx/sites-available/$domain_name" "/etc/nginx/sites-enabled/"
        rm -f /etc/nginx/sites-enabled/default
        
        # Test and restart Nginx
        nginx -t
        systemctl restart nginx
        systemctl enable nginx
        systemctl restart php*-fpm
    fi
    
    print_green "$web_server configured successfully"
}

# Install WP-CLI
install_wp_cli() {
    print_green "Installing WP-CLI..."
    
    curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/bin/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    
    # Verify installation
    if wp --info >/dev/null 2>&1; then
        print_green "WP-CLI installed successfully"
    else
        print_yellow "WP-CLI installation may have issues, but continuing..."
    fi
}

# Complete WordPress installation via WP-CLI
complete_wordpress_installation() {
    print_green "Completing WordPress installation..."
    
    cd "$install_path"
    
    # Wait for database connection
    sleep 5
    
    # Install WordPress
    sudo -u www-data wp core install \
        --url="http://$domain_name" \
        --title="WordPress Site - $domain_name" \
        --admin_user="$wp_admin_user" \
        --admin_password="$wp_admin_pass" \
        --admin_email="$wp_admin_email" \
        --skip-email
    
    # Install essential plugins if using PostgreSQL
    if [[ $database == "postgresql" ]]; then
        sudo -u www-data wp plugin activate postgresql-for-wordpress
    fi
    
    print_green "WordPress installation completed"
}

# Save configuration
save_configuration() {
    print_green "Saving installation configuration..."
    
    local config_dir="/etc/wordpress-automation"
    local config_file="$config_dir/${domain_name}.conf"
    
    mkdir -p "$config_dir"
    
    cat > "$config_file" << EOF
# WordPress Installation Configuration for $domain_name
# Generated on $(date)

DOMAIN=$domain_name
WEB_SERVER=$web_server
DATABASE=$database
DB_NAME=$wp_db
DB_USER=$wp_user
DB_PASS=$wp_pass
WP_ADMIN_USER=$wp_admin_user
WP_ADMIN_PASS=$wp_admin_pass
WP_ADMIN_EMAIL=$wp_admin_email
INSTALL_PATH=$install_path
INSTALL_DATE=$(date)

# URLs
SITE_URL=http://$domain_name
ADMIN_URL=http://$domain_name/wp-admin

# Configuration Files
WEB_SERVER_CONFIG=$([[ $web_server == "apache" ]] && echo "/etc/apache2/sites-available/$domain_name.conf" || echo "/etc/nginx/sites-available/$domain_name")
EOF
    
    chmod 600 "$config_file"
    print_green "Configuration saved to $config_file"
}

# Display installation summary
display_summary() {
    print_green ""
    print_green "=========================================="
    print_green "   WordPress Installation Complete!      "
    print_green "=========================================="
    print_blue "Site Information:"
    echo "Domain: $domain_name"
    echo "Site URL: http://$domain_name"
    echo "Admin URL: http://$domain_name/wp-admin"
    echo ""
    print_blue "Credentials:"
    echo "Admin Username: $wp_admin_user"
    echo "Admin Password: $wp_admin_pass"
    echo "Admin Email: $wp_admin_email"
    echo ""
    print_blue "Database Information:"
    echo "Database Type: $database"
    echo "Database Name: $wp_db"
    echo "Database User: $wp_user"
    echo "Database Password: $wp_pass"
    echo ""
    print_blue "System Information:"
    echo "Web Server: $web_server"
    echo "Installation Path: $install_path"
    echo "PHP Version: $(php -v | head -n1 | cut -d' ' -f2)"
    echo ""
    print_yellow "IMPORTANT: Please save these credentials securely!"
    print_yellow "Configuration file: /etc/wordpress-automation/${domain_name}.conf"
    
    if [[ $database == "postgresql" ]]; then
        print_yellow ""
        print_yellow "NOTE: PostgreSQL support requires the 'postgresql-for-wordpress' plugin."
        print_yellow "This plugin has been automatically installed and activated."
    fi
    
    print_green ""
    print_green "You can now access your WordPress site at: http://$domain_name"
    print_green "Admin panel: http://$domain_name/wp-admin"
}

# Main installation function
main() {
    print_blue "=========================================="
    print_blue "        WordPress Auto Installer          "
    print_blue "=========================================="
    
    check_os
    check_root
    get_user_input
    
    print_yellow "Starting WordPress installation for $domain_name..."
    print_yellow "This may take a few minutes..."
    
    update_system
    install_web_server
    install_database
    setup_wordpress
    configure_web_server
    install_wp_cli
    complete_wordpress_installation
    save_configuration
    display_summary
    
    print_green "Installation completed successfully!"
}

# Error handling
trap 'print_red "An error occurred during installation. Check the logs and try again."; exit 1' ERR

# Run main function
main "$@"