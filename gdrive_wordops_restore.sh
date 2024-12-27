#!/bin/bash
# Script to restore a WordPress site from Google Drive backups and set up a new domain with WordOps

# Step 1: Install gdown
if ! command -v gdown &> /dev/null
then
    echo "Installing gdown..."
    sudo apt update
    sudo apt install -y python3-pip
    pip3 install gdown
else
    echo "gdown is already installed."
fi

# Step 2: Prompt for old domain, new domain, and Google Drive links
read -p "Enter the old domain name (e.g., olddomain.tld): " OLDDOMAIN
read -p "Enter the new domain name (e.g., newdomain.tld): " NEWDOMAIN
read -p "Enter the Google Drive file URL for the website (ZIP file): " GDRIVE_WEBSITE_URL

# Step 3: Create a new WordPress site with WordOps (with error checking)
echo "Creating a new WordPress site for $NEWDOMAIN..."
if ! wo site create $NEWDOMAIN --wp; then
    echo "Failed to create WordPress site for $NEWDOMAIN. Exiting."
    exit 1
fi

# Step 4: Clean default data from the new site
sudo -u www-data -H wp db clean --yes --path=/var/www/$NEWDOMAIN/htdocs
rm -rf /var/www/$NEWDOMAIN/htdocs/*

# Step 5: Download the website file using gdown
echo "Downloading website backup from Google Drive..."
gdown "$GDRIVE_WEBSITE_URL" -O /var/www/$NEWDOMAIN/website_backup.zip

# Step 6: Extract the website backup file
echo "Extracting website backup..."
unzip /var/www/$NEWDOMAIN/website_backup.zip -d /var/www/$NEWDOMAIN/htdocs
rm /var/www/$NEWDOMAIN/website_backup.zip

# Step 7: Locate and import the database
DB_FILE=$(find /var/www/$NEWDOMAIN/htdocs -name "*.sql")
if [ -f "$DB_FILE" ]; then
    echo "Importing database from $DB_FILE..."
    wp db import "$DB_FILE" --allow-root
    rm "$DB_FILE"
else
    echo "Database file not found in the extracted website backup. Please check manually."
    exit 1
fi

# Step 8: Update URLs in the database
echo "Updating URLs from $OLDDOMAIN to $NEWDOMAIN..."
wp search-replace "http://$OLDDOMAIN" "https://$NEWDOMAIN" --skip-columns=guid --allow-root

# Step 9: Enable SSL for the new domain
echo "Enabling SSL for $NEWDOMAIN..."
wo site update $NEWDOMAIN -le

# Completion message
echo "The WordPress site from $OLDDOMAIN has been successfully restored and set up for $NEWDOMAIN."
