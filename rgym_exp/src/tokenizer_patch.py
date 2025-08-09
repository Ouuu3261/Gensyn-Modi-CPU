"""
Comprehensive monkey patch for TRL GRPO trainer to force left padding
"""
import functools
import warnings
from transformers import PreTrainedTokenizer, PreTrainedTokenizerFast
from genrl.logging_utils.global_defs import get_logger

# 保存原始方法
_original_tokenizer_call = None
_original_tokenizer_pad = None
_original_generation_utils_prepare_inputs_for_generation = None

def patched_tokenizer_call(self, *args, **kwargs):
    """修补后的tokenizer调用，强制使用左填充"""
    # 强制设置左填充
    if hasattr(self, 'padding_side'):
        self.padding_side = 'left'
    
    # 在kwargs中强制设置padding_side
    if 'padding_side' in kwargs:
        kwargs['padding_side'] = 'left'
    
    # 如果有padding参数，强制设置为left
    if 'padding' in kwargs and kwargs['padding'] is not False:
        kwargs['padding_side'] = 'left'
    
    # 对于batch处理，确保padding_side正确
    if len(args) > 0 and isinstance(args[0], (list, tuple)):
        kwargs['padding_side'] = 'left'
    
    return _original_tokenizer_call(self, *args, **kwargs)

def patched_tokenizer_pad(self, *args, **kwargs):
    """修补后的pad方法，强制使用左填充"""
    # 强制设置左填充
    if hasattr(self, 'padding_side'):
        self.padding_side = 'left'
    
    # 在kwargs中强制设置padding_side
    if 'padding_side' in kwargs:
        kwargs['padding_side'] = 'left'
    elif len(args) > 0 and isinstance(args[0], (list, dict)):
        # 如果第一个参数是要填充的数据，添加padding_side参数
        kwargs['padding_side'] = 'left'
    
    return _original_tokenizer_pad(self, *args, **kwargs)

def suppress_right_padding_warning(message, category, filename, lineno, file=None, line=None):
    """抑制右填充警告"""
    if "right-padding was detected" in str(message) or "padding_side='left'" in str(message):
        return  # 忽略这些警告
    # 显示其他警告
    warnings._showwarning_orig(message, category, filename, lineno, file, line)

def apply_comprehensive_tokenizer_patch():
    """应用全面的tokenizer补丁"""
    global _original_tokenizer_call, _original_tokenizer_pad
    
    if _original_tokenizer_call is None:
        # 保存原始方法
        _original_tokenizer_call = PreTrainedTokenizer.__call__
        _original_tokenizer_pad = PreTrainedTokenizer.pad
        
        # 应用补丁
        PreTrainedTokenizer.__call__ = patched_tokenizer_call
        PreTrainedTokenizerFast.__call__ = patched_tokenizer_call
        PreTrainedTokenizer.pad = patched_tokenizer_pad
        PreTrainedTokenizerFast.pad = patched_tokenizer_pad
        
        # 抑制右填充警告
        if not hasattr(warnings, '_showwarning_orig'):
            warnings._showwarning_orig = warnings.showwarning
        warnings.showwarning = suppress_right_padding_warning
        
        get_logger().info("Applied comprehensive tokenizer left-padding patch")

def remove_comprehensive_tokenizer_patch():
    """移除全面的tokenizer补丁"""
    global _original_tokenizer_call, _original_tokenizer_pad
    
    if _original_tokenizer_call is not None:
        PreTrainedTokenizer.__call__ = _original_tokenizer_call
        PreTrainedTokenizerFast.__call__ = _original_tokenizer_call
        PreTrainedTokenizer.pad = _original_tokenizer_pad
        PreTrainedTokenizerFast.pad = _original_tokenizer_pad
        
        # 恢复警告
        if hasattr(warnings, '_showwarning_orig'):
            warnings.showwarning = warnings._showwarning_orig
            delattr(warnings, '_showwarning_orig')
        
        _original_tokenizer_call = None
        _original_tokenizer_pad = None
        
        get_logger().info("Removed comprehensive tokenizer left-padding patch")

# 为了向后兼容，保留原来的函数名
apply_tokenizer_patch = apply_comprehensive_tokenizer_patch
remove_tokenizer_patch = remove_comprehensive_tokenizer_patch