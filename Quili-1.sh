#!/bin/bash

# 节点安装功能
function install_node() {
    # 获取内存大小（单位：GB）
    mem_size=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    
    # 获取当前swap大小（单位：GB）
    swap_size=$(sysctl -n vm.swapusage | awk '{print int($3/1024/1024/1024)}')
    
    # 计算期望的swap大小（内存的两倍或者32GB中的较小者）
    desired_swap_size=$((mem_size * 2))
    if ((desired_swap_size >= 32)); then
        desired_swap_size=32
    fi
    
    # 检查当前swap大小是否满足要求
    if ((swap_size < desired_swap_size)) && ((swap_size < 32)); then
        echo "当前swap大小不足。正在将swap大小设置为 $desired_swap_size GB..."
        
        # 关闭所有swap分区
        sudo swapoff -a
        
        # 分配新的swap文件
        sudo dd if=/dev/zero of=/swapfile bs=1g count=$desired_swap_size
        
        # 设置正确的文件权限
        sudo chmod 600 /swapfile
        
        # 设置swap分区
        sudo mkswap /swapfile
        
        # 启用swap分区
        sudo swapon /swapfile
        
        # 添加swap分区至fstab，确保开机时自动挂载
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        
        echo "Swap大小已设置为 $desired_swap_size GB。"
    else
        echo "当前swap大小已经满足要求或大于等于32GB，无需改动。"
    fi
    
    brew update
    brew install git ufw bison screen binutils gcc make jq coreutils
    
    # 设置缓存
    echo -e "\n\n# set for Quil" | sudo tee -a /etc/sysctl.conf
    echo "net.core.rmem_max=600000000" | sudo tee -a /etc/sysctl.conf
    echo "net.core.wmem_max=600000000" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # 安装GVM
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source $HOME/.gvm/scripts/gvm
    
    gvm install go1.4 -B
    gvm use go1.4
    export GOROOT_BOOTSTRAP=$GOROOT
    gvm install go1.17.13
    gvm use go1.17.13
    export GOROOT_BOOTSTRAP=$GOROOT
    gvm install go1.20.2
    gvm use go1.20.2
    export GOROOT_BOOTSTRAP=$GOROOT
    gvm install go1.22.4
    gvm use go1.22.4
    
    # github仓库
    git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
    cd $HOME/ceremonyclient/
    git pull
    git checkout release
    
    sudo tee /Library/LaunchDaemons/ceremonyclient.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ceremonyclient</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/ceremonyclient/node/release_autorun.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$HOME/ceremonyclient/node</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>GOEXPERIMENT</key>
        <string>arenas</string>
    </dict>
</dict>
</plist>
EOF

    sudo launchctl load /Library/LaunchDaemons/ceremonyclient.plist
    sudo launchctl start ceremonyclient

    rm $HOME/go/bin/qclient
    cd $HOME/ceremonyclient/client
    GOEXPERIMENT=arenas go build -o $HOME/go/bin/qclient main.go
    # building grpcurl
    cd ~
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    echo "部署完成"
}

# 备份节点
function backup_key(){
    # 文件路径
    sudo chown -R $USER:$USER $HOME/ceremonyclient/node/.config/
    cd $HOME/ceremonyclient/node/
    # 检查是否安装了zip
    if ! command -v zip &> /dev/null; then
        echo "zip is not installed. Installing now..."
        brew install zip
    fi
    
    # 创建压缩文件
    zip -r ~/quil_bak_$(date +%Y%m%d).zip .config
    echo "已将 .config目录压缩并保存到$HOME下"
}

# 查看日志
function view_logs(){
    sudo log show --predicate 'process == "ceremonyclient"' --info --style compact
}

# 查看节点状态
function view_status(){
    sudo launchctl list | grep ceremonyclient
}

# 停止节点
function stop_node(){
    sudo launchctl stop ceremonyclient
    echo "quil 节点已停止"
}

# 启动节点
function start_node(){
    sudo launchctl start ceremonyclient
    echo "quil 节点已启动"
}

# 卸载节点
function uninstall_node(){
    sudo launchctl stop ceremonyclient
    sudo launchctl unload /Library/LaunchDaemons/ceremonyclient.plist
    rm -rf $HOME/ceremonyclient
    rm -rf $HOME/check_and_restart.sh
    echo "卸载完成。"
}

