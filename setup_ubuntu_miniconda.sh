#!/bin/bash

# RL-Swarm Ubuntu Miniconda 安装脚本
# 用于在全新的Ubuntu系统上安装Miniconda并创建项目虚拟环境

set -euo pipefail

# 颜色输出函数
RED_TEXT='\033[0;31m'
GREEN_TEXT='\033[0;32m'
YELLOW_TEXT='\033[1;33m'
BLUE_TEXT='\033[0;34m'
RESET_TEXT='\033[0m'

echo_red() {
    echo -e "${RED_TEXT}$1${RESET_TEXT}"
}

echo_green() {
    echo -e "${GREEN_TEXT}$1${RESET_TEXT}"
}

echo_yellow() {
    echo -e "${YELLOW_TEXT}$1${RESET_TEXT}"
}

echo_blue() {
    echo -e "${BLUE_TEXT}$1${RESET_TEXT}"
}

# 获取脚本所在目录
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo_blue "🐧 RL-Swarm Ubuntu Miniconda 安装脚本"
echo_blue "======================================"

# 检查操作系统
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo_red "❌ 此脚本仅适用于Ubuntu/Linux系统"
    echo_yellow "💡 如果您使用的是macOS，请使用 setup_macos_conda.sh 脚本"
    exit 1
fi

# 检查是否为Ubuntu系统
if ! command -v apt-get > /dev/null 2>&1; then
    echo_yellow "⚠️  未检测到apt包管理器，脚本可能不完全适用于您的Linux发行版"
    echo_yellow "💡 脚本将继续执行，但某些包安装可能失败"
fi

echo_green "✓ 检测到Linux系统，开始安装..."

# 1. 更新系统包
echo_green "📦 更新系统包..."
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. 安装系统依赖
echo_green "🔧 安装系统依赖包..."
sudo apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    htop \
    vim \
    unzip \
    zip \
    tree

# 3. 检查并安装Miniconda
if command -v conda > /dev/null 2>&1; then
    echo_yellow "⚠️  检测到已安装的conda: $(conda --version)"
    echo_yellow "💡 跳过Miniconda安装步骤"
else
    echo_green "📥 下载并安装Miniconda..."
    
    # 下载Miniconda安装包
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    MINICONDA_INSTALLER="/tmp/miniconda.sh"
    
    echo_green "⬇️  下载Miniconda安装包..."
    wget -q "$MINICONDA_URL" -O "$MINICONDA_INSTALLER"
    
    # 安装Miniconda
    echo_green "🚀 安装Miniconda..."
    bash "$MINICONDA_INSTALLER" -b -p "$HOME/miniconda3"
    
    # 清理安装包
    rm -f "$MINICONDA_INSTALLER"
    
    # 初始化conda
    echo_green "⚙️  初始化conda..."
    "$HOME/miniconda3/bin/conda" init bash
    
    # 重新加载bash配置
    source "$HOME/.bashrc" 2>/dev/null || true
    
    # 添加conda到PATH
    export PATH="$HOME/miniconda3/bin:$PATH"
    
    echo_green "✅ Miniconda安装完成"
fi

# 4. 确保conda可用
if ! command -v conda > /dev/null 2>&1; then
    # 尝试手动添加conda到PATH
    if [ -f "$HOME/miniconda3/bin/conda" ]; then
        export PATH="$HOME/miniconda3/bin:$PATH"
    elif [ -f "$HOME/anaconda3/bin/conda" ]; then
        export PATH="$HOME/anaconda3/bin:$PATH"
    else
        echo_red "❌ 无法找到conda命令，请手动检查安装"
        exit 1
    fi
fi

echo_green "✓ Conda版本: $(conda --version)"

# 5. 配置conda
echo_green "⚙️  配置conda..."
conda config --set auto_activate_base false
conda config --add channels conda-forge
conda config --add channels pytorch
conda config --add channels nvidia

# 6. 创建RL-Swarm虚拟环境
ENV_NAME="rl-swarm"
echo_green "🐍 创建Python虚拟环境: $ENV_NAME"

# 检查环境是否已存在
if conda env list | grep -q "^$ENV_NAME "; then
    echo_yellow "⚠️  环境 '$ENV_NAME' 已存在"
    read -p "是否删除并重新创建？[y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_yellow "🗑️  删除现有环境..."
        conda env remove -n "$ENV_NAME" -y
    else
        echo_green "💡 使用现有环境，跳过创建步骤"
        conda activate "$ENV_NAME"
        echo_green "✓ 已激活环境: $ENV_NAME"
        exit 0
    fi
fi

