#!/bin/bash

# RL-Swarm 核心依赖安装脚本
# 基于原始 run_rl_swarm.sh 的依赖安装方式

set -euo pipefail

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

echo_green ">> 开始安装RL-Swarm核心依赖..."

# 检查是否在conda环境中
if [[ "$CONDA_DEFAULT_ENV" != "rl-swarm" ]]; then
    echo_red ">> 警告：请确保你在 rl-swarm conda 环境中运行此脚本"
    echo_blue ">> 运行: conda activate rl-swarm"
    exit 1
fi

echo_green ">> 升级pip..."
pip install --upgrade pip

echo_green ">> 安装GenRL..."
pip install gensyn-genrl==0.1.4

echo_green ">> 安装Reasoning Gym..."
pip install reasoning-gym>=0.1.20

echo_green ">> 安装TRL..."
pip install trl

echo_green ">> 安装Hivemind（特定版本）..."
pip install hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd

echo_green ">> 验证安装..."
python -c "
try:
    import genrl
    import reasoning_gym
    import trl
    import hivemind
    print('✅ 所有核心依赖安装成功！')
except ImportError as e:
    print(f'❌ 导入失败: {e}')
    exit(1)
"

echo_green ">> 核心依赖安装完成！"
echo_blue ">> 现在你可以运行 RL-Swarm 了"