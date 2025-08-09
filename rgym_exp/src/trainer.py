from typing import Any, List

import requests
import torch
import torch.utils.data
from genrl.data import DataManager
from genrl.logging_utils.global_defs import get_logger
from genrl.logging_utils.ml_logger import LoggerMixin
from genrl.rewards import RewardManager
from genrl.state import GameState
from genrl.trainer.grpo_trainer import GRPOLanguageTrainerModule
from reasoning_gym.utils import SYSTEM_PROMPTS

# 导入并应用tokenizer补丁
from .tokenizer_patch import apply_comprehensive_tokenizer_patch
apply_comprehensive_tokenizer_patch()


class GRPOTrainerModule(GRPOLanguageTrainerModule, LoggerMixin):
    """
    Trainer for the Group Relative Policy Optimization (GRPO) method.
    Implements the TrainerModule interface defined in base_trainer.py.
    """

    def __init__(self, models: List[Any], **kwargs):
        """
        Initialize the GRPO trainer module.

        Args:
            models: List containing the model to be trained.
            **kwargs: Additional arguments for configuration.
        """
        # 在调用super().__init__之前先设置tokenizer配置
        self.judge_base_url = kwargs.get("judge_base_url", None)
        
        super().__init__(models, **kwargs)
        
        # 修复tokenizer的padding token和相关配置问题
        self._fix_tokenizer_config()
    
    def _fix_tokenizer_config(self):
        """修复tokenizer配置的辅助方法"""
        # 检查processing_class属性
        if hasattr(self, 'processing_class') and self.processing_class is not None:
            if hasattr(self.processing_class, 'pad_token') and self.processing_class.pad_token is None:
                self.processing_class.pad_token = self.processing_class.eos_token
                get_logger().info("Set processing_class pad_token to eos_token")
            
            # 为decoder-only模型设置左填充
            if hasattr(self.processing_class, 'padding_side'):
                self.processing_class.padding_side = 'left'
                get_logger().info("Set processing_class padding_side to 'left'")
            
            # 确保pad_token_id正确设置
            if hasattr(self.processing_class, 'pad_token_id') and self.processing_class.pad_token_id is None:
                self.processing_class.pad_token_id = self.processing_class.eos_token_id
                get_logger().info("Set processing_class pad_token_id to eos_token_id")
        
        # 检查tokenizer属性
        if hasattr(self, 'tokenizer') and self.tokenizer is not None:
            if hasattr(self.tokenizer, 'pad_token') and self.tokenizer.pad_token is None:
                self.tokenizer.pad_token = self.tokenizer.eos_token
                get_logger().info("Set tokenizer.pad_token to eos_token")
            
            if hasattr(self.tokenizer, 'padding_side'):
                self.tokenizer.padding_side = 'left'
                get_logger().info("Set tokenizer.padding_side to 'left'")
            
            if hasattr(self.tokenizer, 'pad_token_id') and self.tokenizer.pad_token_id is None:
                self.tokenizer.pad_token_id = self.tokenizer.eos_token_id
                get_logger().info("Set tokenizer.pad_token_id to eos_token_id")
        
        # 检查trainer中的tokenizer（如果存在）
        if hasattr(self, 'trainer') and hasattr(self.trainer, 'tokenizer') and self.trainer.tokenizer is not None:
            if hasattr(self.trainer.tokenizer, 'pad_token') and self.trainer.tokenizer.pad_token is None:
                self.trainer.tokenizer.pad_token = self.trainer.tokenizer.eos_token
                get_logger().info("Set trainer.tokenizer.pad_token to eos_token")
            
            if hasattr(self.trainer.tokenizer, 'padding_side'):
                self.trainer.tokenizer.padding_side = 'left'
                get_logger().info("Set trainer.tokenizer.padding_side to 'left'")
            
            if hasattr(self.trainer.tokenizer, 'pad_token_id') and self.trainer.tokenizer.pad_token_id is None:
                self.trainer.tokenizer.pad_token_id = self.trainer.tokenizer.eos_token_id
                get_logger().info("Set trainer.tokenizer.pad_token_id to eos_token_id")
        
        # 检查模型的tokenizer（如果存在）
        if hasattr(self, 'model') and hasattr(self.model, 'tokenizer') and self.model.tokenizer is not None:
            if hasattr(self.model.tokenizer, 'pad_token') and self.model.tokenizer.pad_token is None:
                self.model.tokenizer.pad_token = self.model.tokenizer.eos_token
                get_logger().info("Set model.tokenizer.pad_token to eos_token")
            
            if hasattr(self.model.tokenizer, 'padding_side'):
                self.model.tokenizer.padding_side = 'left'
                get_logger().info("Set model.tokenizer.padding_side to 'left'")
            
            if hasattr(self.model.tokenizer, 'pad_token_id') and self.model.tokenizer.pad_token_id is None:
                self.model.tokenizer.pad_token_id = self.model.tokenizer.eos_token_id
                get_logger().info("Set model.tokenizer.pad_token_id to eos_token_id")

    def _force_left_padding(self):
        """强制设置所有tokenizer为左填充"""
        tokenizers_to_fix = []
        
        # 收集所有可能的tokenizer引用
        if hasattr(self, 'processing_class') and self.processing_class is not None:
            tokenizers_to_fix.append(('processing_class', self.processing_class))
        if hasattr(self, 'tokenizer') and self.tokenizer is not None:
            tokenizers_to_fix.append(('tokenizer', self.tokenizer))
        if hasattr(self, 'trainer') and hasattr(self.trainer, 'tokenizer') and self.trainer.tokenizer is not None:
            tokenizers_to_fix.append(('trainer.tokenizer', self.trainer.tokenizer))
        if hasattr(self, 'model') and hasattr(self.model, 'tokenizer') and self.model.tokenizer is not None:
            tokenizers_to_fix.append(('model.tokenizer', self.model.tokenizer))
        
        # 强制设置所有tokenizer为左填充
        for name, tokenizer in tokenizers_to_fix:
            if hasattr(tokenizer, 'padding_side'):
                tokenizer.padding_side = 'left'
                get_logger().debug(f"Forced {name}.padding_side = 'left'")
            if hasattr(tokenizer, 'pad_token_id') and tokenizer.pad_token_id is None:
                tokenizer.pad_token_id = tokenizer.eos_token_id
                get_logger().debug(f"Set {name}.pad_token_id = eos_token_id")

    @torch.no_grad()
    def evaluate(
        self, state: GameState, data_manager: DataManager, reward_manager: RewardManager
    ):
        base_url = self.judge_base_url
        if base_url:
            try:
                model_name = self.model.name_or_path
            except AttributeError:
                model_name = "none"

            try:
                request_data = {
                    "user_id": state.peer_id,
                    "round_number": state.round,
                    "model_name": model_name,
                }
                response = requests.post(
                    f"{base_url}/request-question/", json=request_data
                )

                if response.status_code == 200:
                    result = response.json()
                    get_logger().debug(f'recieved question: {result["question"]}')
                else:
                    get_logger().debug(
                        f"Failed to recieve question: {response.status_code}"
                    )
                    return

                prompt = [
                    {"role": "system", "content": SYSTEM_PROMPTS["default"]},
                    {"role": "user", "content": result["question"]},
                ]
                
                # 在生成前强制设置所有tokenizer为左填充
                self._force_left_padding()
                
                input_ids = self.processing_class.apply_chat_template(
                    prompt,
                    tokenize=True,
                    add_generation_prompt=True,
                    return_tensors="pt",
                )
                input_ids = input_ids.to(self.model.device)
                
                # 再次确保在生成前tokenizer配置正确
                self._force_left_padding()
                
                outputs = self.model.generate(input_ids, max_new_tokens=512)
                answer = self.processing_class.decode(
                    outputs[0], skip_special_tokens=True
                )
                session_id = result["session_id"]
                submission_data = {
                    "session_id": session_id,
                    "round_number": state.round,
                    "user_answer": answer,
                }
                response = requests.post(
                    f"{base_url}/submit-answer/", json=submission_data
                )

                if response.status_code == 200:
                    result = response.json()
                    get_logger().debug(f"Score: {result['score']}")
                    return
                else:
                    get_logger().debug(
                        f"Failed to submit answer: {response.status_code}"
                    )
                    return
            except Exception as e:
                get_logger().debug(f"Failed to evaluate: {e}")
                return
        else:
            return
