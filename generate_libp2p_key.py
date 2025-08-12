#!/usr/bin/env python3
"""
生成libp2p protobuf格式的私钥文件
用于解决Hivemind DHT的DecodeError问题
"""

import os
import sys
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

def generate_libp2p_private_key(output_path):
    """生成libp2p格式的私钥文件"""
    try:
        print(f"正在生成libp2p私钥文件: {output_path}")
        
        # 生成RSA私钥
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend()
        )
        
        # 根据libp2p规范，RSA私钥使用DER编码
        # Go语言的libp2p使用ParsePKCS1PrivateKey，需要PKCS#1格式而不是PKCS#8
        private_key_der = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.TraditionalOpenSSL,  # 这会生成PKCS#1格式
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
        print(f"   - 编码格式: PKCS#1 DER (Go libp2p标准)")
        print(f"   - 文件格式: protobuf二进制")
        print(f"   - 文件权限: 600")
        print(f"   - 文件大小: {len(protobuf_data)} 字节")
        
        return True
        
    except Exception as e:
        print(f"❌ 生成libp2p私钥文件失败: {e}")
        return False

def main():
    """主函数"""
    if len(sys.argv) != 2:
        print("用法: python3 generate_libp2p_key.py <输出文件路径>")
        print("示例: python3 generate_libp2p_key.py ./swarm.pem")
        sys.exit(1)
    
    output_path = sys.argv[1]
    
    # 如果文件已存在，询问是否覆盖
    if os.path.exists(output_path):
        response = input(f"文件 {output_path} 已存在，是否覆盖？(y/N): ")
        if response.lower() not in ['y', 'yes']:
            print("操作已取消")
            sys.exit(0)
    
    success = generate_libp2p_private_key(output_path)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()