#!/usr/bin/env python3
"""
将二进制文件转换为16进制文本格式
支持指定每行输出的字节宽度
"""

import argparse
import sys


def bin_to_hex(input_file: str, bytes_per_line: int = 16, uppercase: bool = True) -> str:
    """
    将二进制文件转换为16进制字符串

    Args:
        input_file: 输入的二进制文件路径
        bytes_per_line: 每行输出的字节数
        uppercase: 是否使用大写字母输出16进制

    Returns:
        16进制文本内容
    """
    with open(input_file, 'rb') as f:
        data = f.read()

    hex_chars = '0123456789ABCDEF' if uppercase else '0123456789abcdef'
    lines = []

    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        hex_str = ''.join(hex_chars[b // 16] + hex_chars[b % 16] for b in chunk)
        lines.append(hex_str)

    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='将二进制文件转换为16进制文本格式',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  python bin2hex.py input.bin              # 默认每行16字节
  python bin2hex.py input.bin -w 8        # 每行8字节
  python bin2hex.py input.bin -w 32 -o output.hex  # 输出到文件
  python bin2hex.py input.bin -l          # 使用小写hex
  python bin2hex.py input.bin -r          # 反转每行字节顺序
  python bin2hex.py input.bin -swp        # 每两个字节交换顺序
        '''
    )
    parser.add_argument('input', help='输入的二进制文件路径')
    parser.add_argument('-w', '--width', type=int, default=16,
                        help='每行输出的字节数 (默认: 16)')
    parser.add_argument('-o', '--output', help='输出文件路径 (默认: stdout)')
    parser.add_argument('-l', '--lowercase', action='store_true',
                        help='使用小写字母输出16进制')
    parser.add_argument('-s', '--separator', default='',
                        help='字节之间的分隔符 (默认: 无)')
    parser.add_argument('--no-offset', action='store_true',
                        help='不显示偏移量')
    parser.add_argument('-r', '--reverse', action='store_true',
                        help='反转每行字节顺序')
    parser.add_argument('-swp', '--swap-endian', action='store_true',
                        help='每两个字节交换顺序')

    args = parser.parse_args()

    if args.width <= 0:
        parser.error('width 必须大于 0')

    # 读取并转换
    with open(args.input, 'rb') as f:
        data = f.read()

    hex_chars = '0123456789ABCDEF' if not args.lowercase else '0123456789abcdef'
    lines = []

    for i in range(0, len(data), args.width):
        chunk = data[i:i + args.width]

        if args.swap_endian:
            chunk_bytes = bytearray(chunk)
            for j in range(0, len(chunk_bytes) - 1, 2):
                chunk_bytes[j], chunk_bytes[j + 1] = chunk_bytes[j + 1], chunk_bytes[j]
            chunk = bytes(chunk_bytes)

        # 如果需要反转字节顺序
        if args.reverse:
            chunk = chunk[::-1]

        if args.separator:
            hex_str = args.separator.join(
                hex_chars[b // 16] + hex_chars[b % 16] for b in chunk
            )
        else:
            hex_str = ''.join(hex_chars[b // 16] + hex_chars[b % 16] for b in chunk)

        if args.no_offset:
            lines.append(hex_str)
        else:
            offset = f'{i:08X}'
            lines.append(f'{offset}  {hex_str}')

    result = '\n'.join(lines)

    # 输出
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(result)
        print(f'已保存到: {args.output}')
    else:
        print(result)


if __name__ == '__main__':
    main()
