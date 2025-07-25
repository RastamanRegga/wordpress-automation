#!/bin/bash
# WordPress Remover Script
# Removes WordPress installations created by the installer

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

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_red "This script must be run as root."
        exit 1
    fi
}

# List available WordPress installations
list_installations() {
    local config_dir="/etc/wordpress-automation"
    
    if [[ ! -d "$config_dir" ]] || [[ -z "$(ls -A "$config_dir" 2>/dev/null)" ]]; then
        print_red "No WordPress installations found."
        echo "Make sure you have installed WordPress using the installer script."
        exit 1
    fi
    
    print_blue "Available WordPress installations:"
    local count=0
    local configs=()
    
    for config in "$config_dir"/*.conf; do
        if [[ -f "$config" ]]; then
            count=$((count + 1))
            source "$config"
            configs+=("$config")
            echo "$count) $DOMAIN ($INSTALL_PATH)"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_red "No valid WordPress installations found."
        exit 1
    fi
    
    echo "$((count + 1))) Cancel"
    return $count
}

# Get user selection
get_user_selection() {
    local max_choice=$1
    
    read -p "Select installation to remove (1-$((max_choice + 1))): " choice
    
    if [[ "$choice" -eq $((max_choice + 1)) ]]; then
        print_yellow "Operation cancelled."
        exit 0
    elif [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$max_choice" ]]; then
        print_red "Invalid selection."
        exit 1
    fi
    
    return $((choice - 1))
}

# Load configuration
load_configuration() {
    local config_index=$1
    local config_dir="/etc/wordpress-automation"
    local configs=()
    
    for config in "$config_dir"/*.conf; do
        if [[ -f "$config" ]]; then
            configs+=("$config")
        fi
    done
    
    local selected_config="${configs[$config_index]}"
    
    if [[ ! -f "$selected_config" ]]; then
        print_red "Configuration file not found: $selected_config"
        exit 1
    fi
    
    source "$selected_config"
    CONFIG_FILE="$selected_config"
}

# Confirm removal
confirm_removal() {
    print_red "=========================================="
    print_red "   WARNING: COMPLETE REMOVAL            "
    print_red "=========================================="
    print_yellow "This will permanently remove:"
    echo "• Domain: $DOMAIN"
    echo "• WordPress files: $INSTALL_PATH"
    echo "• Database: $DB_NAME ($DATABASE)"
    echo "• Web server configuration"
    echo "• All website data and content"
    echo ""
    print_red "This action CANNOT be undone!"
    echo ""
    
    read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirmation
    
    if [[ "$confirmation" != "DELETE" ]]; then
        print_yellow "Operation cancelled. No changes were made."
        exit 0
    fi
    
    print_yellow "Starting removal in 5 seconds... Press Ctrl+C to cancel"
    sleep 5
}

# Create backup option
offer_backup() {
    print_yellow "Do you want to create a backup before removal?"
    read -p "Create backup? (y/N): " backup_choice
    
    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        create_backup
    fi
}

# Create backup
create_backup() {
    print_green "Creating backup..."
    
    local backup_dir="/tmp/wordpress-backup-${DOMAIN}-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup files
    if [[ -d "$INSTALL_PATH" ]]; then
        print_blue "Backing up WordPress files..."
        tar -czf "$backup_dir/wordpress-files.tar.gz" -C "$INSTALL_PATH" . 2>/dev/null || {
            print_yellow "Warning: Some files may not have been backed up due to permissions"
        }
    fi
    
    # Backup database
    print_blue "Backing up database..."
    if [[ "$DATABASE" == "mysql" ]]; then
        mysqldump "$DB_NAME" > "$backup_dir/database.sql" 2>/dev/null || {
            print_yellow "Warning: Database backup may be incomplete"
        }
    else
        sudo -u postgres pg_dump "$DB_NAME" > "$backup_dir/database.sql" 2>/dev/null || {
            print_yellow "Warning: Database backup may be incomplete"
        }
    fi
    
    # Save configuration
    cp "$CONFIG_FILE" "$backup_dir/wordpress-config.conf"
    
    # Create restore instructions
    cat > "$backup_dir/RESTORE_INSTRUCTIONS.txt" << EOF
WordPress Backup for $DOMAIN
Created: $(date)
========================================

Files:
- wordpress-files.tar.gz: All WordPress files
- database.sql: Database dump
- wordpress-config.conf: Installation configuration

To restore:
1. Extract files: tar -xzf wordpress-files.tar.gz -C /path/to/restore/
2. Import database:
   MySQL: mysql -u$DB_USER -p$DB_PASS $DB_NAME < database.sql
   PostgreSQL: PGPASSWORD=$DB_PASS psql -U $DB_USER $DB_NAME < database.sql
3. Update wp-config.php with new database credentials if needed
4. Set proper file permissions: chown -R www-data:www-data /path/to/restore/

Original Configuration:
Domain: $DOMAIN
Install Path: $INSTALL_PATH
Web Server: $WEB_SERVER
Database: $DB_NAME ($DATABASE)
EOF
    
    print_green "Backup created at: $backup_dir"
}

# Remove WordPress files
remove_wordpress_files() {
    print_blue "Removing WordPress files..."
    
    if [[ -d "$INSTALL_PATH" ]]; then
        rm -rf "$INSTALL_PATH"
        print_green "WordPress files removed from $INSTALL_PATH"
    else
        print_yellow "WordPress directory not found: $INSTALL_PATH"
    fi
    
    # Remove parent directory if empty
    local parent_dir=$(dirname "$INSTALL_PATH")
    if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
        rmdir "$parent_dir" 2>/dev/null || true
        print_green "Empty parent directory removed: $parent_dir"
    fi
}

# Remove database
remove_database() {
    print_blue "Removing database and user..."
    
    if [[ "$DATABASE" == "mysql" ]]; then
        # Check and remove database
        if mysql -e "USE $DB_NAME" 2>/dev/null; then
            mysql -e "DROP DATABASE $DB_NAME;"
            print_green "MySQL database '$DB_NAME' removed"
        else
            print_yellow "MySQL database '$DB_NAME' not found"
        fi
        
        # Check and remove user
        if mysql -e "SELECT User FROM mysql.user WHERE User='$DB_USER'" 2>/dev/null | grep -q "$DB_USER"; then
            mysql -e "DROP USER '$DB_USER'@'localhost';"
            mysql -e "FLUSH PRIVILEGES;"
            print_green "MySQL user '$DB_USER' removed"
        else
            print_yellow "MySQL user '$DB_USER' not found"
        fi
    else
        # PostgreSQL
        if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
            sudo -u postgres psql -c "DROP DATABASE $DB_NAME;"
            print_green "PostgreSQL database '$DB_NAME' removed"
        else
            print_yellow "PostgreSQL database '$DB_NAME' not found"
        fi
        
        if sudo -u postgres psql -c "\du" | grep -q "$DB_USER"; then
            sudo -u postgres psql -c "DROP USER $DB_USER;"
            print_green "PostgreSQL user '$DB_USER' removed"
        else
            print_yellow "PostgreSQL user '$DB_USER' not found"
        fi
    fi
}

# Remove web server configuration
remove_web_server_config() {
    print_blue "Removing web server configuration..."
    
    if [[ "$WEB_SERVER" == "apache" ]]; then
        local apache_config="/etc/apache2/sites-available/$DOMAIN.conf"
        
        if [[ -f "$apache_config" ]]; then
            a2dissite "$DOMAIN.conf" 2>/dev/null || true
            rm -f "$apache_config"
            print_green "Apache configuration removed"
            
            # Restart Apache
            systemctl reload apache2 2>/dev/null || systemctl restart apache2
        else
            print_yellow "Apache configuration not found"
        fi
    else
        local nginx_config="/etc/nginx/sites-available/$DOMAIN"
        
        if [[ -f "$nginx_config" ]]; then
            rm -f "/etc/nginx/sites-enabled/$DOMAIN"
            rm -f "$nginx_config"
            print_green "Nginx configuration removed"
            
            # Restart Nginx
            systemctl reload nginx 2>/dev/null || systemctl restart nginx
        else
            print_yellow "Nginx configuration not found"
        fi
    fi
}

# Remove SSL certificates
remove_ssl_certificates() {
    print_blue "Checking for SSL certificates..."
    
    if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
        read -p "SSL certificates found. Remove them? (y/N): " ssl_choice
        
        if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
            if command -v certbot &> /dev/null; then
                certbot delete --cert-name "$DOMAIN" --non-interactive 2>/dev/null || {
                    print_yellow "Could not remove SSL certificates via certbot, removing manually..."
                    rm -rf "/etc/letsencrypt/live/$DOMAIN"
                    rm -rf "/etc/letsencrypt/archive/$DOMAIN"
                    rm -f "/etc/letsencrypt/renewal/$DOMAIN.conf"
                }
                print_green "SSL certificates removed"
            else
                rm -rf "/etc/letsencrypt/live/$DOMAIN"
                rm -rf "/etc/letsencrypt/archive/$DOMAIN"
                rm -f "/etc/letsencrypt/renewal/$DOMAIN.conf"
                print_green "SSL certificate files removed"
            fi
        fi
    else
        print_yellow "No SSL certificates found for $DOMAIN"
    fi
}

# Remove log files
remove_logs() {
    print_blue "Removing log files..."
    
    if [[ "$WEB_SERVER" == "apache" ]]; then
        rm -f "/var/log/apache2/${DOMAIN}_error.log"
        rm -f "/var/log/apache2/${DOMAIN}_access.log"
        rm -f "/var/log/apache2/${DOMAIN}_ssl_error.log"
        rm -f "/var/log/apache2/${DOMAIN}_ssl_access.log"
    else
        rm -f "/var/log/nginx/${DOMAIN}.access.log"
        rm -f "/var/log/nginx/${DOMAIN}.error.log"
    fi
    
    print_green "Log files removed"
}

# Remove cron jobs
remove_cron_jobs() {
    print_blue "Removing related cron jobs..."
    
    # Remove any cron jobs related to this domain or installation path
    (crontab -l 2>/dev/null | grep -v "$DOMAIN" | grep -v "$INSTALL_PATH") | crontab - 2>/dev/null || true
    
    # Remove automated backup scripts if they exist
    local backup_script="/usr/local/bin/wordpress-backup-$DOMAIN.sh"
    if [[ -f "$backup_script" ]]; then
        rm -f "$backup_script"
        print_green "Automated backup script removed"
    fi
    
    print_green "Cron jobs cleaned"
}

# Remove configuration file
remove_configuration() {
    print_blue "Removing configuration file..."
    
    if [[ -f "$CONFIG_FILE" ]]; then
        rm -f "$CONFIG_FILE"
        print_green "Configuration file removed: $CONFIG_FILE"
    fi
    
    # Remove automation directory if empty
    local config_dir="/etc/wordpress-automation"
    if [[ -d "$config_dir" ]] && [[ -z "$(ls -A "$config_dir" 2>/dev/null)" ]]; then
        rmdir "$config_dir"
        print_green "Empty automation directory removed"
    fi
}

# Optional: Remove packages if no other sites
offer_package_removal() {
    print_yellow "Do you want to remove web server and database packages?"
    print_yellow "WARNING: This will affect ALL websites on this server!"
    read -p "Remove packages ($WEB_SERVER, $DATABASE, PHP)? (y/N): " package_choice
    
    if [[ "$package_choice" =~ ^[Yy]$ ]]; then
        print_red "This will remove $WEB_SERVER, $DATABASE, and PHP packages!"
        read -p "Are you absolutely sure? Type 'REMOVE PACKAGES': " package_confirm
        
        if [[ "$package_confirm" == "REMOVE PACKAGES" ]]; then
            remove_packages
        else
            print_yellow "Package removal cancelled"
        fi
    fi
}

# Remove packages
remove_packages() {
    print_blue "Removing packages..."
    
    # Stop services first
    systemctl stop apache2 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    systemctl stop mysql 2>/dev/null || true
    systemctl stop mariadb 2>/dev/null || true
    systemctl stop postgresql 2>/dev/null || true
    
    # Remove packages
    if [[ "$WEB_SERVER" == "apache" ]]; then
        apt remove --purge -y apache2 apache2-* libapache2-* 2>/dev/null || true
    else
        apt remove --purge -y nginx nginx-* 2>/dev/null || true
    fi
    
    if [[ "$DATABASE" == "mysql" ]]; then
        apt remove --purge -y mysql-server mysql-client mysql-* mariadb-* 2>/dev/null || true
    else
        apt remove --purge -y postgresql postgresql-* 2>/dev/null || true
    fi
    
    # Remove PHP
    apt remove --purge -y php php-* 2>/dev/null || true
    
    # Remove WP-CLI
    rm -f /usr/local/bin/wp
    
    # Clean up
    apt autoremove -y 2>/dev/null || true
    apt autoclean 2>/dev/null || true
    
    # Remove configuration directories
    rm -rf /etc/apache2 2>/dev/null || true
    rm -rf /etc/nginx 2>/dev/null || true
    rm -rf /var/www 2>/dev/null || true
    rm -rf /var/lib/mysql 2>/dev/null || true
    rm -rf /var/lib/postgresql 2>/dev/null || true
    
    print_green "Packages removed successfully"
}

# Display removal summary
display_summary() {
    print_green ""
    print_green "=========================================="
    print_green "   WordPress Removal Complete!          "
    print_green "=========================================="
    print_blue "Removed:"
    echo "• Domain: $DOMAIN"
    echo "• WordPress files from: $INSTALL_PATH"
    echo "• Database: $DB_NAME ($DATABASE)"
    echo "• Database user: $DB_USER"
    echo "• Web server configuration"
    echo "• Log files"
    echo "• Configuration file"
    echo ""
    print_green "WordPress installation has been completely removed."
    
    # Check if backup was created
    local backup_pattern="/tmp/wordpress-backup-${DOMAIN}-*"
    if ls $backup_pattern 1> /dev/null 2>&1; then
        local latest_backup=$(ls -dt $backup_pattern | head -n1)
        print_yellow "Backup available at: $latest_backup"
    fi
}

# Interactive mode - select from available installations
interactive_mode() {
    print_blue "=========================================="
    print_blue "          WordPress Remover               "
    print_blue "=========================================="
    
    local max_choice
    max_choice=$(list_installations)
    
    local selection
    get_user_selection $max_choice
    selection=$?
    
    load_configuration $selection
    confirm_removal
    offer_backup
    
    perform_removal
}

# Direct mode - remove specific domain
direct_mode() {
    local domain="$1"
    local config_file="/etc/wordpress-automation/${domain}.conf"
    
    if [[ ! -f "$config_file" ]]; then
        print_red "Configuration file not found for domain: $domain"
        print_yellow "Available domains:"
        list_installations
        exit 1
    fi
    
    source "$config_file"
    CONFIG_FILE="$config_file"
    
    print_blue "Removing WordPress installation for: $DOMAIN"
    confirm_removal
    offer_backup
    
    perform_removal
}

# Perform the actual removal
perform_removal() {
    print_yellow "Starting removal process..."
    
    remove_wordpress_files
    remove_database
    remove_web_server_config
    remove_ssl_certificates
    remove_logs
    remove_cron_jobs
    remove_configuration
    offer_package_removal
    
    display_summary
    print_green "Removal completed successfully!"
}

# Show help
show_help() {
    echo "WordPress Remover"
    echo "Usage: $0 [domain]"
    echo ""
    echo "Options:"
    echo "  domain    Remove specific WordPress installation"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive mode - select from list"
    echo "  $0 example.com        # Remove specific domain"
    echo ""
    echo "The script will:"
    echo "• Remove WordPress files and directories"
    echo "• Drop database and database user"
    echo "• Remove web server configuration"
    echo "• Clean up SSL certificates (optional)"
    echo "• Remove log files and cron jobs"
    echo "• Offer to create backup before removal"
    echo "• Optionally remove packages if no other sites exist"
}

# Main function
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        "")
            # Interactive mode
            check_root
            interactive_mode
            ;;
        *)
            # Direct mode with domain
            check_root
            direct_mode "$1"
            ;;
    esac
}

# Error handling
trap 'print_red "An error occurred during removal. Check the output above for details."; exit 1' ERR

# Run main function
main "$@"