#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
批量文件重命名工具
功能：批量重命名文件，支持多种重命名模式
使用方法：python3 batch-rename.py [目录] [模式] [选项]
"""

import os
import sys
import re
import argparse
import json
from pathlib import Path
import datetime
import unicodedata


class BatchRenamer:
    def __init__(self, directory, mode="prefix", dry_run=False, verbose=False):
        """
        初始化批量重命名器
        
        参数:
            directory: 目标目录
            mode: 重命名模式 (prefix, suffix, replace, sequence, timestamp)
            dry_run: 模拟运行，不实际操作
            verbose: 详细输出
        """
        self.directory = Path(directory).resolve()
        self.mode = mode
        self.dry_run = dry_run
        self.verbose = verbose
        self.renames = []
        self.errors = []
        self.log_file = f"rename-log-{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
    def log(self, message):
        """记录日志"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        
        if self.verbose:
            print(log_entry)
        
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
    
    def sanitize_filename(self, filename):
        """清理文件名，移除非法字符"""
        # 替换Windows非法字符
        illegal_chars = r'[<>:"/\\|?*]'
        filename = re.sub(illegal_chars, '_', filename)
        
        # 移除控制字符
        filename = ''.join(char for char in filename if unicodedata.category(char)[0] != 'C')
        
        # 限制长度
        if len(filename) > 255:
            name, ext = os.path.splitext(filename)
            max_name_length = 255 - len(ext)
            filename = name[:max_name_length] + ext
        
        return filename
    
    def add_prefix(self, prefix):
        """添加前缀"""
        self.log(f"添加前缀: {prefix}")
        
        for file_path in self.directory.iterdir():
            if file_path.is_file():
                old_name = file_path.name
                new_name = f"{prefix}{old_name}"
                new_name = self.sanitize_filename(new_name)
                new_path = file_path.parent / new_name
                
                if old_name != new_name:
                    self.renames.append((file_path, new_path, f"添加前缀 '{prefix}'"))
    
    def add_suffix(self, suffix, before_ext=True):
        """添加后缀"""
        suffix_text = f"添加后缀 '{suffix}' (扩展名前: {before_ext})"
        self.log(suffix_text)
        
        for file_path in self.directory.iterdir():
            if file_path.is_file():
                old_name = file_path.name
                name, ext = os.path.splitext(old_name)
                
                if before_ext:
                    new_name = f"{name}{suffix}{ext}"
                else:
                    new_name = f"{old_name}{suffix}"
                
                new_name = self.sanitize_filename(new_name)
                new_path = file_path.parent / new_name
                
                if old_name != new_name:
                    self.renames.append((file_path, new_path, f"添加后缀 '{suffix}'"))
    
    def replace_text(self, old_text, new_text, case_sensitive=True):
        """替换文本"""
        case_text = "区分大小写" if case_sensitive else "不区分大小写"
        self.log(f"替换文本: '{old_text}' -> '{new_text}' ({case_text})")
        
        flags = 0 if case_sensitive else re.IGNORECASE
        
        for file_path in self.directory.iterdir():
            if file_path.is_file():
                old_name = file_path.name
                new_name = re.sub(old_text, new_text, old_name, flags=flags)
                new_name = self.sanitize_filename(new_name)
                new_path = file_path.parent / new_name
                
                if old_name != new_name:
                    self.renames.append((file_path, new_path, f"替换 '{old_text}' -> '{new_text}'"))
    
    def sequence_rename(self, prefix="", start=1, digits=3, ext_filter=None):
        """序列重命名"""
        self.log(f"序列重命名: 前缀='{prefix}', 起始={start}, 位数={digits}")
        
        # 收集文件
        files = []
        for file_path in self.directory.iterdir():
            if file_path.is_file():
                if ext_filter is None or file_path.suffix.lower() == ext_filter.lower():
                    files.append(file_path)
        
        # 按名称排序
        files.sort(key=lambda x: x.name)
        
        # 重命名
        for i, file_path in enumerate(files):
            old_name = file_path.name
            ext = file_path.suffix
            sequence_num = start + i
            sequence_str = str(sequence_num).zfill(digits)
            
            new_name = f"{prefix}{sequence_str}{ext}"
            new_name = self.sanitize_filename(new_name)
            new_path = file_path.parent / new_name
            
            if old_name != new_name:
                self.renames.append((file_path, new_path, f"序列重命名 #{sequence_num}"))
    
    def timestamp_rename(self, format_type="datetime"):
        """时间戳重命名"""
        self.log(f"时间戳重命名: 格式={format_type}")
        
        for file_path in self.directory.iterdir():
            if file_path.is_file():
                old_name = file_path.name
                ext = file_path.suffix
                
                # 获取文件修改时间
                mtime = file_path.stat().st_mtime
                dt = datetime.datetime.fromtimestamp(mtime)
                
                if format_type == "datetime":
                    timestamp_str = dt.strftime("%Y%m%d_%H%M%S")
                elif format_type == "date":
                    timestamp_str = dt.strftime("%Y%m%d")
                elif format_type == "time":
                    timestamp_str = dt.strftime("%H%M%S")
                elif format_type == "iso":
                    timestamp_str = dt.isoformat().replace(':', '-')
                else:
                    timestamp_str = str(int(mtime))
                
                new_name = f"{timestamp_str}{ext}"
                new_name = self.sanitize_filename(new_name)
                new_path = file_path.parent / new_name
                
                if old_name != new_name:
                    self.renames.append((file_path, new_path, f"时间戳重命名 ({format_type})"))
    
    def case_convert(self, convert_type="lower"):
        """大小写转换"""
        self.log(f"大小写转换: {convert_type}")
        
        for file_path in self.directory.iterdir():
            if file_path.is_file():
                old_name = file_path.name
                
                if convert_type == "lower":
                    new_name = old_name.lower()
                elif convert_type == "upper":
                    new_name = old_name.upper()
                elif convert_type == "title":
                    new_name = old_name.title()
                elif convert_type == "sentence":
                    new_name = old_name.capitalize()
                else:
                    continue
                
                new_name = self.sanitize_filename(new_name)
                new_path = file_path.parent / new_name
                
                if old_name != new_name:
                    self.renames.append((file_path, new_path, f"大小写转换 ({convert_type})"))
    
    def execute_renames(self):
        """执行重命名操作"""
        if not self.renames:
            self.log("没有文件需要重命名")
            return
        
        self.log(f"开始执行 {len(self.renames)} 个重命名操作")
        
        # 检查冲突
        new_names = [str(rename[1]) for rename in self.renames]
        if len(new_names) != len(set(new_names)):
            self.log("警告: 检测到重命名冲突")
        
        # 执行重命名
        for old_path, new_path, reason in self.renames:
            try:
                if new_path.exists():
                    self.errors.append(f"目标文件已存在: {new_path}")
                    self.log(f"跳过 (目标已存在): {old_path} -> {new_path}")
                    continue
                
                if not self.dry_run:
                    old_path.rename(new_path)
                
                self.log(f"重命名: {old_path.name} -> {new_path.name} ({reason})")
                
            except Exception as e:
                error_msg = f"重命名失败 {old_path}: {str(e)}"
                self.errors.append(error_msg)
                self.log(error_msg)
        
        # 输出统计
        self.log("=" * 50)
        self.log("重命名统计:")
        self.log(f"  计划重命名: {len(self.renames)}")
        self.log(f"  成功重命名: {len(self.renames) - len(self.errors)}")
        self.log(f"  错误数量: {len(self.errors)}")
        self.log(f"  模拟运行: {self.dry_run}")
        
        if self.errors:
            self.log("错误详情:")
            for error in self.errors:
                self.log(f"  - {error}")
        
        self.log("=" * 50)
    
    def preview_renames(self):
        """预览重命名操作"""
        if not self.renames:
            print("没有文件需要重命名")
            return
        
        print(f"预览 {len(self.renames)} 个重命名操作:")
        print("-" * 80)
        print(f"{'原文件名':<40} {'新文件名':<40} {'原因'}")
        print("-" * 80)
        
        for old_path, new_path, reason in self.renames:
            old_name = old_path.name[:38] + ".." if len(old_path.name) > 40 else old_path.name
            new_name = new_path.name[:38] + ".." if len(new_path.name) > 40 else new_path.name
            print(f"{old_name:<40} {new_name:<40} {reason}")
        
        print("-" * 80)
        print(f"总计: {len(self.renames)} 个文件")
        
        if self.errors:
            print(f"警告: {len(self.errors)} 个潜在错误")
    
    def save_plan(self, file_path):
        """保存重命名计划"""
        plan = {
            "directory": str(self.directory),
            "mode": self.mode,
            "dry_run": self.dry_run,
            "timestamp": datetime.datetime.now().isoformat(),
            "renames": [
                {
                    "old_path": str(old_path),
                    "new_path": str(new_path),
                    "reason": reason
                }
                for old_path, new_path, reason in self.renames
            ],
            "errors": self.errors
        }
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(plan, f, indent=2, ensure_ascii=False)
            self.log(f"重命名计划已保存到: {file_path}")
        except Exception as e:
            self.log(f"保存计划失败: {str(e)}")


