#!/usr/bin/env python3
"""
生成libp2p protobuf格式的私钥文件
用于解决Hivemind DHT的DecodeError问题
支持根据操作系统自动选择PKCS#1或PKCS#8格式
"""

import os
import sys
import platform
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

# libp2p protobuf定义
class PrivateKeyProtobuf:
    """简化的libp2p PrivateKey protobuf实现"""
    
    # KeyType枚举
    RSA = 0
    Ed25519 = 1
    Secp256k1 = 2
    ECDSA = 3
    
    def __init__(self, key_type, data):
        self.key_type = key_type
        self.data = data
    
    def serialize_to_string(self):
        """序列化为protobuf二进制格式"""
        # 简化的protobuf编码
        # Tag 1 (key_type): varint
        # Tag 2 (data): length-delimited
        
        result = bytearray()
        
        # Field 1: key_type (varint)
        result.extend(self._encode_varint(1 << 3 | 0))  # tag 1, wire type 0 (varint)
        result.extend(self._encode_varint(self.key_type))
        
        # Field 2: data (length-delimited)
        result.extend(self._encode_varint(2 << 3 | 2))  # tag 2, wire type 2 (length-delimited)
        result.extend(self._encode_varint(len(self.data)))
        result.extend(self.data)
        
        return bytes(result)
    
    def _encode_varint(self, value):
        """编码varint"""
        result = bytearray()
        while value >= 0x80:
            result.append((value & 0x7F) | 0x80)
            value >>= 7
        result.append(value & 0x7F)
        return result

def generate_libp2p_private_key(output_path, force_format=None):
    """生成libp2p格式的私钥文件"""
    try:
        print(f"正在生成libp2p私钥文件: {output_path}")
        
        # 检测操作系统并选择合适的私钥格式
        system = platform.system().lower()
        
        if force_format:
            use_pkcs8 = force_format.lower() == 'pkcs8'
            format_name = force_format.upper()
        elif system == 'darwin':  # macOS
            use_pkcs8 = False
            format_name = 'PKCS#1'
        elif system == 'linux':  # Ubuntu/Linux
            use_pkcs8 = True
            format_name = 'PKCS#8'
        else:
            # 默认使用PKCS#8格式
            use_pkcs8 = True
            format_name = 'PKCS#8'
        
        print(f"检测到操作系统: {system}")
        print(f"使用私钥格式: {format_name}")
        
        # 生成RSA私钥
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend()
        )
        
        # 根据选择的格式生成DER编码的私钥
        if use_pkcs8:
            # PKCS#8格式 - Ubuntu/Linux libp2p期望的格式
            private_key_der = private_key.private_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
        else:
            # PKCS#1格式 - macOS libp2p期望的格式
            private_key_der = private_key.private_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            )
        
        # 创建libp2p protobuf私钥
        libp2p_private_key = PrivateKeyProtobuf(
            key_type=PrivateKeyProtobuf.RSA,
            data=private_key_der
        )
        
        # 序列化为protobuf二进制格式
        protobuf_data = libp2p_private_key.serialize_to_string()
        
        # 确保目录存在
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # 写入文件
        with open(output_path, 'wb') as f:
            f.write(protobuf_data)
        
        # 设置正确的权限
        os.chmod(output_path, 0o600)
        
        print(f"✅ libp2p私钥文件已生成: {output_path}")
        print(f"   - 密钥类型: RSA 2048位")
        print(f"   - 编码格式: {format_name} DER")
        print(f"   - 文件格式: protobuf二进制")
        print(f"   - 文件权限: 600")
        print(f"   - 文件大小: {len(protobuf_data)} 字节")
        print(f"   - 操作系统: {system}")
        if force_format:
            print(f"   - 强制格式: {force_format.upper()}")
        
        return True
        
    except Exception as e:
        print(f"❌ 生成libp2p私钥文件失败: {e}")
        return False

def main():
    """主函数"""
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("用法: python3 generate_libp2p_key.py <输出文件路径> [格式]")
        print("示例: python3 generate_libp2p_key.py ./swarm.pem")
        print("      python3 generate_libp2p_key.py ./swarm.pem pkcs1")
        print("      python3 generate_libp2p_key.py ./swarm.pem pkcs8")
        print("")
        print("格式说明:")
        print("  pkcs1 - PKCS#1格式 (macOS libp2p)")
        print("  pkcs8 - PKCS#8格式 (Ubuntu/Linux libp2p)")
        print("  不指定格式时会根据操作系统自动选择")
        sys.exit(1)
    
    output_path = sys.argv[1]
    force_format = sys.argv[2] if len(sys.argv) == 3 else None
    
    # 验证格式参数
    if force_format and force_format.lower() not in ['pkcs1', 'pkcs8']:
        print(f"❌ 无效的格式参数: {force_format}")
        print("支持的格式: pkcs1, pkcs8")
        sys.exit(1)
    
    # 如果文件已存在，询问是否覆盖
    if os.path.exists(output_path):
        response = input(f"文件 {output_path} 已存在，是否覆盖？(y/N): ")
        if response.lower() not in ['y', 'yes']:
            print("操作已取消")
            sys.exit(0)
    
    success = generate_libp2p_private_key(output_path, force_format)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()