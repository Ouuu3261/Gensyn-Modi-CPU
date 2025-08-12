#!/bin/bash
# BF16修复版本的运行脚本

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

# Path to an RSA private key. If this path does not exist, a new key pair will be created.
# Remove this file if you want a new PeerID.
DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

DOCKER=${DOCKER:-""}
GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}

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

# 操作系统检测函数
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# 跨平台浏览器打开函数
open_browser() {
    local url="$1"
    local os_type=$(detect_os)
    
    case $os_type in
        "macos")
            if open "$url" 2> /dev/null; then
                echo_green ">> Successfully opened $url in your default browser (macOS)."
                return 0
            fi
            ;;
        "linux")
            # 检查是否有GUI环境（安全检查未定义变量）
            if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
                # 有GUI环境，尝试打开浏览器
                if command -v xdg-open > /dev/null 2>&1; then
                    if xdg-open "$url" 2> /dev/null; then
                        echo_green ">> Successfully opened $url in your default browser (Linux GUI)."
                        return 0
                    fi
                elif command -v sensible-browser > /dev/null 2>&1; then
                    if sensible-browser "$url" 2> /dev/null; then
                        echo_green ">> Successfully opened $url in your default browser (Linux GUI)."
                        return 0
                    fi
                fi
                echo_green ">> Failed to open browser automatically. Please open $url manually in your browser."
            else
                # 无头环境，直接提示用户手动打开
                echo_green ">> Detected headless environment (no GUI). Please open $url manually in your browser."
                echo_green ">> If you're using SSH, you can:"
                echo_green "   1. Open $url in your local browser"
                echo_green "   2. Or use SSH port forwarding: ssh -L 3000:localhost:3000 user@server"
            fi
            ;;
    esac
    
    return 1
}

# Function to check and fix identity file permissions
check_identity_file() {
    echo_green ">> 检查身份文件权限..."
    
    # 确保身份文件路径已设置
    if [[ -z "$IDENTITY_PATH" ]]; then
        IDENTITY_PATH="$DEFAULT_IDENTITY_PATH"
        echo_green "   - 使用默认身份文件路径: $IDENTITY_PATH"
    fi
    
    # 检查身份文件是否存在
    if [[ ! -f "$IDENTITY_PATH" ]]; then
        echo_green "   - 身份文件不存在，正在生成新的身份文件..."
        
        # 生成新的libp2p格式身份文件
        python3 -c "
import os
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

# libp2p protobuf私钥类
class PrivateKeyProtobuf:
    RSA = 0
    Ed25519 = 1
    Secp256k1 = 2
    ECDSA = 3
    
    def __init__(self, key_type, data):
        self.key_type = key_type
        self.data = data
    
    def serialize_to_string(self):
        result = bytearray()
        # Field 1: key_type (varint)
        result.extend(self._encode_varint(1 << 3 | 0))
        result.extend(self._encode_varint(self.key_type))
        # Field 2: data (length-delimited)
        result.extend(self._encode_varint(2 << 3 | 2))
        result.extend(self._encode_varint(len(self.data)))
        result.extend(self.data)
        return bytes(result)
    
    def _encode_varint(self, value):
        result = bytearray()
        while value >= 0x80:
            result.append((value & 0x7F) | 0x80)
            value >>= 7
        result.append(value & 0x7F)
        return result

try:
    # 生成RSA私钥
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend()
    )
    
    # 获取DER编码的私钥数据
    private_key_der = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    # 创建libp2p protobuf私钥
    libp2p_private_key = PrivateKeyProtobuf(
        key_type=PrivateKeyProtobuf.RSA,
        data=private_key_der
    )
    
    # 序列化为protobuf二进制格式
    protobuf_data = libp2p_private_key.serialize_to_string()
    
    # 写入文件
    with open('$IDENTITY_PATH', 'wb') as f:
        f.write(protobuf_data)
    
    print('✅ libp2p身份文件已生成: $IDENTITY_PATH')
    print('   - 密钥类型: RSA 2048位')
    print('   - 文件格式: libp2p protobuf')
    print('   - 文件大小: {} 字节'.format(len(protobuf_data)))
except Exception as e:
    print(f'❌ 生成libp2p身份文件失败: {e}')
    exit(1)
"
        
        if [[ $? -ne 0 ]]; then
            echo_red "❌ 身份文件生成失败"
            exit 1
        fi
    else
        echo_green "   - 身份文件已存在: $IDENTITY_PATH"
    fi
    
    # 检查并修复文件权限
    local current_perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS使用不同的stat语法，获取八进制权限
        current_perms=$(stat -f "%Lp" "$IDENTITY_PATH" 2>/dev/null | tail -c 4 || echo "")
    else
        # Linux使用标准语法
        current_perms=$(stat -c "%a" "$IDENTITY_PATH" 2>/dev/null || echo "")
    fi
    
    if [[ "$current_perms" != "600" ]]; then
        echo_green "   - 当前权限: $current_perms, 正在修复为600..."
        chmod 600 "$IDENTITY_PATH"
        
        if [[ $? -eq 0 ]]; then
            echo_green "   ✓ 身份文件权限已修复为600"
        else
            echo_red "   ❌ 权限修复失败"
            exit 1
        fi
    else
        echo_green "   ✓ 身份文件权限正确 (600)"
    fi
    
    # 验证文件可读性
    if [[ -r "$IDENTITY_PATH" ]]; then
        echo_green "   ✓ 身份文件可读性验证通过"
    else
        echo_red "   ❌ 身份文件不可读"
        exit 1
    fi
    
    echo_green "✓ 身份文件检查完成"
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

    # Enhanced process cleanup
    echo_green "   - 清理相关进程..."
    pkill -f "yarn start" 2> /dev/null || true
    pkill -f "swarm_launcher" 2> /dev/null || true
    pkill -f "rgym_exp" 2> /dev/null || true

    # 确保身份文件权限正确（防止异常退出后权限被修改）
    if [[ -f "$IDENTITY_PATH" ]]; then
        echo_green "   - 恢复身份文件权限..."
        chmod 600 "$IDENTITY_PATH" 2> /dev/null || true
    fi

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

    From Gensyn (BF16 Fixed Version)