def main():
    parser = argparse.ArgumentParser(description="批量文件重命名工具")
    parser.add_argument("directory", help="目标目录")
    parser.add_argument("-m", "--mode", choices=["prefix", "suffix", "replace", "sequence", "timestamp", "case"],
                        default="prefix", help="重命名模式 (默认: prefix)")
    parser.add_argument("-d", "--dry-run", action="store_true", help="模拟运行，不实际操作")
    parser.add_argument("-v", "--verbose", action="store_true", help="详细输出")
    parser.add_argument("-p", "--preview", action="store_true", help="预览重命名操作")
    parser.add_argument("--save-plan", help="保存重命名计划到文件")
    
    # 前缀模式参数
    parser.add_argument("--prefix", help="添加前缀")
    
    # 后缀模式参数
    parser.add_argument("--suffix", help="添加后缀")
    parser.add_argument("--before-ext", action="store_true", default=True, help="在扩展名前添加后缀")
    
    # 替换模式参数
    parser.add_argument("--old-text", help="要替换的文本")
    parser.add_argument("--new-text", help="替换后的文本")
    parser.add_argument("--case-sensitive", action="store_true", default=True, help="区分大小写")
    
    # 序列模式参数
    parser.add_argument("--start", type=int, default=1, help="序列起始数字")
    parser.add_argument("--digits", type=int, default=3, help="序列数字位数")
    parser.add_argument("--ext-filter", help="扩展名过滤器")
    
    # 时间戳模式参数
    parser.add_argument("--format", choices=["datetime", "date", "time", "iso", "unix"],
                        default="datetime", help="时间戳格式")
    
    # 大小写转换参数
    parser.add_argument("--case-type", choices=["lower", "upper", "title", "sentence"],
                        default="lower", help="大小写转换类型")
    
    args = parser.parse_args()
    
    # 检查目录
    directory = Path(args.directory)
    if not directory.exists():
        print(f"错误: 目录不存在: {directory}")
        sys.exit(1)
    
    if not directory.is_dir():
        print(f"错误: 不是目录: {directory}")
        sys.exit(1)
    
    # 创建重命名器
    renamer = BatchRenamer(
        directory=directory,
        mode=args.mode,
        dry_run=args.dry_run,
        verbose=args.verbose
    )
    
    # 根据模式执行重命名
    try:
        if args.mode == "prefix":
            if not args.prefix:
                print("错误: 前缀模式需要指定 --prefix 参数")
                sys.exit(1)
            renamer.add_prefix(args.prefix)
        
        elif args.mode == "suffix":
            if not args.suffix:
                print("错误: 后缀模式需要指定 --suffix 参数")
                sys.exit(1)
            renamer.add_suffix(args.suffix, args.before_ext)
        
        elif args.mode == "replace":
            if not args.old_text or args.new_text is None:
                print("错误: 替换模式需要指定 --old-text 和 --new-text 参数")
                sys.exit(1)
            renamer.replace_text(args.old_text, args.new_text, args.case_sensitive)
        
        elif args.mode == "sequence":
            renamer.sequence_rename(
                prefix=args.prefix or "",
                start=args.start,
                digits=args.digits,
                ext_filter=args.ext_filter
            )
        
        elif args.mode == "timestamp":
            renamer.timestamp_rename(args.format)
        
        elif args.mode == "case":
            renamer.case_convert(args.case_type)
        
        # 预览或执行
        if args.preview:
            renamer.preview_renames()
        else:
            renamer.execute_renames()
        
        # 保存计划
        if args.save_plan:
            renamer.save_plan(args.save_plan)
        
        # 返回适当的退出码
        if renamer.errors:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n操作被用户中断")
        sys.exit(130)
    except Exception as e:
        print(f"重命名失败: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()