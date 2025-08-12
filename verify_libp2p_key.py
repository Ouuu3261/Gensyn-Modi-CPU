#!/usr/bin/env python3
"""
验证libp2p protobuf格式私钥文件
"""

import sys
import os

def parse_varint(data, offset):
    """解析varint"""
    result = 0
    shift = 0
    while offset < len(data):
        byte = data[offset]
        offset += 1
        result |= (byte & 0x7F) << shift
        if (byte & 0x80) == 0:
            break
        shift += 7
    return result, offset

def verify_libp2p_key(file_path):
    """验证libp2p私钥文件格式"""
    try:
        with open(file_path, 'rb') as f:
            data = f.read()
        
        print(f"验证文件: {file_path}")
        print(f"文件大小: {len(data)} 字节")
        
        offset = 0
        
        # 解析第一个字段 (key_type)
        if offset >= len(data):
            print("❌ 文件太短，无法解析")
            return False
            
        tag_and_type, offset = parse_varint(data, offset)
        field_number = tag_and_type >> 3
        wire_type = tag_and_type & 0x7
        
        print(f"字段1 - 标签: {field_number}, 线路类型: {wire_type}")
        
        if field_number != 1 or wire_type != 0:
            print(f"❌ 期望字段1为key_type (标签1, 线路类型0), 实际: 标签{field_number}, 线路类型{wire_type}")
            return False
            
        key_type, offset = parse_varint(data, offset)
        print(f"密钥类型: {key_type} ({'RSA' if key_type == 0 else 'Ed25519' if key_type == 1 else '未知'})")
        
        # 解析第二个字段 (data)
        if offset >= len(data):
            print("❌ 缺少数据字段")
            return False
            
        tag_and_type, offset = parse_varint(data, offset)
        field_number = tag_and_type >> 3
        wire_type = tag_and_type & 0x7
        
        print(f"字段2 - 标签: {field_number}, 线路类型: {wire_type}")
        
        if field_number != 2 or wire_type != 2:
            print(f"❌ 期望字段2为data (标签2, 线路类型2), 实际: 标签{field_number}, 线路类型{wire_type}")
            return False
            
        data_length, offset = parse_varint(data, offset)
        print(f"数据长度: {data_length} 字节")
        
        if offset + data_length != len(data):
            print(f"❌ 数据长度不匹配，期望: {data_length}, 实际剩余: {len(data) - offset}")
            return False
            
        # 检查私钥数据是否为有效的DER格式
        private_key_data = data[offset:offset + data_length]
        
        # DER编码的私钥应该以0x30开头（SEQUENCE）
        if len(private_key_data) > 0 and private_key_data[0] == 0x30:
            print("✅ 私钥数据格式正确 (DER编码)")
        else:
            print(f"⚠️  私钥数据可能不是标准DER格式，开头字节: 0x{private_key_data[0]:02x}")
        
        print("✅ libp2p protobuf格式验证通过")
        return True
        
    except Exception as e:
        print(f"❌ 验证失败: {e}")
        return False

def main():
    if len(sys.argv) != 2:
        print("用法: python3 verify_libp2p_key.py <私钥文件路径>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not os.path.exists(file_path):
        print(f"❌ 文件不存在: {file_path}")
        sys.exit(1)
    
    success = verify_libp2p_key(file_path)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()