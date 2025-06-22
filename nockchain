#!/bin/bash
set -e

# 颜色定义
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD_BLUE="\e[1;34m"
DIM="\e[2m"
RESET="\e[0m"

# 检查依赖
for dep in tmux screen; do
  if ! command -v "$dep" &>/dev/null; then
    echo -e "${RED}错误: 必需依赖 '$dep' 未安装。${RESET}"
    exit 1
  fi
done

# 检查是否在 tmux 中运行
if [[ -n "$TMUX" ]]; then
  echo -e "${RED}⚠️  请在运行此脚本前退出 tmux。${RESET}"
  exit 1
fi

# 启动矿工 tmux 会话函数
start_miner_tmux() {
  local session=$1
  local dir=$2
  local key=$3
  local use_state=$4
  local log_file="$dir/$session.log"

  # 如果矿工 tmux 会话已在运行，则跳过启动
  if tmux has-session -t "$session" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  跳过 $session: tmux 会话已存在。${RESET}"
    return
  fi

  local state_flag=""
  [[ "$use_state" =~ ^[Yy]$ ]] && state_flag="--state-jam ../state.jam"

  tmux new-session -d -s "$session" "cd $dir && \
RUST_LOG=info,nockchain=info,nockchain_libp2p_io=info,libp2p=info,libp2p_quic=info \
MINIMAL_LOG_FORMAT=true \
$HOME/nockchain/target/release/nockchain --mine \
--mining-pubkey $key $state_flag | tee $log_file"
}

# 获取矿工运行时间（格式化为时/分）
get_miner_uptime() {
  local session=$1
  if tmux has-session -t "$session" 2>/dev/null; then
    local start_ts=$(tmux display -p -t "$session" '#{start_time}' 2>/dev/null)
    local now_ts=$(date +%s)
    local diff=$((now_ts - start_ts))
    local hours=$((diff / 3600))
    local minutes=$(((diff % 3600) / 60))
    if (( hours > 0 )); then
      echo "${hours}h ${minutes}m"
    else
      echo "${minutes}m"
    fi
  else
    echo "未运行"
  fi
}

NCK_DIR="$HOME/nockchain"
NCK_BIN="$NCK_DIR/target/release/nockchain"

SCRIPT_PATH="$(realpath "$0")"
LAUNCHER_VERSION_FILE="$(dirname "$SCRIPT_PATH")/NOCKCHAIN_LAUNCHER_VERSION"
if [[ -f "$LAUNCHER_VERSION_FILE" ]]; then
  LAUNCHER_VERSION=$(cat "$LAUNCHER_VERSION_FILE" | tr -d '[:space:]')
else
  LAUNCHER_VERSION="(未知)"
fi
# 直接获取远程版本，不覆盖本地版本文件（除非在更新期间）
REMOTE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/jobless0x/nockchain-launcher/main/NOCKCHAIN_LAUNCHER_VERSION | tr -d '[:space:]')

# 主启动器循环
while true; do
clear

echo -e "${RED}"
cat <<'EOF'
                  _        _           _       
 _ __   ___   ___| | _____| |__   __ _(_)_ __  