# 查询节点信息
function check_node_info(){
    sudo chown -R $USER:$USER $HOME/ceremonyclient/node/.config/
    cd ~/ceremonyclient/node && ./node-1.4.21-darwin-amd64 -node-info
}

# 查询余额
function check_balance(){
    sudo chown -R $USER:$USER $HOME/ceremonyclient/node/.config/
    cd ~/ceremonyclient/node && ./node-1.4.21.1-darwin-amd64 -node-info
}

# 安装gRPC
function install_grpc(){
    sudo chown -R $USER:$USER $HOME/ceremonyclient/node/.config/
    # 检查当前 Go 版本
    current_go_version=$(go version | awk '{print $3}')
    
    # 解析版本号并比较
    if [[ "$current_go_version" < "go1.22.4" ]]; then
        # 如果当前版本低于1.22.4，则使用 GVM 安装1.22.4
        echo "当前 Go 版本为 $current_go_version，低于1.22.4，开始安装1.22.4版本..."
        source $HOME/.gvm/scripts/gvm
        gvm install go1.22.4
        gvm use go1.22.4 --default
    else
        echo "当前 Go 版本为 $current_go_version，不需要更新。"
    fi

    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    wget --no-cache -O - https://raw.githubusercontent.com/oyb811026/quil/main/qnode_gRPC_calls_setup.sh | bash
    stop_node
    start_node
}

# 健康状态
function check_heal(){
    sudo log show --predicate 'process == "ceremonyclient"' --info --style compact | awk '/"current_frame"/ {print $1, $2, $3, $7}'
    echo "提取了当天的日志，如果current_frame一直在增加，说明程序运行正常"
}

# 升级程序
function update_quil(){
    echo "等待官方新版释放..."
}

# 限制CPU使用率
function cpu_limited_rate(){
    read -p "输入每个CPU允许quil使用占比(如60%输入0.6，最大1):" cpu_rate
    comparison=$(echo "$cpu_rate >= 1" | bc)
    if [ "$comparison" -eq 1 ]; then
        cpu_rate=1
    fi
    
    cpu_core=$(sysctl -n hw.ncpu)
    limit_rate=$(echo "scale=2; $cpu_rate * $cpu_core * 100" | bc)
    echo "最终限制的CPU使用率为：$limit_rate%"
    echo "正在重启，请稍等..."
    
    stop_node
    sudo rm -f /Library/LaunchDaemons/ceremonyclient.plist
    sudo tee /Library/LaunchDaemons/ceremonyclient.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ceremonyclient</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/ceremonyclient/node/release_autorun.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$HOME/ceremonyclient/node</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>GOEXPERIMENT</key>
        <string>arenas</string>
    </dict>
    <key>CPUQuota</key>
    <string>$limit_rate%</string>
</dict>
</plist>
EOF

    sudo launchctl load /Library/LaunchDaemons/ceremonyclient.plist
    sudo launchctl start ceremonyclient
    sudo chown -R $USER:$USER $HOME/ceremonyclient/node/.config/
    echo "quil 节点已启动"
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "===================Quilibrium Network一键部署脚本==================="
        echo "请选择要执行的操作:"
        echo "1. 部署节点 install_node"
        echo "2. 备份节点 backup_key"
        echo "3. 查看状态 view_status"
        echo "4. 查看日志 view_logs"
        echo "5. 停止节点 stop_node"
        echo "6. 启动节点 start_node"
        echo "7. 查询余额 check_balance"
        echo "8. 升级程序 update_quil"
        echo "9. 限制CPU cpu_limited_rate"
        echo "10. 安装gRPC install_grpc"
        echo "0. 退出脚本 exit"
        read -p "请输入选项: " OPTION
    
        case $OPTION in
        1) install_node ;;
        2) backup_key ;;
        3) view_status ;;
        4) view_logs ;;
        5) stop_node ;;
        6) start_node ;;
        7) check_balance ;;
        8) update_quil ;;
        9) cpu_limited_rate ;;
        10) install_grpc ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新输入。"; sleep 3 ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

main_menu
