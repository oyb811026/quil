#!/usr/bin/env bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Quili.sh"

# 显示主菜单
function show_main_menu() {
    clear
    echo "=======================欢迎使用Quilibrium项目一键启动脚本======================="
    echo "1. 安装节点（支持断点续安装）"
    echo "2. 查看节点状态"
    echo "3. 启动"
    echo "4. 安装最新快照"
    echo "5. 备份配置文件"
    echo "6. 查看账户信息"
    echo "7. 解锁CPU性能限制"
    echo "8. 升级节点版本"
    echo "9. 升级脚本版本"
    echo "10. 安装gRPC"
    echo "11. 杀死screen会话"
    echo "12. 退出脚本"
    echo "======================================================================"
}

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="quili"
    local profile_file="$HOME/.profile"

    if ! grep -q "$alias_name" "$profile_file"; then
        echo "设置快捷键 '$alias_name' 到 $profile_file"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$profile_file"
        echo "快捷键 '$alias_name' 已设置。请运行 'source $profile_file' 来激活快捷键，或重新登录。"
    else
        echo "快捷键 '$alias_name' 已经设置在 $profile_file。"
    fi
}

# 杀死screen会话的函数
function kill_screen_session() {
    local session_name="Quili"
    if screen -list | grep -q "$session_name"; then
        echo "找到以下screen会话："
        screen -list | grep "$session_name"
        
        read -p "请输入要杀死的会话ID（例如11687）: " session_id
        if [[ -n "$session_id" ]]; then
            echo "正在杀死screen会话 '$session_id'..."
            screen -S "$session_id" -X quit || echo "杀死会话失败"
            echo "Screen会话 '$session_id' 已被杀死."
        else
            echo "无效的会话ID。"
        fi
    else
        echo "没有找到名为 '$session_name' 的screen会话."
    fi
}

# 节点安装功能
function install_node() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "此功能仅适用于 macOS。"
        return 1
    fi

    # 安装 Xcode 命令行工具
    if ! xcode-select -p &> /dev/null; then
        echo "正在安装 Xcode 命令行工具..."
        xcode-select --install
        while ! xcode-select -p &> /dev/null; do
            sleep 5
        done
    fi
    
    # 如果尚未安装,则安装 Homebrew
    if ! command -v brew &> /dev/null; then
        echo "正在安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # 更新 Homebrew 并安装必要的包
    echo "正在更新 Homebrew 并安装必要的包..."
    brew update
    brew install wget git screen bison gcc make

    # 删除旧的 gvm 安装
    if [ -d "$HOME/.gvm" ]; then
        echo "检测到旧的 gvm 安装，正在删除..."
        rm -rf "$HOME/.gvm"
    fi

    # 安装 gvm (Go 版本管理器)
    echo "正在安装 gvm..."
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source $HOME/.gvm/scripts/gvm

    # 获取系统架构
    ARCH=$(uname -m)

    # 安装并使用 Go 版本
    echo "正在安装 Go 版本..."
    gvm install go1.4 -B
    gvm use go1.4
    export GOROOT_BOOTSTRAP=$GOROOT

    if [ "$ARCH" = "x86_64" ]; then
        gvm install go1.17.13
        gvm use go1.17.13
        export GOROOT_BOOTSTRAP=$GOROOT

        gvm install go1.20.2
        gvm use go1.20.2
    elif [ "$ARCH" = "arm64" ]; then
        gvm install go1.17.13 -B
        gvm use go1.17.13
        export GOROOT_BOOTSTRAP=$GOROOT

        gvm install go1.20.2 -B
        gvm use go1.20.2
    else
        echo "不支持的架构: $ARCH"
        return 1
    fi

    echo "正在克隆 Quilibrium 仓库..."
    git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git || { echo "克隆失败"; exit 1; }

    # 进入 node 目录并切换到正确的分支
    cd ceremonyclient/node || exit
    git switch release-cdn

    # 设置执行权限
    chmod +x release_autorun.sh

    # 创建一个 screen 会话并运行命令
    echo "正在 screen 会话中启动节点..."
    screen -dmS Quili bash -c './release_autorun.sh'
    
    echo "======================================"
    echo "安装完成。要查看节点状态:"
    echo "1. 返回主菜单"
    echo "2. 运行 'screen -r Quili' 来连接到 screen 会话"
    echo "3. 使用 Ctrl-A + Ctrl-D 来从 screen 会话中分离"
    echo "======================================"

    # 用户交互以返回主菜单
    while true; do
        read -p "请选择操作 (1-3): " choice
        case $choice in
            1) 
                return ;;  # 返回主菜单
            2) screen -r Quili ;;  
            3) echo "已从 screen 会话分离。" ; break ;;  
            *) echo "无效的选项，请重新输入。" ;;
        esac
    done
}

