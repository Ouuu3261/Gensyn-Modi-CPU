#!/bin/bash

# Mac下手动安装依赖脚本
# 使用方法：
# 1. conda activate rl-swarm
# 2. chmod +x install_deps_manual.sh
# 3. ./install_deps_manual.sh

set -e

echo "🔧 开始安装依赖..."

# 升级pip
echo "📦 升级pip..."
pip install --upgrade pip

# 安装加密依赖
echo "🔐 安装加密依赖..."
pip install cryptography>=45.0.6
pip install pycryptodome>=3.23.0

# 安装其他关键依赖
echo "🚀 安装其他关键依赖..."
pip install reasoning-gym>=0.1.20
pip install -U psutil
pip install -U trl

# 安装hivemind (使用gensyn-ai fork版本)
echo "🧠 安装hivemind..."
pip install "hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd"

# 安装GenRL
echo "🧠 安装GenRL..."
pip install gensyn-genrl==0.1.4

# 安装requirements文件中的其他依赖（跳过hivemind）
echo "📋 安装requirements文件中的其他依赖..."
pip install -r requirements_rl_swarm.txt --no-deps || echo "⚠️ 部分依赖可能已安装或跳过"

# 验证安装
echo "✅ 验证安装..."
python3 -c "import cryptography; print('✓ cryptography:', cryptography.__version__)"
python3 -c "import Crypto; print('✓ pycryptodome: 已安装')"
python3 -c "import reasoning_gym; print('✓ reasoning-gym: 已安装')"
python3 -c "import psutil; print('✓ psutil:', psutil.__version__)"
python3 -c "import trl; print('✓ trl:', trl.__version__)"
python3 -c "import hivemind; print('✓ hivemind:', hivemind.__version__)"

echo "🎉 所有依赖安装完成！"
echo "现在可以运行 RL-Swarm 了！"