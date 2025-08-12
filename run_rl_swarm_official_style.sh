#!/bin/bash

set -euo pipefail

# General arguments
ROOT=$PWD

# GenRL Swarm version to use
GENRL_TAG="v0.1.1"

export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export CONNECT_TO_TESTNET=true
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export HUGGINGFACE_ACCESS_TOKEN="None"

# BF16修复环境变量
export PYTORCH_ENABLE_MPS_FALLBACK=1
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
export TOKENIZERS_PARALLELISM=false
export TRANSFORMERS_OFFLINE=0
export CUDA_VISIBLE_DEVICES=""  # 禁用CUDA

# Path to an RSA private key. If this path does not exist, hivemind will handle it.
# Remove this file if you want a new PeerID.
DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

DOCKER=${DOCKER:-""}
GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}

# Bit of a workaround for the non-root docker container.
if [ -n "$DOCKER" ]; then
    volumes=(
        /home/gensyn/rl_swarm/modal-login/temp-data
        /home/gensyn/rl_swarm/keys
        /home/gensyn/rl_swarm/configs
        /home/gensyn/rl_swarm/logs
    )

    for volume in ${volumes[@]}; do
        sudo chown -R 1001:1001 $volume
    done
fi

# Will ignore any visible GPUs if set.
CPU_ONLY=${CPU_ONLY:-""}

# Set if successfully parsed from modal-login/temp-data/userData.json.
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() {
    echo -e "$GREEN_TEXT$1$RESET_TEXT"
}

echo_blue() {
    echo -e "$BLUE_TEXT$1$RESET_TEXT"
}

echo_red() {
    echo -e "$RED_TEXT$1$RESET_TEXT"
}

ROOT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

# Function to detect operating system
detect_os() {
    case "$OSTYPE" in
        darwin*)
            echo "macos"
            ;;
        linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Simplified identity file check - only sets environment variable like official script
check_identity_file() {
    echo_green ">> 设置身份文件路径..."
    
    # 确保身份文件路径已设置
    if [[ -z "$IDENTITY_PATH" ]]; then
        IDENTITY_PATH="$DEFAULT_IDENTITY_PATH"
        echo_green "   - 使用默认身份文件路径: $IDENTITY_PATH"
    fi
    
    # 只显示路径信息，不生成文件（让hivemind库处理）
    if [[ -f "$IDENTITY_PATH" ]]; then
        echo_green "   - 身份文件已存在: $IDENTITY_PATH"
    else
        echo_green "   - 身份文件不存在，将由hivemind库自动处理: $IDENTITY_PATH"
    fi
    
    echo_green "✓ 身份文件路径设置完成"
}

