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

sleep 5  # 添加5秒的延迟

# 检查行是否存在于文件中的函数
line_exists() {
    grep -qF "$1" "$2"
}

# 在特定模式之后添加行的函数
add_line_after_pattern() {
    sed -i "" "/^ *$1:/a\\
  $2" "$3" || { echo "❌ Failed to add line after '$1'! Exiting..."; exit 1; }
}

# 步骤 1：启用 gRPC 和 REST
echo "🚀 Enabling gRPC and REST..."
sleep 1
cd "$HOME/ceremonyclient/node" || { echo "❌ Failed to change directory to ~/ceremonyclient/node! Exiting..."; exit 1; }

# 删除现有的 listenGrpcMultiaddr 和 listenRESTMultiaddr 行（如果存在）
sed -i "" '/^ *listenGrpcMultiaddr:/d' .config/config.yml
sed -i "" '/^ *listenRESTMultiaddr:/d' .config/config.yml

# 添加 listenGrpcMultiaddr: "/ip4/127.0.0.1/tcp/8337"
echo "listenGrpcMultiaddr: \"/ip4/127.0.0.1/tcp/8337\"" | tee -a .config/config.yml > /dev/null || { echo "❌ Failed to enable gRPC! Exiting..."; exit 1; }

# 添加 listenRESTMultiaddr: "/ip4/127.0.0.1/tcp/8338"
echo "listenRESTMultiaddr: \"/ip4/127.0.0.1/tcp/8338\"" | tee -a .config/config.yml > /dev/null || { echo "❌ Failed to enable REST! Exiting..."; exit 1; }

sleep 1

# 步骤 2：启用统计收集
echo "📊 Enabling Stats Collection..."
if ! line_exists "statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\"" .config/config.yml; then
    add_line_after_pattern "engine" "statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\"" .config/config.yml
    echo "✅ Stats Collection enabled."
else
    echo "✅ Stats Collection already enabled."
fi

sleep 1

# 步骤 3：检查并修改 listenMultiaddr
echo "🔍 Checking listenMultiaddr..."
if grep -qF "  listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic" .config/config.yml; then
    echo "🛠️ Modifying listenMultiaddr..."
    sed -i "" -E 's|^ *  listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic *$|  listenMultiaddr: /ip4/0.0.0.0/tcp/8336|' .config/config.yml
    if [ $? -eq 0 ]; then
        echo "✅ listenMultiaddr modified to use TCP protocol."
    else
        echo "❌ Failed to modify listenMultiaddr! Please check manually your config.yml file"
    fi
else
    # 检查新 listenMultiaddr 是否存在
    if grep -qF "  listenMultiaddr: /ip4/0.0.0.0/tcp/8336" .config/config.yml; then
        echo "✅ New listenMultiaddr line found."
    else
        echo "❌ Neither old nor new listenMultiaddr found. This could cause issues. Please check manually your config.yml file"
    fi
fi

sleep 1

echo""
echo "✅ gRPC, REST, and Stats Collection setup was successful."
echo""
echo "✅ If you want to check manually just run: cd ~/ceremonyclient/node/.config/ && cat config.yml"
sleep 5
