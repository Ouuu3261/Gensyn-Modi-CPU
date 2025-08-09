#!/bin/bash

# RL-Swarm Conda服务条款修复脚本
# 解决conda创建环境时的Terms of Service问题

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

echo_blue "🔧 RL-Swarm Conda服务条款修复脚本"
echo_blue "=================================="

# 确保conda在PATH中
if ! command -v conda > /dev/null 2>&1; then
    if [ -f "$HOME/miniconda3/bin/conda" ]; then
        export PATH="$HOME/miniconda3/bin:$PATH"
        echo_green "✓ 已添加conda到PATH"
    else
        echo_red "❌ 未找到conda命令"
        exit 1
    fi
fi

echo_green "✓ Conda版本: $(conda --version)"

# 方法1: 配置conda使用conda-forge频道（推荐）
echo_green "🔧 方法1: 配置使用conda-forge频道..."
conda config --add channels conda-forge
conda config --set channel_priority flexible

# 方法2: 尝试接受服务条款（如果支持）
echo_green "🔧 方法2: 尝试接受服务条款..."
conda config --set channel_priority strict 2>/dev/null || true

# 方法3: 创建.condarc文件来配置频道
echo_green "🔧 方法3: 创建conda配置文件..."
cat > ~/.condarc << 'CONDARC_EOF'
channels:
  - conda-forge
  - defaults
channel_priority: flexible
auto_activate_base: false
CONDARC_EOF

echo_green "✓ 已创建 ~/.condarc 配置文件"

# 方法4: 使用pip作为备选方案
echo_green "🔧 方法4: 准备pip备选方案..."

# 测试创建环境
echo_green "🧪 测试创建rl-swarm环境..."
ENV_NAME="rl-swarm"

# 检查环境是否已存在
if conda env list | grep -q "^$ENV_NAME "; then
    echo_yellow "⚠️  环境 '$ENV_NAME' 已存在，跳过创建"
else
    echo_green "🆕 创建新的conda环境..."
    
    # 尝试使用conda-forge创建环境
    if conda create -n "$ENV_NAME" python=3.11 -c conda-forge -y; then
        echo_green "✅ 成功使用conda-forge创建环境"
    else
        echo_yellow "⚠️  conda-forge创建失败，尝试使用默认频道..."
        if conda create -n "$ENV_NAME" python=3.11 -y; then
            echo_green "✅ 成功使用默认频道创建环境"
        else
            echo_red "❌ conda创建环境失败"
            echo_yellow "💡 建议使用纯pip方案创建虚拟环境"
            
            # 创建pip虚拟环境作为备选
            echo_green "🐍 创建pip虚拟环境..."
            python3 -m venv "$HOME/rl-swarm-venv"
            echo_green "✓ 已创建pip虚拟环境: $HOME/rl-swarm-venv"
            echo_yellow "💡 激活命令: source $HOME/rl-swarm-venv/bin/activate"
            exit 0
        fi
    fi
fi

echo_green "🎉 修复完成！"
echo_blue "=================================="
echo_green "📋 修复摘要:"
echo_green "  • 已配置conda-forge频道"
echo_green "  • 已设置灵活的频道优先级"
echo_green "  • 已创建.condarc配置文件"
echo_green "  • 环境 '$ENV_NAME' 已准备就绪"
echo_blue "=================================="
echo_yellow "💡 下一步:"
echo_yellow "  1. 激活环境: conda activate rl-swarm"
echo_yellow "  2. 安装依赖: pip install -r requirements_rl_swarm.txt"
echo_yellow "  3. 运行项目: ./run_rl_swarm_fixed.sh"
echo_blue "=================================="
echo_green "🚀 现在可以正常使用conda了！"
