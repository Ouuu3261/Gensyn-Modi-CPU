"""
修复BF16问题的Trainer模块
"""

import torch
import os
from genrl.trainer.grpo_trainer import GRPOLanguageTrainerModule

# 设置环境变量
os.environ['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'
os.environ['PYTORCH_MPS_HIGH_WATERMARK_RATIO'] = '0.0'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

class GRPOTrainerModule(GRPOLanguageTrainerModule):
    """修复BF16问题的GRPO Trainer"""
    
    def __init__(self, *args, **kwargs):
        # 确保禁用BF16相关设置
        if 'config' in kwargs:
            config = kwargs['config']
            if hasattr(config, 'fp16'):
                config.fp16 = False
            if hasattr(config, 'bf16'):
                config.bf16 = False
            if hasattr(config, 'dataloader_pin_memory'):
                config.dataloader_pin_memory = False
        
        super().__init__(*args, **kwargs)
    
    def _setup_model(self, model):
        """确保模型使用float32数据类型"""
        if model is not None:
            # 强制转换为float32
            model = model.float()
            
            # 确保所有参数都是float32
            for param in model.parameters():
                if param.dtype != torch.float32:
                    param.data = param.data.float()
        
        return super()._setup_model(model)
