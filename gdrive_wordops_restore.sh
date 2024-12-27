#!/bin/bash
# Script to restore a WordPress site from Google Drive backups and set up a new domain with WordOps

# Step 1: Prompt for old domain, new domain, and Google Drive links
read -p "Enter the old domain name (e.g., olddomain.tld): " OLDDOMAIN
read -p "Enter the new domain name (e.g., newdomain.tld): " NEWDOMAIN
read -p "Enter the Google Drive file URL for the website (ZIP file): " GDRIVE_WEBSITE_URL
read -p "Enter the Google Drive file URL for the database (SQL file): " GDRIVE_DATABASE_URL

# Step 2: Create a new WordPress site with WordOps (with error checking)
echo "Creating a new WordPress site for $NEWDOMAIN..."
if ! wo site create $NEWDOMAIN --wp; then
    echo "Failed to create WordPress site for $NEWDOMAIN. Exiting."
    exit 1
fi

# Step 3: Install gdown if not already installed
if ! command -v gdown &> /dev/null
then
    echo "Installing gdown..."
    sudo apt update
    sudo apt install -y python3-pip
    pip3 install gdown
else
    echo "gdown is already installed."
fi

# Step 4: Download the website file using gdown
cd /var/www/$NEWDOMAIN

echo "Downloading website backup from Google Drive..."
gdown --fuzzy "$GDRIVE_WEBSITE_URL" -O website_backup.zip

echo "Downloading database backup from Google Drive..."
gdown --fuzzy "$GDRIVE_DATABASE_URL" -O database_backup.sql

# Step 5: Extract the website backup file
echo "Extracting website backup..."
unzip website_backup.zip -d htdocs
rm website_backup.zip

# Step 6: Import the database
DB_FILE="/var/www/$NEWDOMAIN/database_backup.sql"
if [ -f "$DB_FILE" ]; then
    echo "Importing database from $DB_FILE..."
    wp db import "$DB_FILE" --allow-root
    rm "$DB_FILE"
else
    echo "Database file not found. Please check manually."
    exit 1
fi

# Step 7: Update URLs in the database
echo "Updating URLs from $OLDDOMAIN to $NEWDOMAIN..."
wp search-replace "http://$OLDDOMAIN" "https://$NEWDOMAIN" --skip-columns=guid --allow-root

# Step 8: Enable SSL for the new domain
echo "Enabling SSL for $NEWDOMAIN..."
wo site update $NEWDOMAIN -le

# Completion message
echo "The WordPress site from $OLDDOMAIN has been successfully restored and set up for $NEWDOMAIN."
