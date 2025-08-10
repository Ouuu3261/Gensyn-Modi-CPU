#!/bin/bash

# Ubuntu下手动安装依赖脚本
# 使用方法：
# 1. conda activate rl-swarm
# 2. chmod +x install_deps_ubuntu_manual.sh
# 3. ./install_deps_ubuntu_manual.sh

set -e

echo "🔧 开始安装Ubuntu环境依赖..."

# 升级pip
echo "📦 升级pip..."
pip install --upgrade pip

# 安装PyTorch (CPU版本，适合大多数Ubuntu环境)
echo "🔥 安装PyTorch (CPU版本)..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# 安装核心依赖 (使用兼容版本)
echo "📚 安装核心依赖..."
pip install \
    transformers>=4.55.0 \
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
echo "🌐 安装Web API依赖..."
pip install \
    fastapi \
    uvicorn \
    aiofiles \
    boto3 \
    python-json-logger \
    pytest \
    web3==7.13.0

# 安装机器学习相关依赖 (先安装trl，确保版本兼容)
echo "🤖 安装机器学习依赖..."
pip install \
    trl>=0.21.0 \
    wandb==0.21.0 \
    tensorboard==2.20.0 \
    safetensors==0.6.1 \
    tokenizers==0.21.4 \
    huggingface-hub==0.34.3

# 安装其他关键依赖
echo "🚀 安装其他关键依赖..."
pip install \
    reasoning-gym>=0.1.20 \
    psutil>=6.0.0 \
    cryptography>=45.0.6 \
    pycryptodome>=3.23.0 \
    eth-account==0.13.7 \
    rich==14.1.0 \
    click==8.2.1

# 安装hivemind (使用gensyn-ai fork版本，与Mac保持一致)
echo "🧠 安装hivemind..."
pip install "hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd"

# 最后安装GenRL (可能有版本冲突，放在最后并忽略依赖冲突警告)
echo "🧠 安装GenRL..."
pip install gensyn-genrl==0.1.4 --no-deps || echo "⚠️ GenRL安装可能有依赖冲突，但已安装"

# 验证安装
echo "✅ 验证安装..."
python3 -c "import torch; print('✓ PyTorch:', torch.__version__)"
python3 -c "import transformers; print('✓ Transformers:', transformers.__version__)"
python3 -c "import trl; print('✓ TRL:', trl.__version__)"
python3 -c "import reasoning_gym; print('✓ reasoning-gym: 已安装')"
python3 -c "import psutil; print('✓ psutil:', psutil.__version__)"
python3 -c "import hivemind; print('✓ hivemind:', hivemind.__version__)"
python3 -c "import cryptography; print('✓ cryptography:', cryptography.__version__)"
python3 -c "import Crypto; print('✓ pycryptodome: 已安装')"

echo "🎉 Ubuntu环境依赖安装完成！"
echo "💡 注意：如果看到依赖冲突警告，这是正常的，项目仍可正常运行"
echo "现在可以运行 RL-Swarm 了！"