# 创建新环境
echo_green "🆕 创建新的conda环境..."
conda create -n "$ENV_NAME" python=3.11 -y

# 激活环境
echo_green "🔄 激活环境..."
conda activate "$ENV_NAME"

# 7. 安装Python依赖
echo_green "📦 安装Python依赖包..."

# 升级pip
pip install --upgrade pip

# 安装PyTorch (CPU版本，适合大多数环境)
echo_green "🔥 安装PyTorch (CPU版本)..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# 安装核心依赖
echo_green "📚 安装核心依赖..."
pip install \
    transformers==4.51.3 \
    datasets==4.0.0 \
    accelerate==1.9.0 \
    pydantic==2.11.7 \
    numpy==2.1.2 \
    pandas==2.3.1 \
    scipy==1.15.3 \
    matplotlib==3.10.5 \
    tqdm==4.67.1 \
    requests==2.32.4 \
    PyYAML==6.0.2 \
    hydra-core==1.3.2 \
    omegaconf==2.3.0

# 安装Web API依赖
echo_green "🌐 安装Web API依赖..."
pip install \
    fastapi \
    uvicorn \
    aiofiles \
    boto3 \
    python-json-logger \
    pytest \
    web3==7.13.0

# 安装机器学习相关依赖
echo_green "🤖 安装机器学习依赖..."
pip install \
    trl==0.21.0 \
    wandb==0.21.0 \
    tensorboard==2.20.0 \
    safetensors==0.6.1 \
    tokenizers==0.21.4 \
    huggingface-hub==0.34.3

# 安装Hivemind (分布式训练)
echo_green "🐝 安装Hivemind..."
pip install "hivemind @ git+https://github.com/learning-at-home/hivemind@1.11.11"

# 安装其他项目特定依赖
echo_green "🔧 安装其他依赖..."
pip install \
    reasoning_gym==0.1.23 \
    gensyn-genrl==0.1.4 \
    cryptography==45.0.6 \
    eth-account==0.13.7 \
    psutil==7.0.0 \
    rich==14.1.0 \
    click==8.2.1

# 8. 安装Node.js和Yarn (用于前端)
echo_green "📦 安装Node.js和Yarn..."

# 安装Node.js
if ! command -v node > /dev/null 2>&1; then
    echo_green "📥 安装Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo_green "✓ Node.js已安装: $(node --version)"
fi

# 安装Yarn
if ! command -v yarn > /dev/null 2>&1; then
    echo_green "📥 安装Yarn..."
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt-get update && sudo apt-get install -y yarn
else
    echo_green "✓ Yarn已安装: $(yarn --version)"
fi

# 9. 创建环境激活脚本
ACTIVATE_SCRIPT="$ROOT/activate_rl_swarm.sh"
echo_green "📝 创建环境激活脚本: $ACTIVATE_SCRIPT"

cat > "$ACTIVATE_SCRIPT" << 'EOF'
#!/bin/bash
# RL-Swarm 环境激活脚本

# 激活conda环境
if command -v conda > /dev/null 2>&1; then
    conda activate rl-swarm
    echo "✅ 已激活RL-Swarm conda环境"
    echo "🐍 Python版本: $(python --version)"
    echo "📦 Conda环境: $CONDA_DEFAULT_ENV"
else
    echo "❌ 未找到conda命令"
    exit 1
fi
EOF

chmod +x "$ACTIVATE_SCRIPT"

# 10. 验证安装
echo_green "🔍 验证安装..."
python -c "import torch; print(f'✓ PyTorch: {torch.__version__}')"
python -c "import transformers; print(f'✓ Transformers: {transformers.__version__}')"
python -c "import datasets; print(f'✓ Datasets: {datasets.__version__}')"
python -c "import hivemind; print(f'✓ Hivemind: {hivemind.__version__}')"

echo_green "🎉 安装完成！"
echo_blue "======================================"
echo_green "📋 安装摘要:"
echo_green "  • Miniconda: $(conda --version)"
echo_green "  • Python环境: $ENV_NAME"
echo_green "  • Python版本: $(python --version)"
echo_green "  • Node.js: $(node --version)"
echo_green "  • Yarn: $(yarn --version)"
echo_blue "======================================"
echo_yellow "💡 使用说明:"
echo_yellow "  1. 重新打开终端或运行: source ~/.bashrc"
echo_yellow "  2. 激活环境: conda activate rl-swarm"
echo_yellow "  3. 或使用快捷脚本: ./activate_rl_swarm.sh"
echo_yellow "  4. 运行项目: ./run_rl_swarm_fixed.sh"
echo_blue "======================================"
echo_green "🚀 现在可以运行RL-Swarm项目了！"