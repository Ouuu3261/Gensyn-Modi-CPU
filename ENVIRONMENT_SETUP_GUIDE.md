# RL-Swarm 环境设置指南

## 概述
本指南提供了在不同操作系统上设置 RL-Swarm 项目运行环境的详细说明。我们提供了自动化脚本来简化安装过程。

## 支持的操作系统
- **Ubuntu/Linux**: 自动安装 Miniconda 并创建虚拟环境
- **macOS**: 在已有 Anaconda 基础上创建虚拟环境

## 快速开始

### Ubuntu/Linux 系统

#### 1. 运行自动安装脚本
```bash
# 下载项目后，在项目根目录运行
./setup_ubuntu_miniconda.sh
```

#### 2. 脚本功能
- ✅ 自动检测系统类型
- ✅ 更新系统包管理器
- ✅ 安装系统依赖 (git, curl, build-essential 等)
- ✅ 下载并安装 Miniconda
- ✅ 配置 conda 环境
- ✅ 创建 `rl-swarm` 虚拟环境
- ✅ 安装所有 Python 依赖
- ✅ 安装 Node.js 和 Yarn
- ✅ 创建环境激活脚本

#### 3. 安装后操作
```bash
# 重新加载 shell 配置
source ~/.bashrc

# 激活环境
conda activate rl-swarm

# 或使用快捷脚本
./activate_rl_swarm.sh

# 运行项目
./run_rl_swarm_fixed.sh
```

### macOS 系统

#### 1. 前置要求
- 手动安装 Anaconda 或 Miniconda
- 推荐通过官网或 Homebrew 安装

```bash
# 通过 Homebrew 安装 Anaconda (可选)
brew install --cask anaconda

# 或下载官方安装包
# https://www.anaconda.com/products/distribution
```

#### 2. 运行环境设置脚本
```bash
# 在项目根目录运行
./setup_macos_conda.sh
```

#### 3. 脚本功能
- ✅ 检测 conda 安装状态
- ✅ 安装/更新系统工具 (通过 Homebrew)
- ✅ 配置 conda 环境
- ✅ 创建 `rl-swarm` 虚拟环境
- ✅ 针对 Apple Silicon (M1/M2) 优化 PyTorch 安装
- ✅ 安装所有 Python 依赖
- ✅ 创建环境激活脚本

#### 4. 安装后操作
```bash
# 激活环境
conda activate rl-swarm

# 或使用快捷脚本
./activate_rl_swarm.sh

# 运行项目
./run_rl_swarm_fixed.sh
```

## 依赖包详情

### 核心依赖
- **PyTorch**: 深度学习框架
- **Transformers**: Hugging Face 模型库
- **Datasets**: 数据集处理
- **Accelerate**: 分布式训练加速
- **TRL**: 强化学习训练库

### 分布式训练
- **Hivemind**: 去中心化分布式训练

### Web 服务
- **FastAPI**: Web API 框架
- **Uvicorn**: ASGI 服务器

### 区块链集成
- **Web3**: 以太坊交互
- **eth-account**: 以太坊账户管理

### 完整依赖列表
参见 <mcfile name="requirements_rl_swarm.txt" path="/Users/oushin/Desktop/数字农民工会/Gensyn/rl-swarm/requirements_rl_swarm.txt"></mcfile>

## 环境配置

### Python 版本
- **推荐**: Python 3.11
- **最低**: Python 3.9

### 硬件要求
- **内存**: 最少 8GB，推荐 16GB+
- **存储**: 至少 10GB 可用空间
- **网络**: 稳定的互联网连接（用于下载模型）

### 特殊配置

#### Apple Silicon (M1/M2) 优化
- 自动检测处理器类型
- 安装支持 MPS 加速的 PyTorch 版本
- 优化的依赖包版本

#### Ubuntu/Linux 优化
- CPU 版本的 PyTorch（兼容性最佳）
- 通过 APT 包管理器安装系统依赖
- 自动配置 Node.js 和 Yarn

## 故障排除

### 常见问题

#### 1. conda 命令未找到
```bash
# Ubuntu: 重新加载 shell 配置
source ~/.bashrc

# macOS: 检查 Anaconda 安装
echo $PATH | grep conda
```