| '_ \ / _ \ / __| |/ / __| '_ \ / _` | | '_ \ 
| | | | (_) | (__|   < (__| | | | (_| | | | | |
|_| |_|\___/ \___|_|\_\___|_| |_|\__,_|_|_| |_|
EOF

echo -e "${YELLOW}:: 由 Jobless 提供支持 ::${RESET}"

# 显示欢迎信息
echo -e "${DIM}欢迎使用 Nockchain 节点管理器。${RESET}"

# 从所有矿工日志中提取网络高度（用于仪表盘）
NETWORK_HEIGHT="--"
all_blocks=()
for miner_dir in "$HOME/nockchain"/miner*; do
  [[ -d "$miner_dir" ]] || continue
  log_file="$miner_dir/$(basename "$miner_dir").log"
  if [[ -f "$log_file" ]]; then
    height=$(grep -a 'heard block' "$log_file" | tail -n 5 | grep -oP 'height\s+\K[0-9]+\.[0-9]+' | sort -V | tail -n 1)
    [[ -n "$height" ]] && all_blocks+=("$height")
  fi
done
if [[ ${#all_blocks[@]} -gt 0 ]]; then
  NETWORK_HEIGHT=$(printf "%s\n" "${all_blocks[@]}" | sort -V | tail -n 1)
fi

echo -e "${DIM}轻松安装、配置和监控多个 Nockchain 矿工。${RESET}"
echo ""

RUNNING_MINERS=$(tmux ls 2>/dev/null | grep -c '^miner' || true)
RUNNING_MINERS=${RUNNING_MINERS:-0}
MINER_FOLDERS=$(find "$HOME/nockchain" -maxdepth 1 -type d -name "miner*" 2>/dev/null | wc -l)
if (( RUNNING_MINERS > 0 )); then
  echo -e "${GREEN}🟢 $RUNNING_MINERS 个活跃矿工${RESET} ${DIM}($MINER_FOLDERS 个矿工总数)${RESET}"
else
  echo -e "${RED}🔴 没有运行中的矿工${RESET} ${DIM}($MINER_FOLDERS 个矿工总数)${RESET}"
fi

 # 显示节点和启动器版本状态
echo ""
VERSION="(未安装)"
NODE_STATUS="${YELLOW}未安装${RESET}"

if [[ -d "$HOME/nockchain" && -d "$HOME/nockchain/.git" ]]; then
  cd "$HOME/nockchain"
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    LOCAL_HASH=$(git rev-parse "$BRANCH")
    REMOTE_HASH=$(git ls-remote origin "refs/heads/$BRANCH" | awk '{print $1}')
    VERSION=$(git describe --tags --always 2>/dev/null)
    NODE_STATUS="${GREEN}✅ 最新${RESET}"
    [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]] && NODE_STATUS="${RED}🔴 有可用更新${RESET}"
  else
    NODE_STATUS="${YELLOW}(git 信息不可用)${RESET}"
  fi
fi

if [[ -z "$REMOTE_VERSION" ]]; then
  LAUNCHER_STATUS="${YELLOW}⚠️  无法检查更新 (离线)${RESET}"
elif [[ "$LAUNCHER_VERSION" == "$REMOTE_VERSION" ]]; then
  LAUNCHER_STATUS="${GREEN}✅ 最新${RESET}"
else
  LAUNCHER_STATUS="${RED}🔴 有可用更新${RESET}"
fi

 # 显示版本块（对齐优化）
printf "  ${CYAN}%-12s${RESET}%-18s %b\n" "节点:" "$VERSION" "$NODE_STATUS"
printf "  ${CYAN}%-12s${RESET}%-18s %b\n" "启动器:" "$LAUNCHER_VERSION" "$LAUNCHER_STATUS"

if [[ -d "$HOME/nockchain" ]]; then
  if [[ -f "$HOME/nockchain/.env" ]]; then
    if grep -q "^MINING_PUBKEY=" "$HOME/nockchain/.env"; then
      MINING_KEY_DISPLAY=$(grep "^MINING_PUBKEY=" "$HOME/nockchain/.env" 2>/dev/null | cut -d= -f2)
      printf "  ${CYAN}%-12s${RESET}%-18s %b\n" "公钥:" "$MINING_KEY_DISPLAY" ""
    else
      printf "  ${CYAN}%-12s${RESET}%-18s %b\n" "公钥:" "${YELLOW}(未在 .env 中定义)${RESET}" ""
    fi
  else
    printf "  ${CYAN}%-12s${RESET}%-18s %b\n" "公钥:" "${YELLOW}(无 .env 文件)${RESET}" ""
  fi
else
  printf "  ${CYAN}%-12s${RESET}%b\n" "公钥:" "${YELLOW}(不可用)${RESET}"
fi
printf "  ${CYAN}%-12s${RESET}%-20s\n" "高度:" "$NETWORK_HEIGHT"
echo ""

# 显示实时系统指标：CPU负载、内存使用、运行时间
CPU_LOAD=$(awk '{print $1}' /proc/loadavg)
RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
printf "  ${CYAN}%-12s${RESET}%-20s\n" "CPU负载:" "$CPU_LOAD / $(nproc)"
printf "  ${CYAN}%-12s${RESET}%-20s\n" "内存使用:" "$RAM_USED / $RAM_TOTAL"
printf "  ${CYAN}%-12s${RESET}%-20s\n" "运行时间:" "$(uptime -p)"

echo -e "${RED}
NOCKCHAIN 节点管理器
---------------------------------------${RESET}"

echo -e "${CYAN}设置:${RESET}"
echo -e "${BOLD_BLUE}1) 全新安装 Nockchain${RESET}"
echo -e "${BOLD_BLUE}2) 更新 nockchain 到最新版本${RESET}"
echo -e "${BOLD_BLUE}3) 仅更新 nockchain-wallet${RESET}"
echo -e "${BOLD_BLUE}4) 更新启动器脚本${RESET}"

echo -e ""
echo -e "${CYAN}矿工操作:${RESET}"
echo -e "${BOLD_BLUE}5) 启动矿工${RESET}"
echo -e "${BOLD_BLUE}6) 重启矿工${RESET}"
echo -e "${BOLD_BLUE}7) 停止矿工${RESET}"

echo -e ""
echo -e "${CYAN}系统工具:${RESET}"
echo -e "${BOLD_BLUE}0) 运行系统诊断${RESET}"
echo -e "${BOLD_BLUE}8) 显示运行中的矿工${RESET}"
echo -e "${BOLD_BLUE}9) 监控资源使用 (htop)${RESET}"

echo -e ""
echo -ne "${BOLD_BLUE}从上方菜单中选择一个选项（或按 Enter 退出）: ${RESET}"
 # 显示 tmux 和 screen 会话控制提示
echo -e ""
echo -e "${DIM}提示: 使用 ${BOLD_BLUE}tmux ls${DIM} 查看运行中的矿工，${BOLD_BLUE}tmux attach -t miner1${DIM} 进入会话，${BOLD_BLUE}Ctrl+b 然后 d${DIM} 分离 tmux，${BOLD_BLUE}screen -r nockbuild${DIM} 监控构建会话，${BOLD_BLUE}Ctrl+a 然后 d${DIM} 分离 screen。${RESET}"
read USER_CHOICE

# 定义二进制文件和日志的重要路径
BINARY_PATH="$HOME/nockchain/target/release/nockchain"
LOG_PATH="$HOME/nockchain/build.log"

if [[ -z "$USER_CHOICE" ]]; then
  echo -e "${CYAN}退出启动器。再见！${RESET}"
  exit 0
fi

case "$USER_CHOICE" in
  0)
    clear
    echo -e "${CYAN}系统诊断${RESET}"
    echo ""

    # 诊断：验证必需工具是否安装
    echo -e "${CYAN}▶ 必需命令${RESET}"
    echo -e "${DIM}-------------------${RESET}"
    for cmd in tmux screen cargo git curl make; do
      if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✔ $cmd 已安装${RESET}"
      else
        echo -e "${RED}❌ $cmd 缺失${RESET}"
      fi
    done
    echo ""

    # 诊断：检查 Nockchain 和钱包二进制文件是否存在
    echo -e "${CYAN}▶ 关键路径和二进制文件${RESET}"
    echo -e "${DIM}----------------------${RESET}"
    [[ -x "$HOME/nockchain/target/release/nockchain" ]] && echo -e "${GREEN}✔ nockchain 二进制文件存在${RESET}" || echo -e "${RED}❌ nockchain 二进制文件缺失${RESET}"
    [[ -x "$HOME/.cargo/bin/nockchain-wallet" ]] && echo -e "${GREEN}✔ nockchain-wallet 存在${RESET}" || echo -e "${RED}❌ nockchain-wallet 缺失${RESET}"
    echo ""

    # 诊断：验证 .env 存在和挖矿密钥定义
    echo -e "${CYAN}▶ .env 和 MINING_PUBKEY${RESET}"
    echo -e "${DIM}-----------------------${RESET}"
    if [[ -f "$HOME/nockchain/.env" ]]; then
      echo -e "${GREEN}✔ .env 文件存在${RESET}"
      if grep -q "^MINING_PUBKEY=" "$HOME/nockchain/.env"; then
        echo -e "${GREEN}✔ MINING_PUBKEY 已定义${RESET}"
      else
        echo -e "${RED}❌ .env 中未找到 MINING_PUBKEY${RESET}"
      fi
    else
      echo -e "${RED}❌ .env 文件缺失${RESET}"
    fi
    echo ""

    # 诊断：统计本地 nockchain 路径中的矿工目录数量
    echo -e "${CYAN}▶ 矿工文件夹${RESET}"
    echo -e "${DIM}--------------${RESET}"
    miner_count=$(find "$HOME/nockchain" -maxdepth 1 -type d -name "miner*" 2>/dev/null | wc -l)
    if (( miner_count > 0 )); then
      echo -e "${GREEN}✔ 找到 $miner_count 个矿工文件夹${RESET}"
    else
      echo -e "${RED}❌ 未找到矿工文件夹${RESET}"
    fi
    echo ""

    # 诊断：比较本地与远程 git 提交哈希
    echo -e "${CYAN}▶ Nockchain 仓库${RESET}"
    echo -e "${DIM}----------------------${RESET}"
    if [[ ! -d "$HOME/nockchain" ]]; then
      echo -e "${YELLOW}Nockchain 尚未安装。${RESET}"
    elif [[ ! -d "$HOME/nockchain/.git" ]]; then
      echo -e "${YELLOW}Nockchain 存在但不是 Git 仓库。${RESET}"
    elif git -C "$HOME/nockchain" rev-parse &>/dev/null; then
      BRANCH=$(git -C "$HOME/nockchain" rev-parse --abbrev-ref HEAD)
      REMOTE_URL=$(git -C "$HOME/nockchain" config --get remote.origin.url)
      LOCAL_HASH=$(git -C "$HOME/nockchain" rev-parse "$BRANCH")
      REMOTE_HASH=$(git -C "$HOME/nockchain" ls-remote origin "refs/heads/$BRANCH" | awk '{print $1}')

      printf "${GREEN}✔ %-15s${CYAN}%s${RESET}\n" "远程 URL:" "$REMOTE_URL"
      printf "${GREEN}✔ %-15s${BOLD_BLUE}%s${RESET}\n" "分支:" "$BRANCH"

      if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
        printf "${RED}❌ %-15s%s${RESET}\n" "状态:" "有可用更新"
      else
        printf "${GREEN}✔ %-15s%s\n" "状态:" "仓库与远程同步。"
      fi
    else
      echo -e "${RED}❌ Git 仓库似乎损坏${RESET}"
    fi
    echo ""

    # 诊断：验证到 GitHub 的互联网访问
    echo -e "${CYAN}▶ 互联网检查${RESET}"
    echo -e "${DIM}-----------------${RESET}"
    if curl -fsSL https://github.com >/dev/null 2>&1; then
      echo -e "${GREEN}✔ GitHub 可访问${RESET}"
    else
      echo -e "${RED}❌ 无法访问 GitHub${RESET}"
    fi

    echo ""
    # 诊断：检查启动器版本与 GitHub 同步
    echo -e "${CYAN}▶ 启动器更新检查${RESET}"
    echo -e "${DIM}-----------------------${RESET}"
    printf "${GREEN}✔ %-15s${BOLD_BLUE}%s${RESET}\n" "本地版本:" "$LAUNCHER_VERSION"
    if [[ -z "$REMOTE_VERSION" ]]; then
      printf "${YELLOW}⚠ %-15s%s${RESET}\n" "远程版本:" "不可用 (离线或获取错误)"
    else
      printf "${GREEN}✔ %-15s${CYAN}%s${RESET}\n" "远程版本:" "$REMOTE_VERSION"
      if [[ "$LAUNCHER_VERSION" == "$REMOTE_VERSION" ]]; then
        printf "${GREEN}✔ %-15s%s\n" "状态:" "最新"
      else
        printf "${RED}❌ %-15s%s${RESET}\n" "状态:" "有可用更新"
      fi
    fi
    echo ""

    echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
    read -n 1 -s
    continue
    ;;
  1)
    clear

    echo -e "${YELLOW}⚠️  这将全新安装 Nockchain。这可能会覆盖现有文件。${RESET}"
    echo -e "${YELLOW}确定要继续吗？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_INSTALL
    if [[ ! "$CONFIRM_INSTALL" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}返回菜单...${RESET}"
      continue
    fi

    # 处理 sudo 和 root 系统准备
    if [ "$(id -u)" -eq 0 ]; then
      echo -e "${YELLOW}>> 以 root 身份运行。更新系统并安装 sudo...${RESET}"
      apt-get update && apt-get upgrade -y

      if ! command -v sudo &> /dev/null; then
        apt-get install sudo -y
      fi
    fi

    if [ ! -f "$BINARY_PATH" ]; then
        echo -e "${YELLOW}>> Nockchain 尚未构建。开始阶段1 (构建)...${RESET}"

        echo -e "${CYAN}>> 安装系统依赖...${RESET}"
        sudo apt-get update && sudo apt-get upgrade -y
        sudo apt install -y curl iptables build-essential ufw screen git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libclang-dev llvm-dev

        if ! command -v cargo &> /dev/null; then
            echo -e "${CYAN}>> 安装 Rust...${RESET}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi

        echo -e "${CYAN}>> 克隆 Nockchain 仓库并开始构建...${RESET}"
        rm -rf nockchain .nockapp
        git clone https://github.com/zorp-corp/nockchain
        cd nockchain
        cp .env_example .env

        if screen -ls | grep -q "nockbuild"; then
          echo -e "${YELLOW}名为 'nockbuild' 的 screen 会话已存在。终止中...${RESET}"
          screen -S nockbuild -X quit
        fi

        echo -e "${CYAN}>> 在 screen 会话 'nockbuild' 中启动构建并记录到 build.log...${RESET}"
        screen -dmS nockbuild bash -c "cd \$HOME/nockchain && make install-hoonc && make build && make install-nockchain-wallet && make install-nockchain | tee build.log"

        echo -e "${GREEN}>> 构建已在 screen 会话 'nockbuild' 中启动。${RESET}"
        echo -e "${YELLOW}>> 监控构建: ${DIM}screen -r nockbuild${RESET}"
        echo -e "${DIM}提示: 按 ${CYAN}Ctrl+A${DIM}，然后 ${CYAN}D${DIM} 在不停止构建的情况下分离 screen。${RESET}"
        echo -e "${YELLOW}是否现在附加到构建 screen 会话？ (y/n)${RESET}"
        read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" ATTACH_BUILD
        if [[ "$ATTACH_BUILD" =~ ^[Yy]$ ]]; then
          screen -r nockbuild
        else
          echo -e "${CYAN}返回主菜单...${RESET}"
          read -n 1 -s -r -p $'\n按任意键继续...'
        fi
        continue
    fi

    echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
    read -n 1 -s
    continue
    ;;
  2)
    clear
    echo -e "${YELLOW}您即将从 GitHub 更新 Nockchain 到最新版本。${RESET}"
    echo -e "${YELLOW}继续？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_UPDATE
    if [[ ! "$CONFIRM_UPDATE" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}返回菜单...${RESET}"
      continue
    fi

    if screen -ls | grep -q "nockupdate"; then
      echo -e "${YELLOW}名为 'nockupdate' 的 screen 会话已存在。终止中...${RESET}"
      screen -S nockupdate -X quit
    fi

    echo -e "${YELLOW}在 .env 中检测到以下公钥，将在更新后用于重启矿工:${RESET}"
    MINING_KEY_DISPLAY=$(grep "^MINING_PUBKEY=" "$HOME/nockchain/.env" | cut -d= -f2)
    echo -e "${CYAN}公钥:${RESET} $MINING_KEY_DISPLAY"
    echo -e "${YELLOW}是否要在更新后使用此密钥自动重启所有矿工？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_RESTART_AFTER_UPDATE

    if [[ "$CONFIRM_RESTART_AFTER_UPDATE" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}>> 在 screen 会话 'nockupdate' 中启动更新和矿工重启...${RESET}"
      screen -dmS nockupdate bash -c "
        cd \$HOME/nockchain && \
        git pull && \
        make install-nockchain && \
        export PATH=\"\$HOME/.cargo/bin:\$PATH\" && \
        echo '>> 终止现有矿工...' && \
        tmux ls 2>/dev/null | grep '^miner' | cut -d: -f1 | xargs -r -n1 tmux kill-session -t && \
        for d in \$HOME/nockchain/miner*; do
          session=\$(basename \"\$d\")
          \"$HOME/nockchain/node_launcher.sh\" internal_start_miner_tmux \"\$session\" \"\$d\" \"$MINING_KEY_DISPLAY\" \"n\"
          echo \"✅ 已重启 \$session\"
        done
        echo '更新和重启完成。'
        exec bash
      "
      echo -e "${GREEN}>> 更新和矿工重启进程已在 screen 会话 'nockupdate' 中启动。${RESET}"
    else
      echo -e "${CYAN}>> 在 screen 会话 'nockupdate' 中启动更新（矿工不会重启）...${RESET}"
      screen -dmS nockupdate bash -c "
        cd \$HOME/nockchain && \
        git pull && \
        make install-nockchain && \
        export PATH=\"\$HOME/.cargo/bin:\$PATH\" && \
        echo '更新完成。矿工未重启。' && \
        exec bash
      "
      echo -e "${GREEN}>> 更新进程已在 screen 会话 'nockupdate' 中启动。矿工不会重启。${RESET}"
    fi
    echo -e "${YELLOW}>> 监控: ${DIM}screen -r nockupdate${RESET}"
    echo -e "${CYAN}要在不停止更新的情况下退出 screen 会话:${RESET}"
    echo -e "${DIM}按 Ctrl+A 然后 D${RESET}"

    echo -e "${YELLOW}是否现在附加到 'nockupdate' screen 会话？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" ATTACH_CHOICE
    if [[ "$ATTACH_CHOICE" =~ ^[Yy]$ ]]; then
      screen -r nockupdate
    fi

    echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
    read -n 1 -s
    continue
    ;;
  3)
    clear
    echo -e "${YELLOW}您即将仅更新 Nockchain 钱包 (nockchain-wallet)。${RESET}"
    echo -e "${YELLOW}继续？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_UPDATE_WALLET
    if [[ ! "$CONFIRM_UPDATE_WALLET" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}返回菜单...${RESET}"
      continue
    fi

    if screen -ls | grep -q "walletupdate"; then
      echo -e "${YELLOW}名为 'walletupdate' 的 screen 会话已存在。终止中...${RESET}"
      screen -S walletupdate -X quit
    fi

    echo -e "${CYAN}>> 在 screen 会话 'walletupdate' 中启动钱包更新...${RESET}"
    screen -dmS walletupdate bash -c "
      cd \$HOME/nockchain && \
      git pull && \
      make install-nockchain-wallet && \
      export PATH=\"\$HOME/.cargo/bin:\$PATH\" && \
      echo '钱包更新完成。' && \
      exec bash
    "
    echo -e "${GREEN}✅ 钱包更新已在 screen 会话 'walletupdate' 中启动。${RESET}"
    echo -e "${YELLOW}监控: ${DIM}screen -r walletupdate${RESET}"
    echo -e "${CYAN}退出 screen: ${DIM}Ctrl+A 然后 D${RESET}"

    echo -e "${YELLOW}是否现在附加到 'walletupdate' screen 会话？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" ATTACH_WALLET
    if [[ "$ATTACH_WALLET" =~ ^[Yy]$ ]]; then
      screen -r walletupdate
    fi

    echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
    read -n 1 -s
    continue
    ;;
  4)
    clear
    echo -e "${YELLOW}您即将从 GitHub 更新启动器脚本到最新版本。${RESET}"
    echo -e "${YELLOW}继续？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_LAUNCHER_UPDATE
    if [[ ! "$CONFIRM_LAUNCHER_UPDATE" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}返回菜单...${RESET}"
      continue
    fi

    SCRIPT_PATH="$(realpath "$0")"
    TEMP_PATH="/tmp/nockchain_launcher.sh"
    TEMP_VERSION="/tmp/NOCKCHAIN_LAUNCHER_VERSION"

    echo -e "${CYAN}>> 下载最新启动器脚本...${RESET}"
    if ! curl -fsSL https://raw.githubusercontent.com/jobless0x/nockchain-launcher/main/nockchain_launcher.sh -o "$TEMP_PATH"; then
      echo -e "${RED}❌ 下载启动器脚本失败。${RESET}"
      continue
    fi

    echo -e "${CYAN}>> 下载版本文件...${RESET}"
    if ! curl -fsSL https://raw.githubusercontent.com/jobless0x/nockchain-launcher/main/NOCKCHAIN_LAUNCHER_VERSION -o "$TEMP_VERSION"; then
      echo -e "${RED}❌ 下载版本文件失败。${RESET}"
      continue
    fi

    echo -e "${CYAN}>> 替换启动器和版本文件...${RESET}"
    cp "$TEMP_PATH" "$SCRIPT_PATH"
    cp "$TEMP_VERSION" "$LAUNCHER_VERSION_FILE"
    chmod +x "$SCRIPT_PATH"

    echo -e "${GREEN}✅ 启动器更新成功。${RESET}"
    echo -e "${YELLOW}按任意键使用更新后的版本重新启动启动器...${RESET}"
    read -n 1 -s
    exec "$SCRIPT_PATH"
    ;;
  5)
    clear
    echo -e "${YELLOW}您即将启动一个或多个矿工。${RESET}"
    echo -e "${YELLOW}确定要继续吗？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_LAUNCH
    if [[ ! "$CONFIRM_LAUNCH" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}返回菜单...${RESET}"
      continue
    fi
    # 阶段2：在矿工设置前确保 Nockchain 构建存在
    if [ -f "$BINARY_PATH" ]; then
        echo -e "${GREEN}>> 检测到构建。继续阶段2 (钱包 + 矿工设置)...${RESET}"
    else
        echo -e "${RED}!! 错误: 构建未完成或失败。${RESET}"
        echo -e "${YELLOW}>> 检查构建日志: $LOG_PATH${RESET}"
        echo -e "${YELLOW}>> 恢复 screen: ${DIM}screen -r nockbuild${RESET}"
        continue
    fi
    cd "$HOME/nockchain"
    export PATH="$PATH:$(pwd)/target/release"
    export PATH="$HOME/.cargo/bin:$PATH"
    echo "export PATH=\"\$PATH:$(pwd)/target/release\"" >> ~/.bashrc
    # 如果找不到 keys.export，则处理钱包导入或生成
    if [[ -f "keys.export" ]]; then
      echo -e "${CYAN}>> 从 keys.export 导入钱包...${RESET}"
      nockchain-wallet import-keys --input keys.export
    else
      echo -e "${YELLOW}未找到钱包 (keys.export)。${RESET}"
      echo -e "${YELLOW}是否现在生成新钱包？ (y/n)${RESET}"
      read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CREATE_WALLET
      if [[ ! "$CREATE_WALLET" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}返回菜单...${RESET}"
        continue
      fi
      echo -e "${CYAN}>> 生成新钱包...${RESET}"
      nockchain-wallet keygen
      echo -e "${CYAN}>> 备份密钥到 'keys.export'...${RESET}"
      echo ""
      nockchain-wallet export-keys
    fi
    # 验证或请求用户的挖矿公钥
    if grep -q "^MINING_PUBKEY=" .env; then
      MINING_KEY=$(grep "^MINING_PUBKEY=" .env | cut -d= -f2)
    else
      echo -e "${YELLOW}输入用于挖矿的公钥:${RESET}"
      read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" MINING_KEY
      if [[ -z "$MINING_KEY" ]]; then
        echo -e "${RED}!! 错误: 公钥不能为空。${RESET}"
        continue
      fi
      sed -i "s/^MINING_PUBKEY=.*/MINING_PUBKEY=$MINING_KEY/" .env
    fi
    # 在启动前要求用户确认或更正公钥
    while true; do
      echo -e "${YELLOW}将使用以下挖矿公钥:${RESET}"
      echo -e "${CYAN}$MINING_KEY${RESET}"
      echo -e "${YELLOW}是否正确？ (y/n)${RESET}"
      read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_KEY
      if [[ "$CONFIRM_KEY" =~ ^[Yy]$ ]]; then
        break
      fi
      echo -e "${YELLOW}请输入正确的挖矿公钥:${RESET}"
      read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" MINING_KEY
      sed -i "s/^MINING_PUBKEY=.*/MINING_PUBKEY=$MINING_KEY/" .env
    done
    # 为 Nockchain 配置并启用必需的 UFW 防火墙规则
    echo -e "${CYAN}>> 配置防火墙...${RESET}"
    sudo ufw allow ssh >/dev/null 2>&1 || true
    sudo ufw allow 22 >/dev/null 2>&1 || true
    sudo ufw allow 3005/tcp >/dev/null 2>&1 || true
    sudo ufw allow 3006/tcp >/dev/null 2>&1 || true
    sudo ufw allow 3005/udp >/dev/null 2>&1 || true
    sudo ufw allow 3006/udp >/dev/null 2>&1 || true
    sudo ufw --force enable >/dev/null 2>&1 || echo -e "${YELLOW}警告: 启用 UFW 失败。继续脚本执行。${RESET}"
    echo -e "${GREEN}✅ 防火墙配置完成。${RESET}"
    # 收集系统规格并计算最佳矿工数量
    CPU_CORES=$(nproc)
    TOTAL_MEM=$(free -g | awk '/^Mem:/ {print $2}')
    echo ""
    echo -e "${CYAN}📈 矿工推荐:${RESET}"
    echo -e "${CYAN}推荐: 每 2 个 vCPU 和 8GB RAM 运行 1 个矿工${RESET}"
    RECOMMENDED_MINERS=$(( CPU_CORES / 2 < TOTAL_MEM / 8 ? CPU_CORES / 2 : TOTAL_MEM / 8 ))
    echo -e "${YELLOW}此系统最大推荐矿工数: ${RESET}${CYAN}$RECOMMENDED_MINERS${RESET}"
    echo ""
    while true; do
      echo -e "${YELLOW}要运行多少个矿工？ (输入数字如 1, 3, 10...) 或 'n' 取消:${RESET}"
      read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" NUM_MINERS
      NUM_MINERS=$(echo "$NUM_MINERS" | tr -d '[:space:]')
      if [[ "$NUM_MINERS" =~ ^[Nn]$ ]]; then
        echo -e "${CYAN}返回菜单...${RESET}"
        break
      elif [[ "$NUM_MINERS" =~ ^[0-9]+$ && "$NUM_MINERS" -ge 1 ]]; then
        echo ""
        echo -e "${CYAN}您即将启动以下矿工:${RESET}"
        miner_list=$(seq 1 "$NUM_MINERS" | sed 's/^/miner/')
        echo -e "${GREEN}$miner_list${RESET}"
        echo -e "${YELLOW}继续？ (y/n)${RESET}"
        read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_LAUNCH
        if [[ ! "$CONFIRM_LAUNCH" =~ ^[Yy]$ ]]; then
          echo -e "${CYAN}返回矿工数量选择...${RESET}"
          continue
        fi
        for i in $(seq 1 "$NUM_MINERS"); do
          (
            MINER_DIR="$NCK_DIR/miner$i"
            mkdir -p "$MINER_DIR"
            if tmux has-session -t miner$i 2>/dev/null; then
              echo -e "${YELLOW}⚠️  跳过 miner$i: tmux 会话已存在。${RESET}"
              exit
            fi
            if [ -f "$NCK_DIR/state.jam" ]; then
              USE_STATE_JAM="y"
            else
              USE_STATE_JAM="n"
            fi
            echo -e "${CYAN}>> 在 tmux 中启动 miner$i...${RESET}"
            start_miner_tmux "miner$i" "$MINER_DIR" "$MINING_KEY" "$USE_STATE_JAM"
            echo -e "${GREEN}✅ Miner$i 正在 tmux 会话 'miner$i' 中运行。${RESET}"
          ) &
        done
        wait
        echo ""
        echo -e "${GREEN}🎉 Nockchain 矿工启动成功！${RESET}"
        # 显示启动后说明和 tmux 管理提示
        echo ""
        echo -e "${CYAN}使用以下命令管理您的矿工:${RESET}"
        echo -e "${CYAN}- 列出会话:    ${DIM}tmux ls${RESET}"
        echo -e "${CYAN}- 附加会话:    ${DIM}tmux attach -t minerX${RESET}"
        echo -e "${CYAN}- 分离:         ${DIM}Ctrl + b 然后 d${RESET}"
        echo ""
        echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
        read -n 1 -s
        break
      else
        echo -e "${RED}❌ 无效输入。请输入正整数 (如 1, 3) 或 'n' 取消。${RESET}"
      fi
    done
    continue
    ;;
  6)
    clear
    all_miners=()
    for d in "$HOME/nockchain"/miner*; do
      [ -d "$d" ] || continue
      session=$(basename "$d")
      if tmux has-session -t "$session" 2>/dev/null; then
        all_miners+=("🟢 $session")
      else
        all_miners+=("❌ $session")
      fi
    done
    # 按矿工编号排序，保留图标
    IFS=$'\n' sorted_miners=($(printf "%s\n" "${all_miners[@]}" | sort -k2 -V))
    unset IFS
    if ! command -v fzf &> /dev/null; then
      echo -e "${YELLOW}未找到 fzf。安装 fzf...${RESET}"
      sudo apt-get update && sudo apt-get install -y fzf
      echo -e "${GREEN}fzf 安装成功。${RESET}"
    fi
    menu=$(printf "%s\n" "↩️  取消并返回菜单" "🔁 重启所有矿工" "${sorted_miners[@]}")
    selected=$(echo "$menu" | fzf --multi --bind "space:toggle" --prompt="选择要重启的矿工: " --header=$'\n\n使用 SPACE 选择矿工。\n按 ENTER 将重启（或启动）选中的矿工。\n\n')
    if [[ -z "$selected" || "$selected" == *"Cancel and return to menu"* ]]; then
      echo -e "${YELLOW}未选择。返回菜单...${RESET}"
      continue
    fi
    if echo "$selected" | grep -q "Restart all miners"; then
      TARGET_SESSIONS=$(printf "%s\n" "${sorted_miners[@]}" | sed 's/^[^ ]* //')
    else
      TARGET_SESSIONS=$(echo "$selected" | grep -v "Restart all miners" | grep -v "Cancel and return to menu" | sed 's/^[^ ]* //')
    fi
    echo -e "${YELLOW}您选择了:${RESET}"
    for session in $TARGET_SESSIONS; do
      echo -e "${CYAN}- $session${RESET}"
    done
    echo -e "${YELLOW}确定要重启这些吗？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_RESTART
    [[ ! "$CONFIRM_RESTART" =~ ^[Yy]$ ]] && echo -e "${CYAN}返回菜单...${RESET}" && continue
    for session in $TARGET_SESSIONS; do
      echo -e "${CYAN}重启 $session...${RESET}"
      tmux kill-session -t "$session" 2>/dev/null || true
      miner_num=$(echo "$session" | grep -o '[0-9]\+')
      miner_dir="$HOME/nockchain/miner$miner_num"
      mkdir -p "$miner_dir"
      start_miner_tmux "$session" "$miner_dir" "$MINING_KEY" "n"
    done
    echo -e "${GREEN}✅ 选中的矿工已重启。${RESET}"
    echo -e "${CYAN}附加到 tmux 会话: ${DIM}tmux attach -t minerX${RESET}"
    echo -e "${CYAN}从 tmux 分离: ${DIM}Ctrl + b 然后 d${RESET}"
    echo -e "${CYAN}列出 tmux 会话: ${DIM}tmux ls${RESET}"
    echo -e "${GREEN}✅ 当前运行中的矿工:${RESET}"
    tmux ls | grep '^miner' | cut -d: -f1 | sort -V
    echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
    read -n 1 -s
    continue
    ;;
  7)
    clear
    all_miners=()
    for d in "$HOME/nockchain"/miner*; do
      [ -d "$d" ] || continue
      session=$(basename "$d")
      if tmux has-session -t "$session" 2>/dev/null; then
        all_miners+=("🟢 $session")
      else
        all_miners+=("❌ $session")
      fi
    done
    IFS=$'\n' sorted_miners=($(printf "%s\n" "${all_miners[@]}" | sort -k2 -V))
    unset IFS
    if ! command -v fzf &> /dev/null; then
      echo -e "${YELLOW}未找到 fzf。安装 fzf...${RESET}"
      sudo apt-get update && sudo apt-get install -y fzf
      echo -e "${GREEN}fzf 安装成功。${RESET}"
    fi
    running_miners=()
    for entry in "${sorted_miners[@]}"; do
      [[ "$entry" =~ ^🟢 ]] && running_miners+=("$entry")
    done
    menu=$(printf "%s\n" "↩️  取消并返回菜单" "🛑 停止所有运行中的矿工" "${running_miners[@]}")
    selected=$(echo "$menu" | fzf --multi --bind "space:toggle" --prompt="选择要停止的矿工: " --header=$'\n\n使用 SPACE 选择矿工。\n按 ENTER 将停止选中的矿工。\n\n')
    if [[ -z "$selected" || "$selected" == *"Cancel and return to menu"* ]]; then
      echo -e "${YELLOW}未选择。返回菜单...${RESET}"
      continue
    fi
    if echo "$selected" | grep -q "Stop all"; then
      TARGET_SESSIONS=$(printf "%s\n" "${sorted_miners[@]}" | grep '^🟢' | sed 's/^[^ ]* //')
    else
      TARGET_SESSIONS=$(echo "$selected" | grep '^🟢' | sed 's/^[^ ]* //')
    fi
    echo -e "${YELLOW}您选择了:${RESET}"
    for session in $TARGET_SESSIONS; do
      echo -e "${CYAN}- $session${RESET}"
    done
    echo -e "${YELLOW}确定要停止这些吗？ (y/n)${RESET}"
    read -rp "$(echo -e "${BOLD_BLUE}> ${RESET}")" CONFIRM_STOP
    [[ ! "$CONFIRM_STOP" =~ ^[Yy]$ ]] && echo -e "${CYAN}返回菜单...${RESET}" && continue
    for session in $TARGET_SESSIONS; do
      echo -e "${CYAN}停止 $session...${RESET}"
      tmux kill-session -t "$session"
    done
    echo -e "${GREEN}✅ 选中的矿工已停止。${RESET}"
    echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
    read -n 1 -s
    continue
    ;;
  8)
    clear
    while true; do
      # 从所有矿工日志中提取网络高度（实时，每次刷新）
      NETWORK_HEIGHT="--"
      all_blocks=()
      for miner_dir in "$HOME/nockchain"/miner*; do
        [[ -d "$miner_dir" ]] || continue
        log_file="$miner_dir/$(basename "$miner_dir").log"
        if [[ -f "$log_file" ]]; then
          height=$(grep -a 'heard block' "$log_file" | tail -n 5 | grep -oP 'height\s+\K[0-9]+\.[0-9]+' | sort -V | tail -n 1)
          [[ -n "$height" ]] && all_blocks+=("$height")
        fi
      done
      if [[ ${#all_blocks[@]} -gt 0 ]]; then
        NETWORK_HEIGHT=$(printf "%s\n" "${all_blocks[@]}" | sort -V | tail -n 1)
      fi
      tput cup 0 0
      echo -e "${DIM}🖥️  实时矿工监控 ${RESET}"
      echo ""
      echo -e "${DIM}图例:${RESET} ${YELLOW}🟡 <5m${RESET} | ${CYAN}🔵 <30m${RESET} | ${GREEN}🟢 稳定 >30m${RESET} | ${DIM}${RED}❌ 未激活${RESET}"
      echo ""
      echo -e "${CYAN}📡 网络高度: ${RESET}$NETWORK_HEIGHT"
      echo ""
      printf "   | %-9s | %-9s | %-9s | %-9s | %-9s | %-5s | %-10s | %-5s\n" "矿工" "运行时间" "CPU (%)" "内存 (%)" "区块" "延迟" "状态" "节点数"

      all_miners=()
      for miner_dir in "$HOME/nockchain"/miner*; do
        [ -d "$miner_dir" ] || continue
        all_miners+=("$(basename "$miner_dir")")
      done
      IFS=$'\n' sorted_miners=($(printf "%s\n" "${all_miners[@]}" | sort -V))
      unset IFS
      if [[ ${#sorted_miners[@]} -eq 0 ]]; then
        echo -e "${YELLOW}未找到矿工或无法读取数据。${RESET}"
        echo -e "${YELLOW}按 Enter 返回菜单...${RESET}"
        read
        break
      fi

      for session in "${sorted_miners[@]}"; do
        miner_dir="$HOME/nockchain/$session"
        log_file="$miner_dir/$session.log"

        if tmux has-session -t "$session" 2>/dev/null; then
          pane_pid=$(tmux list-panes -t "$session" -F "#{pane_pid}" 2>/dev/null)
          miner_pid=$(pgrep -P "$pane_pid" -f nockchain | head -n 1)

          readable="--"
          if [[ -n "$miner_pid" && -r "/proc/$miner_pid/stat" ]]; then
            proc_start_ticks=$(awk '{print $22}' /proc/$miner_pid/stat)
            clk_tck=$(getconf CLK_TCK)
            boot_time=$(awk '/btime/ {print $2}' /proc/stat)
            start_time=$((boot_time + proc_start_ticks / clk_tck))
            now=$(date +%s)
            uptime_secs=$((now - start_time))
            hours=$((uptime_secs / 3600))
            minutes=$(((uptime_secs % 3600) / 60))
            readable="${minutes}m"
            (( hours > 0 )) && readable="${hours}h ${minutes}m"
          fi

          if [[ "$readable" =~ ^([0-9]+)m$ ]]; then
            diff=${BASH_REMATCH[1]}
            if (( diff < 5 )); then
              color="${YELLOW}🟡"
            elif (( diff < 30 )); then
              color="${CYAN}🔵"
            else
              color="${GREEN}🟢"
            fi
          elif [[ "$readable" =~ ^([0-9]+)h ]]; then
            color="${GREEN}🟢"
          else
            color="${YELLOW}🟡"
          fi

          if [[ -n "$miner_pid" ]]; then
            cpu_mem=$(ps -p "$miner_pid" -o %cpu,%mem --no-headers)
            cpu=$(echo "$cpu_mem" | awk '{print $1}')
            mem=$(echo "$cpu_mem" | awk '{print $2}')
          else
            cpu="?"
            mem="?"
          fi

          if [[ -f "$log_file" ]]; then
            latest_block=$(grep -a 'added to validated blocks at' "$log_file" 2>/dev/null | tail -n 1 | grep -oP 'at\s+\K[0-9]+\.[0-9]+' || echo "--")
          else
            latest_block="--"
          fi

          # 从 tmux 缓冲区获取节点数
          peer_count=$(tmux capture-pane -p -t "$session" | grep 'connected_peers=' | tail -n 1 | grep -o 'connected_peers=[0-9]\+' | cut -d= -f2)
          [[ -z "$peer_count" ]] && peer_count="--"

          # 延迟逻辑
          if [[ "$latest_block" =~ ^[0-9]+\.[0-9]+$ && "$NETWORK_HEIGHT" =~ ^[0-9]+\.[0-9]+$ ]]; then
            miner_block=$(echo "$latest_block" | awk -F. '{print ($1 * 1000 + $2)}')
            network_block=$(echo "$NETWORK_HEIGHT" | awk -F. '{print ($1 * 1000 + $2)}')
            lag_int=$((network_block - miner_block))
            (( lag_int < 0 )) && lag_int=0
            lag="$lag_int"
          else
            lag="--"
            lag_int=0
          fi

          if [[ "$lag" =~ ^[0-9]+$ && "$lag_int" -eq 0 ]]; then
            lag_status="⛏️ 挖矿中 "
            lag_color="${GREEN}"
          else
            lag_status="⏳ 同步中"
            lag_color="${YELLOW}"
          fi

          printf "%b | %-9s | %-9s | %-9s | %-9s | %-9s | %-5s | %-10b | %-5s\n" "$color" "$session" "$readable" "$cpu%" "$mem%" "$latest_block" "$lag" "$(echo -e "$lag_color$lag_status$RESET")" "$peer_count"
        else
          # 显示未激活/损坏矿工的默认值
          printf "${DIM}❌ | %-9s | %-9s | %-9s | %-9s | %-9s | %-5s | %-10s | %-5s${RESET}\n" "$session" "--" "--" "--" "--" "--" "未激活" "--"
        fi
      done

      echo ""
      echo -e "${DIM}每 2 秒刷新 — 按 ${BOLD_BLUE}Enter${DIM} 退出。${RESET}"
      key=""
      if read -t 2 -s -r key 2>/dev/null; then
        [[ "$key" == "" ]] && break  # 按下 Enter
      fi
    done
    continue
    ;;
  9)
    clear
    if ! command -v htop &> /dev/null; then
      echo -e "${YELLOW}htop 未安装。正在安装...${RESET}"
      sudo apt-get update && sudo apt-get install -y htop
    fi
    htop
    continue
    ;;
  *)
    echo -e "${RED}无效选项。返回菜单...${RESET}"
    sleep 1
    continue
    ;;
esac

done
