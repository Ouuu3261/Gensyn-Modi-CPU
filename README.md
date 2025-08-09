# RL-Swarm 环境设置指南

## 🚀 快速开始

### 一键部署

#### Ubuntu/Linux 系统
```bash
# 克隆仓库
git clone https://github.com/Ouuu3261/Gensyn-Modi-CPU.git
cd Gensyn-Modi-CPU

# 运行自动安装脚本
./setup_ubuntu_miniconda.sh

# 如果遇到 Anaconda 服务条款问题，运行以下命令
conda tos accept

# 激活环境并启动
source ~/.bashrc
conda activate rl-swarm
./run_rl_swarm_fixed.sh
```

#### macOS 系统
```bash
# 克隆仓库
git clone https://github.com/Ouuu3261/Gensyn-Modi-CPU.git
cd Gensyn-Modi-CPU

# 运行环境设置脚本
./setup_macos_conda.sh

# 激活环境并启动
conda activate rl-swarm
./run_rl_swarm_fixed.sh
```

## 📋 系统要求

### 硬件要求
- **内存**: 最少 8GB，推荐 16GB+
- **存储**: 至少 10GB 可用空间
- **网络**: 稳定的互联网连接

### 软件要求
- **Python**: 3.9+ (推荐 3.11)
- **操作系统**: Ubuntu 18.04+, macOS 10.15+

## ⚠️ 重要说明

本软件为**实验性质**，适用于对 Gensyn 协议早期版本感兴趣的用户。

如果您关心链上参与，请务必阅读下方的[身份管理](#身份管理)部分。

如遇问题，请先查看[故障排除](#故障排除)部分。如无法解决，请在 [Issues](../../issues) 中查找相关问题或创建新问题。

## 🔧 自动化脚本功能

### Ubuntu/Linux 脚本 (`setup_ubuntu_miniconda.sh`)
- 自动检测并安装 Miniconda
- 创建专用的 `rl-swarm` conda 环境
- 安装所有必需的 Python 依赖包
- 配置环境变量和路径
- 设置 BF16 优化（如果支持）

### macOS 脚本 (`setup_macos_conda.sh`)
- 检测 Homebrew 并自动安装（如需要）
- 安装 Miniconda（如果未安装）
- 创建优化的 conda 环境
- 处理 macOS 特定的依赖问题
- 配置 Metal Performance Shaders (MPS) 支持

## 📦 安装后操作

### 验证安装
```bash
# 检查 conda 环境
conda info --envs

# 激活环境
conda activate rl-swarm

# 验证 Python 版本
python --version

# 检查关键包
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import transformers; print(f'Transformers: {transformers.__version__}')"
```

### 环境激活
```bash
# 每次使用前激活环境
conda activate rl-swarm

# 或使用完整路径
source ~/miniconda3/bin/activate rl-swarm
```

## 📋 依赖包详情

### 核心依赖
- **PyTorch**: 深度学习框架
- **Transformers**: Hugging Face 模型库
- **Datasets**: 数据处理工具
- **Accelerate**: 分布式训练支持
- **Tokenizers**: 高效文本处理

### 强化学习相关
- **Gymnasium**: 强化学习环境
- **Stable-Baselines3**: RL 算法实现
- **Wandb**: 实验跟踪和可视化

### 系统工具
- **Requests**: HTTP 请求处理
- **Psutil**: 系统监控
- **Tqdm**: 进度条显示

## 🔧 环境配置

### 环境变量设置
```bash
# 设置 CUDA 相关（如果有 GPU）
export CUDA_VISIBLE_DEVICES=0

# 设置 PyTorch 优化
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# macOS MPS 优化
export PYTORCH_ENABLE_MPS_FALLBACK=1
```

### 内存优化
```bash
# 设置 BF16 优化
export TORCH_DTYPE=bfloat16

# 限制内存使用
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.8
```

## 🛠️ 故障排除

### 常见问题

#### 1. Conda 环境创建失败
```bash
# 如果遇到 Anaconda 服务条款问题
conda tos accept

# 清理 conda 缓存
conda clean --all

# 重新创建环境
conda env remove -n rl-swarm
./setup_ubuntu_miniconda.sh  # 或 setup_macos_conda.sh
```

#### 2. 包安装冲突
```bash
# 使用 mamba 替代 conda（更快）
conda install mamba -n base -c conda-forge
mamba env create -f environment.yml
```

#### 3. PyTorch 安装问题
```bash
# 手动安装 PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

#### 4. macOS 权限问题
```bash
# 修复权限
sudo chown -R $(whoami) ~/miniconda3
chmod +x setup_macos_conda.sh
```

### 系统特定问题

#### Ubuntu/Linux
- **依赖缺失**: `sudo apt-get install build-essential`
- **Python 版本**: 确保使用 Python 3.9+
- **内存不足**: 增加 swap 空间

#### macOS
- **Xcode 工具**: `xcode-select --install`
- **Homebrew 问题**: 重新安装 Homebrew
- **M1/M2 芯片**: 使用 ARM64 版本的 Miniconda

## ✅ 安装验证

### 完整测试脚本
```bash
#!/bin/bash
echo "=== RL-Swarm 环境验证 ==="

# 检查 conda
if command -v conda &> /dev/null; then
    echo "✅ Conda 已安装: $(conda --version)"
else
    echo "❌ Conda 未找到"
    exit 1
fi

# 检查环境
if conda env list | grep -q rl-swarm; then
    echo "✅ rl-swarm 环境存在"
else
    echo "❌ rl-swarm 环境不存在"
    exit 1
fi

# 激活环境并测试
source ~/miniconda3/bin/activate rl-swarm

# 测试 Python 包
python -c "
import sys
print(f'✅ Python: {sys.version}')

try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
    print(f'✅ CUDA 可用: {torch.cuda.is_available()}')
    if hasattr(torch.backends, 'mps'):
        print(f'✅ MPS 可用: {torch.backends.mps.is_available()}')
except ImportError as e:
    print(f'❌ PyTorch 导入失败: {e}')

try:
    import transformers
    print(f'✅ Transformers: {transformers.__version__}')
except ImportError as e:
    print(f'❌ Transformers 导入失败: {e}')

try:
    import datasets
    print(f'✅ Datasets: {datasets.__version__}')
except ImportError as e:
    print(f'❌ Datasets 导入失败: {e}')
"

echo "=== 验证完成 ==="
```

## 🚀 启动项目

### 标准启动
```bash
conda activate rl-swarm
./run_rl_swarm_fixed.sh
```

### 调试模式
```bash
conda activate rl-swarm
export DEBUG=1
./run_rl_swarm_fixed.sh
```

### 自定义配置
```bash
conda activate rl-swarm
export MODEL_NAME="your-model"
export BATCH_SIZE=16
./run_rl_swarm_fixed.sh
```

---

## 📞 获取帮助

如果遇到问题：

1. 查看 [Issues](../../issues) 页面
2. 检查日志文件：`logs/swarm.log`
3. 运行诊断脚本验证环境
4. 提交新的 Issue 并包含：
   - 操作系统信息
   - 错误日志
   - 环境配置详情

**祝您使用愉快！** 🎉

