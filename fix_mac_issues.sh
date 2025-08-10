#!/bin/bash
# Mac专用快速修复脚本 - 解决cryptography和unbound variable问题

set -euo pipefail

GREEN_TEXT="\033[32m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() {
    echo -e "$GREEN_TEXT$1$RESET_TEXT"
}

echo_red() {
    echo -e "$RED_TEXT$1$RESET_TEXT"
}

echo_green "🔧 Mac专用快速修复脚本启动..."

# 1. 检查并激活conda环境
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo_green ">> 尝试激活rl-swarm conda环境..."
    if command -v conda > /dev/null 2>&1; then
        # 初始化conda
        eval "$(conda shell.bash hook)" 2>/dev/null || true
        
        # 尝试激活rl-swarm环境
        if conda env list | grep -q "rl-swarm"; then
            conda activate rl-swarm
            echo_green "✓ 已激活rl-swarm环境"
        else
            echo_red "❌ rl-swarm环境不存在，请先运行setup_macos_conda.sh"
            exit 1
        fi
    else
        echo_red "❌ conda未安装，请先安装conda"
        exit 1
    fi
else
    echo_green "✓ 当前conda环境: $CONDA_DEFAULT_ENV"
fi

# 2. 强制安装cryptography依赖
echo_green ">> 强制安装cryptography依赖..."
pip install --upgrade pip
pip install --force-reinstall cryptography>=45.0.6
pip install --force-reinstall pycryptodome>=3.23.0

# 验证安装
python3 -c "import cryptography; print('✓ cryptography安装成功:', cryptography.__version__)" || {
    echo_red "❌ cryptography安装失败"
    exit 1
}

python3 -c "import Crypto; print('✓ pycryptodome安装成功')" || {
    echo_red "❌ pycryptodome安装失败"
    exit 1
}

# 3. 修复身份文件权限
echo_green ">> 修复身份文件权限..."
IDENTITY_PATH="./swarm.pem"

if [[ -f "$IDENTITY_PATH" ]]; then
    echo_green "   - 发现现有身份文件，修复权限..."
    chmod 600 "$IDENTITY_PATH"
    echo_green "   ✓ 身份文件权限已修复"
else
    echo_green "   - 身份文件不存在，将在启动时自动生成"
fi

# 4. 清理可能的进程冲突
echo_green ">> 清理可能的进程冲突..."
pkill -f "yarn start" 2>/dev/null || true
pkill -f "swarm_launcher" 2>/dev/null || true
pkill -f "rgym_exp" 2>/dev/null || true

# 清理端口占用
if command -v lsof > /dev/null 2>&1; then
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
fi

# 5. 清理临时文件
echo_green ">> 清理临时文件..."
rm -rf ./modal-login/temp-data/*.json 2>/dev/null || true
rm -rf ./logs/*.log 2>/dev/null || true

# 6. 验证脚本权限
echo_green ">> 检查脚本权限..."
chmod +x ./run_rl_swarm_fixed.sh
chmod +x ./run_rl_swarm.sh

# 7. 测试关键功能
echo_green ">> 测试关键功能..."

# 测试stat命令兼容性
if [[ "$OSTYPE" == "darwin"* ]]; then
    test_file="/tmp/test_stat_$$"
    touch "$test_file"
    chmod 600 "$test_file"
    
    # 测试macOS stat语法
    perms=$(stat -f "%A" "$test_file" 2>/dev/null || echo "")
    if [[ "$perms" == "600" ]]; then
        echo_green "   ✓ stat命令兼容性测试通过"
    else
        echo_red "   ❌ stat命令兼容性测试失败"
    fi
    
    rm -f "$test_file"
fi

# 8. 安装其他必要依赖
echo_green ">> 安装其他必要依赖..."
pip install gensyn-genrl==0.1.4

echo_green "🎉 Mac修复完成！"
echo_green ""
echo_green "现在您可以运行以下命令启动RL-Swarm："
echo_green "  ./run_rl_swarm_fixed.sh"
echo_green ""
echo_green "如果仍有问题，请检查："
echo_green "1. 确保在rl-swarm conda环境中"
echo_green "2. 确保网络连接正常"
echo_green "3. 确保有足够的磁盘空间"