# 查看常规版本节点日志
function check_service_status() {
    if screen -list | grep -q "Quili"; then
        screen -r Quili
    else
        echo "没有找到名为 'Quili' 的screen会话."
    fi
}

# 启动
function run_node() {
    echo "正在下载最新的 release_autorun.sh..."
    curl -o ~/ceremonyclient/node/release_autorun.sh https://raw.githubusercontent.com/a3165458/Quilibrium/main/release_autorun.sh

    # 确保新文件具有执行权限
    chmod +x ~/ceremonyclient/node/release_autorun.sh

    # 切换到 ceremonyclient/node 目录
    cd ~/ceremonyclient/node || { echo "无法进入目录 ~/ceremonyclient/node"; exit 1; }

    # 启动新的 screen 会话
    screen -dmS Quili bash -c './release_autorun.sh'
    echo "=======================已启动quilibrium 挖矿 请退出脚本使用screen 命令或者使用查看日志功能查询状态========================================="
}

# 安装最新快照
function add_snapshots() {
    brew install unzip
    rm -rf "$HOME/ceremonyclient/node/.config/store"
    wget -qO- https://snapshots.cherryservers.com/quilibrium/store.zip > /tmp/store.zip
    unzip -j -o /tmp/store.zip -d "$HOME/ceremonyclient/node/.config/store"
    rm /tmp/store.zip

    screen -dmS Quili bash -c "source \$HOME/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./release_autorun.sh"
}

# 备份配置文件
function backup_set() {
    mkdir -p ~/backup
    cp ~/ceremonyclient/node/.config/config.yml ~/backup/config.txt
    cp ~/ceremonyclient/node/.config/keys.yml ~/backup/keys.txt
    echo "=======================备份完成，请执行cd ~/backup 查看备份文件========================================="
}

# 查看账户信息
function check_balance() {
    cd ~/ceremonyclient/node || exit
    local version="1.4.21.1"
    local binary="node-$version"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64"* ]]; then
            binary="$binary-darwin-arm64"
        else
            binary="$binary-darwin-amd64"
        fi
    else
        echo "不支持的操作系统，请从源代码构建"
        exit 1
    fi
    ./"$binary" --node-info || echo "获取账户信息失败，请检查节点是否正在运行。"
}

# 解锁CPU性能限制
function unlock_performance() {
    cd ~/ceremonyclient/node || exit 
    echo "请选择要切换的版本："
    echo "1. 限制CPU50%性能版本"
    echo "2. CPU性能拉满版本"
    read -p "请输入选项(1或2): " version_choice

    if [ "$version_choice" -eq 1 ]; then
        git switch release-cdn
    elif [ "$version_choice" -eq 2 ]; then
        git switch release-non-datacenter
    else
        echo "无效的选项，退出脚本。"
        exit 1
    fi

    chmod +x release_autorun.sh
    screen -dmS Quili bash -c './release_autorun.sh'
    echo "=======================已解锁CPU性能限制并启动quilibrium 挖矿请退出脚本使用screen 命令或者使用查看日志功能查询状态========================================="
}

# 升级节点版本
function update_node() {
    cd ~/ceremonyclient/node || exit
    git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git
    git pull
    git switch release-cdn
    echo "节点已升级。请运行脚本独立启动挖矿功能启动节点。"
}

# 更新本脚本
function update_script() {
    local script_url="https://raw.githubusercontent.com/oyb811026/quil/main/Quili.sh"
    
    cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
    
    if curl -o "$SCRIPT_PATH" "$script_url"; then
        chmod +x "$SCRIPT_PATH"
        echo "脚本已更新。请退出脚本后，执行bash $SCRIPT_PATH 重新运行此脚本。"
    else
        echo "更新失败。正在恢复原始脚本。"
        mv "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"
    fi
}

# 安装gRPC
function setup_grpc() {
    echo "正在安装 gRPC..."
    curl -o qnode_gRPC_calls_setup.sh https://raw.githubusercontent.com/oyb811026/quil/main/qnode_gRPC_calls_setup.sh
    bash qnode_gRPC_calls_setup.sh
    echo "=======================gRPC安装完成========================================="
}

# 自动设置快捷键
check_and_set_alias

# 启动主菜单
while true; do
    show_main_menu
    read -p "请输入选项(1-12): " choice
    case $choice in
        1) install_node ;;
        2) check_service_status ;;
        3) run_node ;;
        4) add_snapshots ;;
        5) backup_set ;;
        6) check_balance ;;
        7) unlock_performance ;;
        8) update_node ;;
        9) update_script ;;
        10) setup_grpc ;;
        11) kill_screen_session ;;
        12) echo "感谢使用，退出脚本。" ; exit 0 ;;
        *) echo "无效的选项，请重新输入。" ;;
    esac
done
