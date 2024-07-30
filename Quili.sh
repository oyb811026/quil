#!/usr/bin/env bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" == "0" ]; then
    echo "此脚本不应以root用户权限运行。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Quili.sh"
release_os="darwin"
release_arch="arm64"

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="quili"
    local profile_file="$HOME/.profile"

    # 检查快捷键是否已经设置
    if ! grep -q "$alias_name" "$profile_file"; then
        echo "设置快捷键 '$alias_name' 到 $profile_file"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$profile_file"
        echo "快捷键 '$alias_name' 已设置。请运行 'source $profile_file' 来激活快捷键，或重新登录。"
    else
        echo "快捷键 '$alias_name' 已经设置在 $profile_file。"
        echo "如果快捷键不起作用，请尝试运行 'source $profile_file' 或重新登录。"
    fi
}

# 启动进程的函数
start_process() {
    local node_binary="./node-$version-$release_os-$release_arch"
    
    if [[ ! -f $node_binary ]]; then
        echo "Error: Node binary $node_binary does not exist."
        exit 1
    fi
    
    chmod +x "$node_binary"  # 赋予可执行权限
    echo "Starting process in screen session..."
    screen -dmS Quili bash -c "$node_binary"  # 在screen会话中启动进程
    main_process_id=$(pgrep -f "$node_binary")  # 获取进程ID
    echo "Process started with PID $main_process_id"
}

# 检查进程是否在运行的函数
is_process_running() {
    pgrep -P $main_process_id > /dev/null
    return $?  # 返回状态码
}

# 杀死进程的函数
kill_process() {
    if pgrep -f "node-.*-$release_os-$release_arch" > /dev/null; then
        echo "Killing processes matching node-.*-$release_os-$release_arch"
        pkill -f "node-.*-$release_os-$release_arch"
    else
        echo "No processes running"
    fi
}

# 杀死screen会话的函数
kill_screen_session() {
    local session_name="Quili"
    if screen -list | grep -q "$session_name"; then
        echo "找到以下screen会话："
        screen -list | grep "$session_name"  # 列出所有名为 Quili 的会话
        
        # 提示用户选择要杀死的会话
        read -p "请输入要杀死的会话ID（例如11687）: " session_id
        if [[ -n "$session_id" ]]; then
            echo "Killing screen session '$session_id'..."
            screen -S "$session_id" -X quit  # 杀死指定的screen会话
            echo "Screen session '$session_id' has been killed."
        else
            echo "无效的会话ID。"
        fi
    else
        echo "没有找到名为 '$session_name' 的screen会话."
    fi
}

# 下载新版本文件的函数
fetch() {
    files=$(curl -s https://releases.quilibrium.com/release | grep "$release_os-$release_arch")
    new_release=false

    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if [[ ! -f "./$file" ]]; then
            echo "Downloading $file..."
            if curl -O "https://releases.quilibrium.com/$file"; then
                new_release=true  # 标记为有新版本
            else
                echo "Failed to download $file"
            fi
        fi
    done
}

# 节点安装功能
function install_node() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "此功能仅适用于 macOS。请使用适合您操作系统的安装方法。"
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

    # 安装 Homebrew
    if ! command -v brew &> /dev/null; then
        echo "正在安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    echo "正在更新 Homebrew 并安装必要的包..."
    brew update
    brew install wget git screen bison gcc make

    echo "正在安装 gvm (Go 版本管理器)..."
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source "$HOME/.gvm/scripts/gvm"

    # 安装并使用 Go 版本
    echo "正在安装 Go 版本..."
    if gvm install go1.20.2; then
        gvm use go1.20.2
    else
        echo "安装 go1.20.2 失败，请检查 gvm 和网络配置。"
        exit 1
    fi

    echo "正在克隆 Quilibrium 仓库..."
    git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git

    cd ceremonyclient/node || exit
    git switch release-cdn

    chmod +x release_autorun.sh

    echo "正在 screen 会话中启动节点..."
    start_process  # 启动节点进程

    echo "======================================"
    echo "安装完成。要查看节点状态:"
    echo "1. 退出此脚本"
    echo "2. 运行 'screen -r Quili' 来连接到 screen 会话"
    echo "3. 使用 Ctrl-A + Ctrl-D 来从 screen 会话中分离"
    echo "======================================"
    
    # 用户交互
    while true; do
        read -p "请选择操作 (1-3): " choice
        case $choice in
            1) exit 0 ;;  # 退出脚本
            2) screen -r Quili ;;  # 连接到 screen 会话
            3) echo "已从 screen 会话分离。"; break ;;  # 从 screen 会话中分离
            *) echo "无效的选项，请重新输入。" ;;
        esac
    done
}

# 查看常规版本节点日志
function check_service_status() {
    screen -r Quili
}

# 独立启动
function run_node() {
    echo "正在独立启动节点..."
    fetch  # 检查并下载最新版本
    kill_process  # 杀死旧的进程
    start_process  # 启动新的节点进程

    if [[ $? -eq 0 ]]; then
        echo "节点已在screen会话中启动。您可以使用 'screen -r Quili' 查看状态。"
        echo "使用 Ctrl+A+D 可以从 screen 会话中分离。"
    else
        echo "启动节点失败，请检查错误信息。"
    fi
}

# 安装最新快照
function add_snapshots() {
    brew install unzip
    rm -r "$HOME/ceremonyclient/node/.config/store"
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
    local version="1.4.21"
    local binary="node-$version"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64"* ]]; then
            binary="$binary-darwin-arm64"
        else
            binary="$binary-darwin-amd64"
        fi
    else
        echo "unsupported OS for releases, please build from source"
        exit 1
    fi
    ./"$binary" --node-info
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

# 主循环
function main() {
    fetch  # 初始调用fetch函数以获取文件
    kill_process  # 杀死可能正在运行的进程
    start_process  # 启动进程

    while true; do
        if ! is_process_running; then  # 如果进程没有在运行
            echo "Process crashed or stopped. Restarting..."
            start_process  # 重新启动进程
        fi

        fetch  # 定期检查并下载新版本

        if [[ "$new_release" == true ]]; then  # 如果有新版本
            kill_process  # 杀死当前进程
            start_process  # 启动新版本
        fi

        sleep 300  # 每300秒循环一次
    done
}

# 自动设置快捷键
check_and_set_alias

echo "=======================欢迎使用Quilibrium项目一键启动脚本======================="
echo "1. 安装节点（支持断点续安装）"
echo "2. 查看节点状态"
echo "3. 独立启动挖矿"
echo "4. 安装最新快照"
echo "5. 备份配置文件"
echo "6. 查看账户信息"
echo "7. 解锁CPU性能限制"
echo "8. 升级节点版本"
echo "9. 升级脚本版本"
echo "10. 安装gRPC"
echo "11. 启动主循环"
echo "12. 杀死screen会话"  # 新增选项
echo "13. 退出脚本"
echo "======================================================================"

while true; do
    read -p "请输入选项(1-13): " choice
    case $choice in
        1) install_node ;;
        2) check_service_status ;;
        3) run_node ;;  # 确保独立启动的选项
        4) add_snapshots ;;
        5) backup_set ;;
        6) check_balance ;;
        7) unlock_performance ;;
        8) update_node ;;
        9) update_script ;;
        10) setup_grpc ;;  # 安装gRPC
        11) main ;;  # 启动主循环
        12) kill_screen_session ;;  # 杀死screen会话
        13) exit 0 ;;  # 正常退出脚本
        *) echo "无效的选项，请重新输入。" ;;
    esac
done
