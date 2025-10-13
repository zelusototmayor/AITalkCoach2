#!/bin/bash

# Setup script for local subdomain testing
# Run with: sudo ./setup_local_domains.sh

echo "Setting up local domains for AI Talk Coach..."

# Check if entries already exist
if grep -q "aitalkcoach.local" /etc/hosts; then
    echo "✓ Local domains already configured in /etc/hosts"
else
    echo "Adding local domains to /etc/hosts..."
    echo "" >> /etc/hosts
    echo "# AI Talk Coach local development domains" >> /etc/hosts
    echo "127.0.0.1 aitalkcoach.local" >> /etc/hosts
    echo "127.0.0.1 app.aitalkcoach.local" >> /etc/hosts
    echo "127.0.0.1 www.aitalkcoach.local" >> /etc/hosts
    echo "✓ Local domains added to /etc/hosts"
fi

echo ""
echo "Setup complete! You can now access:"
echo "  - Marketing site: http://aitalkcoach.local:3000"
echo "  - Application:    http://app.aitalkcoach.local:3000"
echo ""
echo "Make sure your Rails server is running on port 3000"