#### 2. 权限错误
```bash
# 确保脚本有执行权限
chmod +x setup_ubuntu_miniconda.sh
chmod +x setup_macos_conda.sh
```

#### 3. 网络连接问题
```bash
# 配置 conda 镜像源（中国用户）
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
```

#### 4. 依赖安装失败
```bash
# 手动安装依赖
pip install -r requirements_rl_swarm.txt

# 或分批安装
pip install torch torchvision torchaudio
pip install transformers datasets accelerate
```

### 环境重置

#### 删除并重新创建环境
```bash
# 删除现有环境
conda env remove -n rl-swarm

# 重新运行安装脚本
./setup_ubuntu_miniconda.sh  # Ubuntu
./setup_macos_conda.sh       # macOS
```

## 验证安装

### 检查核心组件
```bash
# 激活环境
conda activate rl-swarm

# 验证 Python 包
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import transformers; print(f'Transformers: {transformers.__version__}')"
python -c "import hivemind; print(f'Hivemind: {hivemind.__version__}')"

# 检查 GPU/MPS 支持 (如适用)
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
python -c "import torch; print(f'MPS: {torch.backends.mps.is_available()}')"  # macOS only
```

### 测试项目启动
```bash
# 运行项目（测试模式）
./run_rl_swarm_fixed.sh
```

## 更新和维护

### 更新依赖
```bash
# 激活环境
conda activate rl-swarm

# 更新所有包
conda update --all

# 或更新特定包
pip install --upgrade transformers datasets
```

### 环境备份
```bash
# 导出环境配置
conda env export -n rl-swarm > rl_swarm_environment.yml

# 从备份恢复
conda env create -f rl_swarm_environment.yml
```

## 详细使用方法

### 完整部署流程

#### 1. 获取项目代码
```bash
# 克隆项目
git clone <repository-url>
cd rl-swarm
```

#### 2. 环境安装

**Ubuntu/Linux 系统**:
```bash
# 运行自动安装脚本
./setup_ubuntu_miniconda.sh

# 等待安装完成后，重新加载shell配置
source ~/.bashrc

# 验证安装
conda activate rl-swarm
python -c "import torch, transformers, hivemind; print('✅ 环境安装成功')"
```

**macOS 系统**:
```bash
# 确保已安装 Anaconda，然后运行
./setup_macos_conda.sh

# 验证安装
conda activate rl-swarm
python -c "import torch, transformers, hivemind; print('✅ 环境安装成功')"
```

#### 3. 项目配置

**设置环境变量**:
```bash
# 激活conda环境
conda activate rl-swarm

# 设置Hugging Face缓存目录（可选）
export TRANSFORMERS_CACHE="$PWD/.cache/huggingface"
export HF_HOME="$PWD/.cache/huggingface"
export HUGGINGFACE_HUB_CACHE="$PWD/.cache/huggingface/hub"

# 设置测试网连接（根据需要）
export CONNECT_TO_TESTNET=true
export SWARM_CONTRACT="your_contract_address"
```

**检查配置文件**:
```bash
# 确保配置文件存在
ls -la configs/
# 应该看到: rg-swarm-final-fix.yaml
```

#### 4. 启动项目

**标准启动**:
```bash
# 激活环境
conda activate rl-swarm

# 启动项目
./run_rl_swarm_fixed.sh
```

**后台启动**:
```bash
# 使用nohup在后台运行
nohup ./run_rl_swarm_fixed.sh > rl_swarm.log 2>&1 &

# 查看日志
tail -f rl_swarm.log
```

#### 5. 验证运行状态

**检查进程**:
```bash
# 查看相关进程
ps aux | grep -E "(yarn|swarm_launcher|rgym_exp)"

# 查看端口占用
lsof -i :3000  # 前端服务
lsof -i :8000  # API服务
```

**检查日志**:
```bash
# 查看主要日志
tail -f logs/swarm_launcher.log

# 查看前端日志
tail -f logs/yarn.log

# 查看训练日志
ls logs/training_*
```

#### 6. 停止项目
```bash
# 使用Ctrl+C停止（推荐）
# 或发送SIGTERM信号
pkill -f "swarm_launcher"
pkill -f "yarn start"
```

### 批量部署指南

