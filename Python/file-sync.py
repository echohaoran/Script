#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
文件同步工具
功能：在两个目录之间同步文件，支持多种同步模式
使用方法：python3 file-sync.py [源目录] [目标目录] [模式]
"""

import os
import sys
import shutil
import hashlib
import argparse
import json
from pathlib import Path
import datetime
from concurrent.futures import ThreadPoolExecutor
import time


class FileSync:
    def __init__(self, source_dir, target_dir, mode="mirror", dry_run=False, verbose=False):
        """
        初始化文件同步器
        
        参数:
            source_dir: 源目录
            target_dir: 目标目录
            mode: 同步模式 (mirror, backup, sync)
            dry_run: 模拟运行，不实际操作
            verbose: 详细输出
        """
        self.source_dir = Path(source_dir).resolve()
        self.target_dir = Path(target_dir).resolve()
        self.mode = mode
        self.dry_run = dry_run
        self.verbose = verbose
        self.stats = {
            "copied": 0,
            "updated": 0,
            "deleted": 0,
            "skipped": 0,
            "errors": 0
        }
        self.excluded_files = set()
        self.excluded_dirs = set()
        self.log_file = f"sync-log-{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
    def log(self, message):
        """记录日志"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        
        if self.verbose:
            print(log_entry)
        
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
    
    def get_file_hash(self, file_path):
        """计算文件哈希值"""
        hash_md5 = hashlib.md5()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception as e:
            self.log(f"计算哈希失败 {file_path}: {str(e)}")
            return None
    
    def should_exclude(self, path):
        """检查文件或目录是否应该被排除"""
        path_name = path.name
        
        # 排除临时文件和系统文件
        if path_name.startswith('.') or path_name.startswith('~') or path_name.endswith('.tmp'):
            return True
        
        # 排除日志文件
        if path_name.endswith('.log'):
            return True
        
        # 排除缓存目录
        if path_name in ['__pycache__', '.git', '.svn', 'node_modules', '.vscode', '.idea']:
            return True
        
        # 检查自定义排除列表
        if path in self.excluded_files or path in self.excluded_dirs:
            return True
        
        return False
    
    def copy_file(self, source_file, target_file):
        """复制文件"""
        try:
            # 确保目标目录存在
            target_file.parent.mkdir(parents=True, exist_ok=True)
            
            # 检查是否需要复制
            if target_file.exists():
                source_hash = self.get_file_hash(source_file)
                target_hash = self.get_file_hash(target_file)
                
                if source_hash == target_hash:
                    self.stats["skipped"] += 1
                    self.log(f"跳过 (相同): {source_file}")
                    return
            
            # 执行复制
            if not self.dry_run:
                shutil.copy2(source_file, target_file)
            
            if target_file.exists():
                self.stats["updated"] += 1
                self.log(f"更新: {source_file} -> {target_file}")
            else:
                self.stats["copied"] += 1
                self.log(f"复制: {source_file} -> {target_file}")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"复制失败 {source_file}: {str(e)}")
    
    def delete_file(self, file_path):
        """删除文件"""
        try:
            if not self.dry_run:
                file_path.unlink()
            
            self.stats["deleted"] += 1
            self.log(f"删除: {file_path}")
            
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"删除失败 {file_path}: {str(e)}")
    
    def delete_directory(self, dir_path):
        """删除目录"""
        try:
            if not self.dry_run:
                shutil.rmtree(dir_path)
            
            self.stats["deleted"] += 1
            self.log(f"删除目录: {dir_path}")
            
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"删除目录失败 {dir_path}: {str(e)}")
    
    def mirror_sync(self):
        """镜像同步：目标目录完全镜像源目录"""
        self.log("开始镜像同步...")
        
        # 确保目标目录存在
        self.target_dir.mkdir(parents=True, exist_ok=True)
        
        # 同步文件
        for source_file in self.source_dir.rglob('*'):
            if self.should_exclude(source_file):
                continue
                
            if source_file.is_file():
                relative_path = source_file.relative_to(self.source_dir)
                target_file = self.target_dir / relative_path
                self.copy_file(source_file, target_file)
        
        # 删除目标目录中多余的文件
        for target_file in self.target_dir.rglob('*'):
            if self.should_exclude(target_file):
                continue
                
            if target_file.is_file():
                relative_path = target_file.relative_to(self.target_dir)
                source_file = self.source_dir / relative_path
                
                if not source_file.exists():
                    self.delete_file(target_file)
        
        # 删除目标目录中多余的空目录
        for target_dir in sorted(self.target_dir.rglob('*'), reverse=True):
            if target_dir.is_dir() and not any(target_dir.iterdir()):
                relative_path = target_dir.relative_to(self.target_dir)
                source_dir = self.source_dir / relative_path
                
                if not source_dir.exists():
                    self.delete_directory(target_dir)
    
    def backup_sync(self):
        """备份同步：只复制新文件和更新的文件，不删除目标目录中的文件"""
        self.log("开始备份同步...")
        
        # 确保目标目录存在
        self.target_dir.mkdir(parents=True, exist_ok=True)
        
        # 同步文件
        for source_file in self.source_dir.rglob('*'):
            if self.should_exclude(source_file):
                continue
                
            if source_file.is_file():
                relative_path = source_file.relative_to(self.source_dir)
                target_file = self.target_dir / relative_path
                self.copy_file(source_file, target_file)
    
    def two_way_sync(self):
        """双向同步：在两个目录之间同步最新的文件"""
        self.log("开始双向同步...")
        
        # 确保两个目录都存在
        self.source_dir.mkdir(parents=True, exist_ok=True)
        self.target_dir.mkdir(parents=True, exist_ok=True)
        
        # 收集所有文件
        all_files = {}
        
        # 处理源目录文件
        for source_file in self.source_dir.rglob('*'):
            if self.should_exclude(source_file) or not source_file.is_file():
                continue
                
            relative_path = source_file.relative_to(self.source_dir)
            file_info = {
                'path': source_file,
                'mtime': source_file.stat().st_mtime,
                'size': source_file.stat().st_size,
                'source': 'source'
            }
            all_files[str(relative_path)] = file_info
        
        # 处理目标目录文件
        for target_file in self.target_dir.rglob('*'):
            if self.should_exclude(target_file) or not target_file.is_file():
                continue
                
            relative_path = target_file.relative_to(self.target_dir)
            file_info = {
                'path': target_file,
                'mtime': target_file.stat().st_mtime,
                'size': target_file.stat().st_size,
                'source': 'target'
            }
            
            if str(relative_path) in all_files:
                # 比较修改时间
                if file_info['mtime'] > all_files[str(relative_path)]['mtime']:
                    all_files[str(relative_path)] = file_info
            else:
                all_files[str(relative_path)] = file_info
        
        # 同步文件
        for relative_path, file_info in all_files.items():
            source_path = self.source_dir / relative_path
            target_path = self.target_dir / relative_path
            
            if file_info['source'] == 'source':
                self.copy_file(source_path, target_path)
            else:
                self.copy_file(target_path, source_path)
    
    def add_exclusion(self, path):
        """添加排除路径"""
        path_obj = Path(path)
        if path_obj.is_file():
            self.excluded_files.add(path_obj.resolve())
        elif path_obj.is_dir():
            self.excluded_dirs.add(path_obj.resolve())
    
    def load_exclusions_from_file(self, file_path):
        """从文件加载排除列表"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        self.add_exclusion(line)
        except Exception as e:
            self.log(f"加载排除列表失败: {str(e)}")
    
    def save_exclusions_to_file(self, file_path):
        """保存排除列表到文件"""
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write("# 文件同步排除列表\n")
                f.write("# 以#开头的行为注释\n\n")
                
                for path in self.excluded_files:
                    f.write(f"{path}\n")
                
                for path in self.excluded_dirs:
                    f.write(f"{path}\n")
        except Exception as e:
            self.log(f"保存排除列表失败: {str(e)}")
    
    def run_sync(self):
        """执行同步"""
        start_time = time.time()
        
        self.log(f"开始同步: {self.source_dir} -> {self.target_dir}")
        self.log(f"同步模式: {self.mode}")
        self.log(f"模拟运行: {self.dry_run}")
        
        # 根据模式执行同步
        if self.mode == "mirror":
            self.mirror_sync()
        elif self.mode == "backup":
            self.backup_sync()
        elif self.mode == "sync":
            self.two_way_sync()
        else:
            raise ValueError(f"不支持的同步模式: {self.mode}")
        
        # 输出统计信息
        end_time = time.time()
        duration = end_time - start_time
        
        self.log("=" * 50)
        self.log("同步完成统计:")
        self.log(f"  复制文件: {self.stats['copied']}")
        self.log(f"  更新文件: {self.stats['updated']}")
        self.log(f"  删除文件: {self.stats['deleted']}")
        self.log(f"  跳过文件: {self.stats['skipped']}")
        self.log(f"  错误数量: {self.stats['errors']}")
        self.log(f"  耗时: {duration:.2f} 秒")
        self.log("=" * 50)
        
        return self.stats


def main():
    parser = argparse.ArgumentParser(description="文件同步工具")
    parser.add_argument("source", help="源目录")
    parser.add_argument("target", help="目标目录")
    parser.add_argument("-m", "--mode", choices=["mirror", "backup", "sync"], 
                        default="mirror", help="同步模式 (默认: mirror)")
    parser.add_argument("-d", "--dry-run", action="store_true", 
                        help="模拟运行，不实际操作")
    parser.add_argument("-v", "--verbose", action="store_true", 
                        help="详细输出")
    parser.add_argument("-e", "--exclude", nargs="*", 
                        help="排除的文件或目录")
    parser.add_argument("--exclude-from", 
                        help="从文件加载排除列表")
    parser.add_argument("--save-exclude", 
                        help="保存排除列表到文件")
    
    args = parser.parse_args()
    
    # 检查源目录
    source_dir = Path(args.source)
    if not source_dir.exists():
        print(f"错误: 源目录不存在: {source_dir}")
        sys.exit(1)
    
    # 创建同步器
    sync = FileSync(
        source_dir=source_dir,
        target_dir=args.target,
        mode=args.mode,
        dry_run=args.dry_run,
        verbose=args.verbose
    )
    
    # 添加排除项
    if args.exclude:
        for exclude_path in args.exclude:
            sync.add_exclusion(exclude_path)
    
    # 从文件加载排除列表
    if args.exclude_from:
        sync.load_exclusions_from_file(args.exclude_from)
    
    # 执行同步
    try:
        stats = sync.run_sync()
        
        # 保存排除列表
        if args.save_exclude:
            sync.save_exclusions_to_file(args.save_exclude)
        
        # 返回适当的退出码
        if stats["errors"] > 0:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n同步被用户中断")
        sys.exit(130)
    except Exception as e:
        print(f"同步失败: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()