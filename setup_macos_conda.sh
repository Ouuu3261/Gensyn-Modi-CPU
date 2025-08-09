#!/bin/bash

# RL-Swarm macOS Conda 环境设置脚本
# 用于在已安装Anaconda的macOS系统上创建项目虚拟环境

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

echo_blue "🍎 RL-Swarm macOS Conda 环境设置脚本"
echo_blue "====================================="

# 检查操作系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo_red "❌ 此脚本仅适用于macOS系统"
    echo_yellow "💡 如果您使用的是Ubuntu/Linux，请使用 setup_ubuntu_miniconda.sh 脚本"
    exit 1
fi

echo_green "✓ 检测到macOS系统，开始设置..."

# 检查conda是否已安装
if ! command -v conda > /dev/null 2>&1; then
    echo_red "❌ 未检测到conda命令"
    echo_yellow "💡 请先手动安装Anaconda或Miniconda："
    echo_yellow "   • Anaconda: https://www.anaconda.com/products/distribution"
    echo_yellow "   • Miniconda: https://docs.conda.io/en/latest/miniconda.html"
    echo_yellow "   • 或使用Homebrew: brew install --cask anaconda"
    exit 1
fi

echo_green "✓ 检测到conda: $(conda --version)"

# 检查系统依赖
echo_green "🔍 检查系统依赖..."

# 检查Homebrew
if ! command -v brew > /dev/null 2>&1; then
    echo_yellow "⚠️  未检测到Homebrew，建议安装以便管理系统依赖"
    echo_yellow "💡 安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
else
    echo_green "✓ Homebrew已安装: $(brew --version | head -n1)"
    
    # 安装必要的系统工具
    echo_green "📦 安装/更新系统工具..."
    brew install git curl wget jq node yarn || true
fi

# 检查必要工具
REQUIRED_TOOLS=("git" "curl" "node" "yarn")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" > /dev/null 2>&1; then
        echo_green "✓ $tool: $(command -v "$tool")"
    else
        echo_yellow "⚠️  $tool 未安装，可能需要手动安装"
    fi
done

# 配置conda
echo_green "⚙️  配置conda..."
conda config --set auto_activate_base false
conda config --add channels conda-forge
conda config --add channels pytorch
conda config --add channels nvidia

# 创建RL-Swarm虚拟环境
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

# 安装Python依赖
echo_green "📦 安装Python依赖包..."

# 升级pip
pip install --upgrade pip

# 检测Apple Silicon (M1/M2) 或 Intel
if [[ $(uname -m) == "arm64" ]]; then
    echo_green "🍎 检测到Apple Silicon (M1/M2)，安装优化版本..."
    # 对于Apple Silicon，使用MPS后端的PyTorch
    pip install torch torchvision torchaudio
else
    echo_green "💻 检测到Intel Mac，安装标准版本..."
    # 对于Intel Mac，使用CPU版本
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
fi

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

# 创建环境激活脚本
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
    
    # 检测处理器类型并显示相关信息
    if [[ $(uname -m) == "arm64" ]]; then
        echo "🍎 Apple Silicon (M1/M2) - 支持MPS加速"
    else
        echo "💻 Intel Mac - CPU模式"
    fi
else
    echo "❌ 未找到conda命令"
    exit 1
fi
EOF

chmod +x "$ACTIVATE_SCRIPT"

# 验证安装
echo_green "🔍 验证安装..."
python -c "import torch; print(f'✓ PyTorch: {torch.__version__}')"
python -c "import transformers; print(f'✓ Transformers: {transformers.__version__}')"
python -c "import datasets; print(f'✓ Datasets: {datasets.__version__}')"
python -c "import hivemind; print(f'✓ Hivemind: {hivemind.__version__}')"

# 检测MPS支持 (仅Apple Silicon)
if [[ $(uname -m) == "arm64" ]]; then
    python -c "import torch; print(f'✓ MPS可用: {torch.backends.mps.is_available()}')" 2>/dev/null || echo "⚠️  MPS检测失败"
fi

echo_green "🎉 安装完成！"
echo_blue "====================================="
echo_green "📋 安装摘要:"
echo_green "  • Conda: $(conda --version)"
echo_green "  • Python环境: $ENV_NAME"
echo_green "  • Python版本: $(python --version)"
echo_green "  • 处理器: $(uname -m)"
if command -v node > /dev/null 2>&1; then
    echo_green "  • Node.js: $(node --version)"
fi
if command -v yarn > /dev/null 2>&1; then
    echo_green "  • Yarn: $(yarn --version)"
fi
echo_blue "====================================="
echo_yellow "💡 使用说明:"
echo_yellow "  1. 激活环境: conda activate rl-swarm"
echo_yellow "  2. 或使用快捷脚本: ./activate_rl_swarm.sh"
echo_yellow "  3. 运行项目: ./run_rl_swarm_fixed.sh"
echo_blue "====================================="
if [[ $(uname -m) == "arm64" ]]; then
    echo_green "🚀 Apple Silicon优化完成，现在可以运行RL-Swarm项目了！"
else
    echo_green "🚀 Intel Mac设置完成，现在可以运行RL-Swarm项目了！"
fi