#### 1. 准备部署脚本
```bash
#!/bin/bash
# deploy_rl_swarm.sh - 批量部署脚本

DEPLOY_DIR="/opt/rl-swarm"
REPO_URL="your_github_repo_url"

# 创建部署目录
sudo mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# 克隆项目
git clone $REPO_URL .

# 根据系统类型选择安装脚本
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ./setup_ubuntu_miniconda.sh
elif [[ "$OSTYPE" == "darwin"* ]]; then
    ./setup_macos_conda.sh
fi

# 启动服务
conda activate rl-swarm
./run_rl_swarm_fixed.sh
```

#### 2. 系统服务配置（Linux）
```bash
# 创建systemd服务文件
sudo tee /etc/systemd/system/rl-swarm.service << EOF
[Unit]
Description=RL-Swarm Service
After=network.target

[Service]
Type=simple
User=rl-swarm
WorkingDirectory=/opt/rl-swarm
Environment=PATH=/home/rl-swarm/miniconda3/envs/rl-swarm/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/opt/rl-swarm/run_rl_swarm_fixed.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl enable rl-swarm
sudo systemctl start rl-swarm
sudo systemctl status rl-swarm
```

#### 3. Docker部署（可选）
```bash
# 构建Docker镜像
docker build -t rl-swarm:latest .

# 运行容器
docker run -d \
  --name rl-swarm \
  -p 3000:3000 \
  -p 8000:8000 \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/outputs:/app/outputs \
  rl-swarm:latest
```

### 监控和维护

#### 1. 健康检查
```bash
# 检查服务状态
curl -f http://localhost:3000/health || echo "前端服务异常"
curl -f http://localhost:8000/health || echo "API服务异常"

# 检查GPU/CPU使用率
nvidia-smi  # 如果有GPU
htop        # CPU和内存使用情况
```

#### 2. 日志轮转
```bash
# 设置logrotate
sudo tee /etc/logrotate.d/rl-swarm << EOF
/opt/rl-swarm/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
```

#### 3. 自动更新脚本
```bash
#!/bin/bash
# update_rl_swarm.sh

cd /opt/rl-swarm

# 停止服务
sudo systemctl stop rl-swarm

# 更新代码
git pull origin main

# 更新依赖（如需要）
conda activate rl-swarm
pip install -r requirements_rl_swarm.txt

# 重启服务
sudo systemctl start rl-swarm
```

## 支持和帮助

### 文档资源
- <mcfile name="README.md" path="/Users/oushin/Desktop/数字农民工会/Gensyn/rl-swarm/README.md"></mcfile>: 项目主要文档
- <mcfile name="TODO_CROSS_PLATFORM.md" path="/Users/oushin/Desktop/数字农民工会/Gensyn/rl-swarm/TODO_CROSS_PLATFORM.md"></mcfile>: 跨平台兼容性说明

### 脚本文件
- <mcfile name="setup_ubuntu_miniconda.sh" path="/Users/oushin/Desktop/数字农民工会/Gensyn/rl-swarm/setup_ubuntu_miniconda.sh"></mcfile>: Ubuntu 自动安装脚本
- <mcfile name="setup_macos_conda.sh" path="/Users/oushin/Desktop/数字农民工会/Gensyn/rl-swarm/setup_macos_conda.sh"></mcfile>: macOS 环境设置脚本
- <mcfile name="activate_rl_swarm.sh" path="/Users/oushin/Desktop/数字农民工会/Gensyn/rl-swarm/activate_rl_swarm.sh"></mcfile>: 环境激活快捷脚本（安装后生成）

### 快速命令参考
```bash
# 环境管理
conda activate rl-swarm              # 激活环境
conda deactivate                     # 退出环境
conda env list                       # 查看所有环境

# 项目操作
./run_rl_swarm_fixed.sh             # 启动项目
pkill -f swarm_launcher              # 停止项目
tail -f logs/swarm_launcher.log      # 查看日志

# 系统监控
htop                                 # 系统资源监控
lsof -i :3000                       # 检查端口占用
ps aux | grep swarm                  # 查看相关进程
```

---

**注意**: 这些脚本会自动处理大部分配置，但在某些特殊环境下可能需要手动调整。如遇问题，请参考故障排除部分或查看相关日志文件。批量部署时建议先在测试环境验证完整流程。