#!/bin/bash

cat << "EOF"

                      QQQQQQQQQ       1111111   
                    QQ:::::::::QQ    1::::::1   
                  QQ:::::::::::::QQ 1:::::::1   
                 Q:::::::QQQ:::::::Q111:::::1   
                 Q::::::O   Q::::::Q   1::::1   
                 Q:::::O     Q:::::Q   1::::1   
                 Q:::::O     Q:::::Q   1::::1   
                 Q:::::O     Q:::::Q   1::::l   
                 Q:::::O     Q:::::Q   1::::l   
                 Q:::::O     Q:::::Q   1::::l   
                 Q:::::O  QQQQ:::::Q   1::::l   
                 Q::::::O Q::::::::Q   1::::l   
                 Q:::::::QQ::::::::Q111::::::111
                  QQ::::::::::::::Q 1::::::::::1
                    QQ:::::::::::Q  1::::::::::1
                      QQQQQQQQ::::QQ111111111111
                              Q:::::Q           
                               QQQQQQ  QUILIBRIUM.ONE                                                                                                                                  


============================================================================
                          ✨ gRPC Calls SETUP ✨
============================================================================
This script will edit your .config/config.yml file and setup the gRPC calls.

Follow the Quilibrium Node guide at https://docs.quilibrium.one

Made with 🔥 by LaMat - https://quilibrium.one
============================================================================

Processing... ⏳

EOF

sleep 5  # Add a 5-second delay

# Function to check if a line exists in a file
line_exists() {
    grep -qF "$1" "$2"
}

# Function to add a line after a specific pattern
add_line_after_pattern() {
    sed -i '' "/^ *$1:/a\\
  $2
" "$3" || { echo "❌ Failed to add line after '$1'! Exiting..."; exit 1; }
}

# Step 1: Enable gRPC and REST
echo "🚀 Enabling gRPC and REST..."
sleep 1
cd "$HOME/ceremonyclient/node" || { echo "❌ Failed to change directory to ~/ceremonyclient/node! Exiting..."; exit 1; }

# Delete existing lines for listenGrpcMultiaddr and listenRESTMultiaddr if they exist
sed -i '' '/^ *listenGrpcMultiaddr:/d' .config/config.yml
sed -i '' '/^ *listenRESTMultiaddr:/d' .config/config.yml

# Add listenGrpcMultiaddr: "/ip4/127.0.0.1/tcp/8337"
echo "listenGrpcMultiaddr: \"/ip4/127.0.0.1/tcp/8337\"" >> .config/config.yml || { echo "❌ Failed to enable gRPC! Exiting..."; exit 1; }

# Add listenRESTMultiaddr: "/ip4/127.0.0.1/tcp/8338"
echo "listenRESTMultiaddr: \"/ip4/127.0.0.1/tcp/8338\"" >> .config/config.yml || { echo "❌ Failed to enable REST! Exiting..."; exit 1; }

sleep 1

# Step 2: Enable Stats Collection
echo "📊 Enabling Stats Collection..."
if ! line_exists "statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\"" .config/config.yml; then
    add_line_after_pattern "engine" "statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\"" .config/config.yml
    echo "✅ Stats Collection enabled."
else
    echo "✅ Stats Collection already enabled."
fi

sleep 1

# Step 3: Check and modify listenMultiaddr
echo "🔍 Checking listenMultiaddr..."
if grep -qF "  listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic" .config/config.yml; then
    echo "🛠️ Modifying listenMultiaddr..."
    sed -i '' 's|^ *  listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic *$|  listenMultiaddr: /ip4/0.0.0.0/tcp/8336|' .config/config.yml
    if [ $? -eq 0 ]; then
        echo "✅ listenMultiaddr modified to use TCP protocol."
    else
        echo "❌ Failed to modify listenMultiaddr! Please check manually your config.yml file"
    fi
else
    # Check if the new listenMultiaddr exists
    if grep -qF "  listenMultiaddr: /ip4/0.0.0.0/tcp/8336" .config/config.yml; then
        echo "✅ New listenMultiaddr line found."
    else
        echo "❌ Neither old nor new listenMultiaddr found. This could cause issues. Please check manually your config.yml file"
    fi
fi

sleep 1

echo ""
echo "✅ gRPC, REST, and Stats Collection setup was successful."
echo ""
echo "✅ If you want to check manually just run: cd /root/ceremonyclient/node/.config/ && cat config.yml"
sleep 5
