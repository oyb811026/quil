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
                          ✨ gRPC 调用设置 ✨
============================================================================
此脚本将编辑您的 .config/config.yml 文件并设置 gRPC 调用。

请按照 Quilibrium 节点指南操作：https://docs.quilibrium.one

由 LaMat 制作 🔥 - https://quilibrium.one
============================================================================

处理中... ⏳

EOF

sleep 5  # 延迟以便用户阅读信息

# 检查文件中是否存在某行的函数
line_exists() {
    grep -qF "$1" "$2"
}

# 在特定模式后添加一行的函数
add_line_after_pattern() {
    sed -i '' "/^ *$1:/a\\
  $2" "$3" || { echo "❌ 无法在 '$1' 后添加行！退出..."; exit 1; }
}

# 步骤 1：启用 gRPC 和 REST
echo "🚀 启用 gRPC 和 REST..."
sleep 1
cd "$HOME/ceremonyclient/node" || { echo "❌ 无法切换目录到 ~/ceremonyclient/node！退出..."; exit 1; }

# 删除现有的 listenGrpcMultiaddr 和 listenRESTMultiaddr 行（如果存在）
sed -i '' '/^ *listenGrpcMultiaddr:/d' .config/config.yml
sed -i '' '/^ *listenRESTMultiaddr:/d' .config/config.yml

# 添加 listenGrpcMultiaddr: "/ip4/127.0.0.1/tcp/8337"
echo "listenGrpcMultiaddr: \"/ip4/127.0.0.1/tcp/8337\"" | tee -a .config/config.yml > /dev/null || { echo "❌ 无法启用 gRPC！退出..."; exit 1; }

# 添加 listenRESTMultiaddr: "/ip4/127.0.0.1/tcp/8338"
echo "listenRESTMultiaddr: \"/ip4/127.0.0.1/tcp/8338\"" | tee -a .config/config.yml > /dev/null || { echo "❌ 无法启用 REST！退出..."; exit 1; }

sleep 1

# 步骤 2：启用统计收集
echo "📊 启用统计收集..."
if ! line_exists "statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\"" .config/config.yml; then
    add_line_after_pattern "engine" "statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\"" .config/config.yml
    echo "✅ 统计收集已启用。"
else
    echo "✅ 统计收集已经启用。"
fi

sleep 1

# 步骤 3：检查和修改 listenMultiaddr
echo "🔍 检查 listenMultiaddr..."
if grep -qF "  listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic" .config/config.yml; then
    echo "🛠️ 正在修改 listenMultiaddr..."
    sed -i '' -E 's|^ *  listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic *$|  listenMultiaddr: /ip4/0.0.0.0/tcp/8336|' .config/config.yml
    if [ $? -eq 0 ]; then
        echo "✅ listenMultiaddr 已修改为使用 TCP 协议。"
    else
        echo "❌ 无法修改 listenMultiaddr！请手动检查 config.yml 文件。"
    fi
else
    # 检查新的 listenMultiaddr 是否存在
    if grep -qF "  listenMultiaddr: /ip4/0.0.0.0/tcp/8336" .config/config.yml; then
        echo "✅ 找到了新的 listenMultiaddr 行。"
    else
        echo "❌ 既没有找到旧的也没有找到新的 listenMultiaddr。可能会导致问题。请手动检查 config.yml 文件。"
    fi
fi

sleep 1

echo ""
echo "✅ gRPC、REST 和统计收集设置成功。"
echo ""
echo "✅ 如果您想手动检查，请运行：cd /root/ceremonyclient/node/.config/ && cat config.yml"
sleep 5