# Function to perform pre-startup cleanup
pre_startup_cleanup() {
    echo_green ">> 执行启动前清理检查..."
    
    # 1. 检查并清理可能的僵尸进程
    echo_green "   - 检查僵尸进程..."
    
    # 清理可能残留的yarn进程
    if pgrep -f "yarn start" > /dev/null 2>&1; then
        echo_green "   - 发现残留的yarn进程，正在清理..."
        pkill -f "yarn start" 2> /dev/null || true
        sleep 2
    fi
    
    # 清理可能残留的swarm_launcher进程
    if pgrep -f "swarm_launcher" > /dev/null 2>&1; then
        echo_green "   - 发现残留的swarm_launcher进程，正在清理..."
        pkill -f "swarm_launcher" 2> /dev/null || true
        sleep 2
    fi
    
    # 清理可能残留的python进程（包含rgym_exp）
    if pgrep -f "rgym_exp" > /dev/null 2>&1; then
        echo_green "   - 发现残留的rgym_exp进程，正在清理..."
        pkill -f "rgym_exp" 2> /dev/null || true
        sleep 2
    fi
    
    # 2. 检查并清理端口占用
    echo_green "   - 检查端口占用..."
    
    # 检查3000端口（modal-login服务）
    if command -v lsof > /dev/null 2>&1; then
        if lsof -ti:3000 > /dev/null 2>&1; then
            echo_green "   - 发现3000端口被占用，正在清理..."
            lsof -ti:3000 | xargs kill -9 2> /dev/null || true
            sleep 1
        fi
        
        # 检查8000端口（web服务）
        if lsof -ti:8000 > /dev/null 2>&1; then
            echo_green "   - 发现8000端口被占用，正在清理..."
            lsof -ti:8000 | xargs kill -9 2> /dev/null || true
            sleep 1
        fi
    else
        # 如果没有lsof，使用netstat检查（Linux兼容）
        if command -v netstat > /dev/null 2>&1; then
            local port_3000_pid=$(netstat -tlnp 2>/dev/null | grep ":3000 " | awk '{print $7}' | cut -d'/' -f1)
            local port_8000_pid=$(netstat -tlnp 2>/dev/null | grep ":8000 " | awk '{print $7}' | cut -d'/' -f1)
            
            if [[ -n "$port_3000_pid" && "$port_3000_pid" != "-" ]]; then
                echo_green "   - 发现3000端口被占用(PID: $port_3000_pid)，正在清理..."
                kill -9 "$port_3000_pid" 2> /dev/null || true
            fi
            
            if [[ -n "$port_8000_pid" && "$port_8000_pid" != "-" ]]; then
                echo_green "   - 发现8000端口被占用(PID: $port_8000_pid)，正在清理..."
                kill -9 "$port_8000_pid" 2> /dev/null || true
            fi
        fi
    fi
    
    # 3. 清理临时文件
    echo_green "   - 清理临时文件..."
    rm -rf $ROOT_DIR/modal-login/temp-data/*.json 2> /dev/null || true
    
    # 4. 检查关键目录权限
    if [[ ! -w "$ROOT/logs" ]]; then
        echo_red "   ⚠️  警告: logs目录不可写，尝试修复权限..."
        chmod 755 "$ROOT/logs" 2> /dev/null || true
    fi
    
    echo_green "✓ 启动前清理完成"
}

# Function to clean up the server process upon exit
cleanup() {
    echo_green ">> Shutting down trainer..."

    # Remove modal credentials if they exist
    rm -r $ROOT_DIR/modal-login/temp-data/*.json 2> /dev/null || true

    # Kill all processes belonging to this script's process group
    kill -- -$$ || true

    exit 0
}

errnotify() {
    echo_red ">> An error was detected while running rl-swarm. See $ROOT/logs for full logs."
}

trap cleanup EXIT
trap errnotify ERR

echo -e "\033[38;5;224m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    From Gensyn (Official Style - Let Hivemind Handle Identity)

EOF

echo_green "🔧 官方风格版本启动中（让hivemind库处理身份文件）..."

# 执行启动前清理检查
pre_startup_cleanup

# 检查身份文件路径（不生成文件）
check_identity_file

# 显示操作系统信息
OS_TYPE=$(detect_os)
case $OS_TYPE in
    "macos")
        echo_green "✓ 检测到操作系统: macOS"
        ;;
    "linux")
        echo_green "✓ 检测到操作系统: Linux"
        ;;
    *)
        echo_green "⚠️  检测到未知操作系统: $OSTYPE"
        ;;
esac

# 检查是否在conda环境中（但不强制特定环境名）
if [[ -z "$CONDA_DEFAULT_ENV" ]]; then
    echo_red "⚠️  建议在conda环境中运行此脚本"
    echo_green "💡 如果您使用的是其他Python环境管理工具，请确保已安装所需依赖"
else
    echo_green "✓ 检测到conda环境: $CONDA_DEFAULT_ENV"
fi

# Create logs directory if it doesn't exist
mkdir -p "$ROOT/logs"

if [ "$CONNECT_TO_TESTNET" = true ]; then
    # Run modal_login server.
    echo "Please login to create an Ethereum Server Wallet"
    cd modal-login
    
    # Node.js + NVM setup
    if ! command -v node > /dev/null 2>&1; then
        echo "Node.js not found. Installing NVM and latest Node.js..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node
    else
        echo "Node.js is already installed: $(node -v)"
    fi

    if ! command -v yarn > /dev/null 2>&1; then
        echo "Yarn not found. Installing Yarn globally with npm..."
        # 跨平台Yarn安装
        case $(detect_os) in
            "linux")
                # 在Linux上，优先尝试通过包管理器安装
                if command -v apt-get > /dev/null 2>&1; then
                    echo "Detected APT package manager. Installing Yarn via apt..."
                    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
                    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
                    sudo apt-get update && sudo apt-get install -y yarn
                else
                    # 如果没有apt，则使用npm安装
                    npm install -g --silent yarn
                fi
                ;;
            "macos"|*)
                # macOS或其他系统使用npm安装
                npm install -g --silent yarn
                ;;
        esac
    fi

    ENV_FILE="$ROOT/modal-login/.env"
    # 直接重写.env文件内容
    cat > "$ENV_FILE" << EOF
NEXT_PUBLIC_ALCHEMY_API_KEY=RL2EtY6LXx2XCLPV3JZriJAB9mnELa2U
NEXT_PUBLIC_PAYMASTER_POLICY_ID=4c37387c-2a55-4edd-b188-b5c44eb71e96
SMART_CONTRACT_ADDRESS=${SWARM_CONTRACT}
EOF

    # Docker image already builds it, no need to again.
    if [ -z "$DOCKER" ]; then
        yarn install --immutable
        echo "Building server"
        yarn build > "$ROOT/logs/yarn.log" 2>&1
    fi
    yarn start >> "$ROOT/logs/yarn.log" 2>&1 & # Run in background and log output

    SERVER_PID=$!  # Store the process ID
    echo "Started server process: $SERVER_PID"
    
    # 等待服务器启动并进行健康检查
    echo_green ">> Waiting for server to start (this may take a few minutes for first-time setup)..."
    RETRY_COUNT=0
    MAX_RETRIES=60  # 最多等待60次，每次5秒，总共5分钟
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 检查进程是否还在运行
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo_red "❌ Server process died unexpectedly. Check logs for details:"
            echo_red "   tail -20 $ROOT/logs/yarn.log"
            exit 1
        fi
        
        # 检查服务器是否响应（移除-f参数，只检查连接性）
        if curl -s --connect-timeout 3 --max-time 10 "http://localhost:3000" > /dev/null 2>&1; then
            echo_green "✓ Server is responding on port 3000"
            break
        fi
        
        echo "   Waiting for server... ($((RETRY_COUNT * 5))s elapsed)"
        sleep 5
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done
    
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo_red "❌ Server failed to start within 5 minutes. Check logs:"
        echo_red "   tail -20 $ROOT/logs/yarn.log"
        exit 1
    fi
    
    cd ..
    
    # 等待API key激活
    echo_green ">> Please complete the login process in your browser..."
    echo_green "   URL: http://localhost:3000"
    echo_green "   Waiting for API key activation..."
    
    API_KEY_TIMEOUT=0
    MAX_API_KEY_TIMEOUT=300  # 5分钟超时
    
    while [ $API_KEY_TIMEOUT -lt $MAX_API_KEY_TIMEOUT ]; do
        # 检查API key文件是否存在且包含有效数据
        if [ -f "modal-login/temp-data/userData.json" ]; then
            # 尝试解析JSON并检查是否包含必要字段
            if python3 -c "
import json
import sys
try:
    with open('modal-login/temp-data/userData.json', 'r') as f:
        data = json.load(f)
    # 检查必要字段
    if 'apiKey' in data and data['apiKey'] and 'orgId' in data and data['orgId']:
        print('API key activated successfully')
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null; then
                echo_green "✓ API key activated successfully!"
                break
            fi
        fi
        
        # 检查服务器进程是否还在运行
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo_red "❌ Server process died during API key activation"
            exit 1
        fi
        
        # 显示等待状态
        if [ -f "modal-login/temp-data/userData.json" ]; then
            echo "   API key is pending activation... (${API_KEY_TIMEOUT}s elapsed)"
        else
            echo "   Checking API key status... (${API_KEY_TIMEOUT}s elapsed)"
        fi
        
        sleep 5
        API_KEY_TIMEOUT=$((API_KEY_TIMEOUT + 5))
        
        # 超时检查
        if [ $API_KEY_TIMEOUT -ge $MAX_API_KEY_TIMEOUT ]; then
            echo_red "❌ API key activation timeout after 5 minutes."
            echo_red "   Please check if the login process was completed successfully."
            exit 1
        fi
    done
fi

echo_green ">> Getting requirements..."
pip install --upgrade pip

# 安装关键的加密依赖（如果缺失）
echo_green ">> 检查并安装加密依赖..."
python3 -c "import cryptography" 2>/dev/null || pip install cryptography>=45.0.6
python3 -c "import Crypto" 2>/dev/null || pip install pycryptodome>=3.23.0

# 安装其他关键依赖
echo_green ">> 检查并安装其他关键依赖..."
python3 -c "import reasoning_gym" 2>/dev/null || pip install reasoning-gym>=0.1.20
python3 -c "import psutil" 2>/dev/null || pip install -U psutil
python3 -c "import trl" 2>/dev/null || pip install -U trl

# 安装hivemind (使用gensyn-ai fork版本)
echo_green ">> 安装hivemind..."
python3 -c "import hivemind" 2>/dev/null || pip install "hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd"

# echo_green ">> Installing GenRL..."
pip install gensyn-genrl==0.1.4

# 配置文件处理
if [ ! -d "$ROOT/configs" ]; then
    mkdir "$ROOT/configs"
fi  

# 检查BF16修复配置文件
CONFIG_FILE="configs/rg-swarm-final-fix.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo_red "❌ BF16修复配置文件不存在: $CONFIG_FILE"
    exit 1
fi

echo_green "✓ BF16修复配置文件检查通过"

echo_green ">> Done!"

HF_TOKEN=${HF_TOKEN:-""}
if [ -n "${HF_TOKEN}" ]; then
    HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
    echo -en $GREEN_TEXT
    read -p ">> Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] " yn
    echo -en $RESET_TEXT
    yn=${yn:-N}
    case $yn in
        [Yy]*) read -p "Enter your Hugging Face access token: " HUGGINGFACE_ACCESS_TOKEN ;;
        [Nn]*) HUGGINGFACE_ACCESS_TOKEN="None" ;;
        *) echo ">>> No answer was given, so NO models will be pushed to Hugging Face Hub" && HUGGINGFACE_ACCESS_TOKEN="None" ;;
    esac
fi

echo -en $GREEN_TEXT
read -p ">> Enter the name of the model you want to use in huggingface repo/name format, or press [Enter] to use the default model. " MODEL_NAME
echo -en $RESET_TEXT

# Only export MODEL_NAME if user provided a non-empty value
if [ -n "$MODEL_NAME" ]; then
    export MODEL_NAME
    echo_green ">> Using model: $MODEL_NAME"
else
    echo_green ">> Using default model from config (Gensyn/Qwen2.5-0.5B-Instruct)"
fi

echo_green ">> Good luck in the swarm! (Official Style - Hivemind Handles Identity)"
echo_blue ">> And remember to star the repo on GitHub! --> https://github.com/gensyn-ai/rl-swarm"

echo_green "🚀 启动RL-Swarm（官方风格版本 - 让hivemind处理身份文件）..."

python -m rgym_exp.runner.swarm_launcher \
    --config-path "$ROOT/configs" \
    --config-name "rg-swarm-final-fix.yaml"

wait  # Keep script running until Ctrl+C