EOF

echo_green "🔧 BF16修复版本启动中..."

# 执行启动前清理检查
pre_startup_cleanup

# 检查身份文件权限
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
        
        # 每10次尝试显示一次进度，避免输出过多
        if [ $((RETRY_COUNT % 10)) -eq 0 ] || [ $RETRY_COUNT -lt 5 ]; then
            echo "   Waiting for server to start... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        fi
        sleep 5
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo_red "❌ Server failed to start within 5 minutes. Check logs:"
        echo_red "   tail -20 $ROOT/logs/yarn.log"
        echo_red "   You can also try running 'cd modal-login && yarn start' manually to see detailed errors."
        exit 1
    fi

    # Try to open the URL in the default browser
    if [ -z "$DOCKER" ]; then
        open_browser "http://localhost:3000" || true
        # 无论是否成功打开浏览器，都继续等待用户操作
        echo_green ">> Waiting for you to complete the login process in your browser..."
    else
        echo_green ">> Please open http://localhost:3000 in your host browser."
    fi

    cd ..

    echo_green ">> Waiting for modal userData.json to be created..."
    LOGIN_TIMEOUT=0
    MAX_LOGIN_TIMEOUT=1800  # 30分钟超时
    
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        # 定期检查服务器进程是否还在运行
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo_red "❌ Server process died while waiting for login. Check logs:"
            echo_red "   tail -20 $ROOT/logs/yarn.log"
            exit 1
        fi
        
        # 每60秒显示一次等待提示，避免用户以为脚本卡住了
        if [ $((LOGIN_TIMEOUT % 60)) -eq 0 ]; then
            echo_green "   Still waiting for login... (${LOGIN_TIMEOUT}s elapsed)"
            echo_green "   Please make sure you have:"
            echo_green "   1. Opened http://localhost:3000 in your browser (or via SSH port forwarding)"
            echo_green "   2. Completed the login process"
            echo_green "   3. The login page shows 'Success' or similar confirmation"
        fi
        
        sleep 5  # Wait for 5 seconds before checking again
        LOGIN_TIMEOUT=$((LOGIN_TIMEOUT + 5))
        
        # 超时检查
        if [ $LOGIN_TIMEOUT -ge $MAX_LOGIN_TIMEOUT ]; then
            echo_red "❌ Login timeout after 30 minutes. Please check:"
            echo_red "   1. Server is accessible at http://localhost:3000"
            echo_red "   2. You have completed the login process"
            echo_red "   3. Check server logs: tail -20 $ROOT/logs/yarn.log"
            echo_red "   4. If using SSH, ensure port forwarding is working: ssh -L 3000:localhost:3000 user@server"
            exit 1
        fi
    done
    echo_green "✓ Found userData.json. Proceeding..."

    # 验证userData.json文件内容
    if [ ! -s "modal-login/temp-data/userData.json" ]; then
        echo_red "❌ userData.json file is empty. Login may have failed."
        exit 1
    fi

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    if [ -z "$ORG_ID" ]; then
        echo_red "❌ Failed to extract ORG_ID from userData.json. File may be corrupted."
        echo_red "   File contents:"
        cat modal-login/temp-data/userData.json
        exit 1
    fi
    echo_green "✓ Your ORG_ID is set to: $ORG_ID"

    # Wait until the API key is activated by the client
    echo_green ">> Waiting for API key to become activated..."
    API_KEY_TIMEOUT=0
    MAX_API_KEY_TIMEOUT=300  # 5分钟超时
    
    while true; do
        # 检查服务器进程是否还在运行
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo_red "❌ Server process died while waiting for API key activation. Check logs:"
            echo_red "   tail -20 $ROOT/logs/yarn.log"
            exit 1
        fi
        
        STATUS=$(curl -s --connect-timeout 5 --max-time 10 "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID" 2>/dev/null || echo "error")
        if [[ "$STATUS" == "activated" ]]; then
            echo_green "✓ API key is activated! Proceeding..."
            break
        elif [[ "$STATUS" == "pending" ]]; then
            echo "   API key is pending activation... (${API_KEY_TIMEOUT}s elapsed)"
        else
            echo "   Checking API key status... (${API_KEY_TIMEOUT}s elapsed)"
        fi
        
        sleep 5
        API_KEY_TIMEOUT=$((API_KEY_TIMEOUT + 5))
        
        # 超时检查
        if [ $API_KEY_TIMEOUT -ge $MAX_API_KEY_TIMEOUT ]; then
            echo_red "❌ API key activation timeout after 5 minutes."
            echo_red "   Current status: $STATUS"
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

echo_green ">> Good luck in the swarm! (BF16 Fixed Version)"
echo_blue ">> And remember to star the repo on GitHub! --> https://github.com/gensyn-ai/rl-swarm"

echo_green "🚀 启动RL-Swarm（BF16修复版本）..."

python -m rgym_exp.runner.swarm_launcher \
    --config-path "$ROOT/configs" \
    --config-name "rg-swarm-final-fix.yaml"

wait  # Keep script running until Ctrl+C
