
#!/usr/bin/env python3
import os
import shutil
import datetime
import sys

def backup_folder(src, dst):
    if not os.path.exists(src):
        print(f"源目录不存在: {src}")
        return
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"backup_{timestamp}"
    backup_path = os.path.join(dst, backup_name)
    try:
        shutil.copytree(src, backup_path)
        print(f"备份成功: {backup_path}")
    except Exception as e:
        print(f"备份失败: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法: python3 backup-tool.py <源目录> <目标目录>")
        sys.exit(1)
    backup_folder(sys.argv[1], sys.argv[2])