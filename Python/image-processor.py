#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
图像处理工具
功能：批量处理图像文件，支持缩放、转换、水印等操作
使用方法：python3 image-processor.py [输入目录] [输出目录] [操作]
"""

import os
import sys
import argparse
from pathlib import Path
import datetime
import json
from concurrent.futures import ThreadPoolExecutor
import time

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False
    print("警告: 未安装Pillow库，图像处理功能不可用")
    print("请运行: pip install Pillow")

try:
    import cv2
    import numpy as np
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False


class ImageProcessor:
    def __init__(self, input_dir, output_dir, dry_run=False, verbose=False):
        """
        初始化图像处理器
        
        参数:
            input_dir: 输入目录
            output_dir: 输出目录
            dry_run: 模拟运行，不实际操作
            verbose: 详细输出
        """
        self.input_dir = Path(input_dir).resolve()
        self.output_dir = Path(output_dir).resolve()
        self.dry_run = dry_run
        self.verbose = verbose
        self.stats = {
            "processed": 0,
            "skipped": 0,
            "errors": 0
        }
        self.supported_formats = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'}
        self.log_file = f"image-process-{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
    def log(self, message):
        """记录日志"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        
        if self.verbose:
            print(log_entry)
        
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
    
    def is_image_file(self, file_path):
        """检查是否为图像文件"""
        return file_path.suffix.lower() in self.supported_formats
    
    def get_image_files(self):
        """获取所有图像文件"""
        image_files = []
        
        for file_path in self.input_dir.rglob('*'):
            if file_path.is_file() and self.is_image_file(file_path):
                image_files.append(file_path)
        
        return sorted(image_files)
    
    def resize_image(self, input_path, output_path, size=None, scale=None, maintain_aspect=True):
        """调整图像大小"""
        try:
            if not PIL_AVAILABLE:
                raise ImportError("Pillow库未安装")
            
            with Image.open(input_path) as img:
                original_size = img.size
                
                if scale:
                    new_size = (int(original_size[0] * scale), int(original_size[1] * scale))
                elif size:
                    if maintain_aspect:
                        img.thumbnail(size, Image.LANCZOS)
                        new_size = img.size
                    else:
                        new_size = size
                        img = img.resize(new_size, Image.LANCZOS)
                else:
                    new_size = original_size
                
                # 确保输出目录存在
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not self.dry_run:
                    img.save(output_path)
                
                self.stats["processed"] += 1
                self.log(f"调整大小: {input_path.name} {original_size} -> {new_size}")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"调整大小失败 {input_path}: {str(e)}")
    
    def convert_format(self, input_path, output_path, format="JPEG", quality=95):
        """转换图像格式"""
        try:
            if not PIL_AVAILABLE:
                raise ImportError("Pillow库未安装")
            
            with Image.open(input_path) as img:
                # 处理透明度
                if format.upper() == "JPEG" and img.mode in ("RGBA", "LA", "P"):
                    background = Image.new("RGB", img.size, (255, 255, 255))
                    if img.mode == "P":
                        img = img.convert("RGBA")
                    background.paste(img, mask=img.split()[-1] if img.mode == "RGBA" else None)
                    img = background
                
                # 确保输出目录存在
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not self.dry_run:
                    if format.upper() == "JPEG":
                        img.save(output_path, format=format, quality=quality, optimize=True)
                    elif format.upper() == "PNG":
                        img.save(output_path, format=format, optimize=True)
                    else:
                        img.save(output_path, format=format)
                
                self.stats["processed"] += 1
                self.log(f"转换格式: {input_path.name} -> {format}")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"转换格式失败 {input_path}: {str(e)}")
    
    def add_watermark(self, input_path, output_path, text=None, image_path=None, position="bottom-right", opacity=0.5):
        """添加水印"""
        try:
            if not PIL_AVAILABLE:
                raise ImportError("Pillow库未安装")
            
            with Image.open(input_path) as img:
                # 创建透明图层
                watermark = Image.new("RGBA", img.size, (0, 0, 0, 0))
                draw = ImageDraw.Draw(watermark)
                
                if text:
                    # 文本水印
                    try:
                        font = ImageFont.truetype("arial.ttf", 36)
                    except:
                        font = ImageFont.load_default()
                    
                    # 计算文本位置
                    bbox = draw.textbbox((0, 0), text, font=font)
                    text_width = bbox[2] - bbox[0]
                    text_height = bbox[3] - bbox[1]
                    
                    if position == "bottom-right":
                        x, y = img.width - text_width - 10, img.height - text_height - 10
                    elif position == "bottom-left":
                        x, y = 10, img.height - text_height - 10
                    elif position == "top-right":
                        x, y = img.width - text_width - 10, 10
                    elif position == "top-left":
                        x, y = 10, 10
                    else:  # center
                        x, y = (img.width - text_width) // 2, (img.height - text_height) // 2
                    
                    # 绘制文本
                    opacity_alpha = int(255 * opacity)
                    draw.text((x, y), text, font=font, fill=(255, 255, 255, opacity_alpha))
                
                elif image_path:
                    # 图像水印
                    with Image.open(image_path) as watermark_img:
                        # 调整水印大小
                        watermark_img.thumbnail((img.width // 4, img.height // 4))
                        
                        # 计算位置
                        if position == "bottom-right":
                            x, y = img.width - watermark_img.width - 10, img.height - watermark_img.height - 10
                        elif position == "bottom-left":
                            x, y = 10, img.height - watermark_img.height - 10
                        elif position == "top-right":
                            x, y = img.width - watermark_img.width - 10, 10
                        elif position == "top-left":
                            x, y = 10, 10
                        else:  # center
                            x, y = (img.width - watermark_img.width) // 2, (img.height - watermark_img.height) // 2
                        
                        # 设置透明度
                        if watermark_img.mode != "RGBA":
                            watermark_img = watermark_img.convert("RGBA")
                        
                        alpha = watermark_img.split()[-1]
                        alpha = ImageEnhance.Brightness(alpha).enhance(opacity)
                        watermark_img.putalpha(alpha)
                        
                        watermark.paste(watermark_img, (x, y), watermark_img)
                
                # 合并图像
                if img.mode != "RGBA":
                    img = img.convert("RGBA")
                
                watermarked = Image.alpha_composite(img, watermark)
                
                # 转换回原始模式
                if img.mode != "RGBA":
                    watermarked = watermarked.convert(img.mode)
                
                # 确保输出目录存在
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not self.dry_run:
                    watermarked.save(output_path)
                
                self.stats["processed"] += 1
                self.log(f"添加水印: {input_path.name}")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"添加水印失败 {input_path}: {str(e)}")
    
    def apply_filter(self, input_path, output_path, filter_type="blur", intensity=1.0):
        """应用滤镜"""
        try:
            if not PIL_AVAILABLE:
                raise ImportError("Pillow库未安装")
            
            with Image.open(input_path) as img:
                if filter_type == "blur":
                    filtered = img.filter(ImageFilter.GaussianBlur(radius=intensity * 5))
                elif filter_type == "sharpen":
                    filtered = img.filter(ImageFilter.UnsharpMask(radius=intensity * 2, percent=intensity * 100, threshold=3))
                elif filter_type == "edge":
                    filtered = img.filter(ImageFilter.FIND_EDGES)
                elif filter_type == "emboss":
                    filtered = img.filter(ImageFilter.EMBOSS)
                elif filter_type == "contour":
                    filtered = img.filter(ImageFilter.CONTOUR)
                elif filter_type == "brightness":
                    enhancer = ImageEnhance.Brightness(img)
                    filtered = enhancer.enhance(intensity)
                elif filter_type == "contrast":
                    enhancer = ImageEnhance.Contrast(img)
                    filtered = enhancer.enhance(intensity)
                elif filter_type == "color":
                    enhancer = ImageEnhance.Color(img)
                    filtered = enhancer.enhance(intensity)
                elif filter_type == "sharpness":
                    enhancer = ImageEnhance.Sharpness(img)
                    filtered = enhancer.enhance(intensity)
                else:
                    filtered = img
                
                # 确保输出目录存在
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not self.dry_run:
                    filtered.save(output_path)
                
                self.stats["processed"] += 1
                self.log(f"应用滤镜: {input_path.name} ({filter_type}, 强度={intensity})")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"应用滤镜失败 {input_path}: {str(e)}")
    
    def crop_image(self, input_path, output_path, left, top, right, bottom):
        """裁剪图像"""
        try:
            if not PIL_AVAILABLE:
                raise ImportError("Pillow库未安装")
            
            with Image.open(input_path) as img:
                cropped = img.crop((left, top, right, bottom))
                
                # 确保输出目录存在
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not self.dry_run:
                    cropped.save(output_path)
                
                self.stats["processed"] += 1
                self.log(f"裁剪图像: {input_path.name} ({left},{top},{right},{bottom})")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"裁剪图像失败 {input_path}: {str(e)}")
    
    def rotate_image(self, input_path, output_path, angle, expand=True):
        """旋转图像"""
        try:
            if not PIL_AVAILABLE:
                raise ImportError("Pillow库未安装")
            
            with Image.open(input_path) as img:
                rotated = img.rotate(angle, expand=expand, fillcolor="white")
                
                # 确保输出目录存在
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not self.dry_run:
                    rotated.save(output_path)
                
                self.stats["processed"] += 1
                self.log(f"旋转图像: {input_path.name} ({angle}度)")
                
        except Exception as e:
            self.stats["errors"] += 1
            self.log(f"旋转图像失败 {input_path}: {str(e)}")
    
    def batch_process(self, operation, **kwargs):
        """批量处理图像"""
        start_time = time.time()
        
        self.log(f"开始批量处理: {operation}")
        self.log(f"输入目录: {self.input_dir}")
        self.log(f"输出目录: {self.output_dir}")
        self.log(f"模拟运行: {self.dry_run}")
        
        # 获取所有图像文件
        image_files = self.get_image_files()
        self.log(f"找到 {len(image_files)} 个图像文件")
        
        if not image_files:
            self.log("没有找到图像文件")
            return
        
        # 确保输出目录存在
        if not self.dry_run:
            self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # 处理每个图像
        for input_path in image_files:
            # 计算相对路径
            relative_path = input_path.relative_to(self.input_dir)
            output_path = self.output_dir / relative_path
            
            # 执行操作
            if operation == "resize":
                self.resize_image(input_path, output_path, **kwargs)
            elif operation == "convert":
                # 更改扩展名
                output_path = output_path.with_suffix(f".{kwargs.get('format', 'jpg').lower()}")
                self.convert_format(input_path, output_path, **kwargs)
            elif operation == "watermark":
                self.add_watermark(input_path, output_path, **kwargs)
            elif operation == "filter":
                self.apply_filter(input_path, output_path, **kwargs)
            elif operation == "crop":
                self.crop_image(input_path, output_path, **kwargs)
            elif operation == "rotate":
                self.rotate_image(input_path, output_path, **kwargs)
            else:
                self.log(f"未知操作: {operation}")
                self.stats["skipped"] += 1
        
        # 输出统计
        end_time = time.time()
        duration = end_time - start_time
        
        self.log("=" * 50)
        self.log("处理统计:")
        self.log(f"  处理文件: {self.stats['processed']}")
        self.log(f"  跳过文件: {self.stats['skipped']}")
        self.log(f"  错误数量: {self.stats['errors']}")
        self.log(f"  耗时: {duration:.2f} 秒")
        self.log("=" * 50)
        
        return self.stats


def main():
    parser = argparse.ArgumentParser(description="图像处理工具")
    parser.add_argument("input_dir", help="输入目录")
    parser.add_argument("output_dir", help="输出目录")
    parser.add_argument("operation", choices=["resize", "convert", "watermark", "filter", "crop", "rotate"],
                        help="处理操作")
    parser.add_argument("-d", "--dry-run", action="store_true", help="模拟运行，不实际操作")
    parser.add_argument("-v", "--verbose", action="store_true", help="详细输出")
    parser.add_argument("-j", "--jobs", type=int, default=1, help="并行处理数量")
    
    # 调整大小参数
    parser.add_argument("--size", nargs=2, type=int, metavar=("WIDTH", "HEIGHT"),
                        help="目标尺寸 (宽度 高度)")
    parser.add_argument("--scale", type=float, help="缩放比例")
    parser.add_argument("--no-aspect", action="store_true", help="不保持宽高比")
    
    # 格式转换参数
    parser.add_argument("--format", help="目标格式 (JPEG, PNG, BMP, etc.)")
    parser.add_argument("--quality", type=int, default=95, help="JPEG质量 (1-100)")
    
    # 水印参数
    parser.add_argument("--watermark-text", help="水印文本")
    parser.add_argument("--watermark-image", help="水印图像路径")
    parser.add_argument("--position", choices=["top-left", "top-right", "bottom-left", "bottom-right", "center"],
                        default="bottom-right", help="水印位置")
    parser.add_argument("--opacity", type=float, default=0.5, help="水印透明度 (0-1)")
    
    # 滤镜参数
    parser.add_argument("--filter-type", choices=["blur", "sharpen", "edge", "emboss", "contour", 
                                                 "brightness", "contrast", "color", "sharpness"],
                        default="blur", help="滤镜类型")
    parser.add_argument("--intensity", type=float, default=1.0, help="滤镜强度")
    
    # 裁剪参数
    parser.add_argument("--crop", nargs=4, type=int, metavar=("LEFT", "TOP", "RIGHT", "BOTTOM"),
                        help="裁剪区域 (左 上 右 下)")
    
    # 旋转参数
    parser.add_argument("--angle", type=float, help="旋转角度")
    parser.add_argument("--no-expand", action="store_true", help="不扩展画布")
    
    args = parser.parse_args()
    
    # 检查输入目录
    input_dir = Path(args.input_dir)
    if not input_dir.exists():
        print(f"错误: 输入目录不存在: {input_dir}")
        sys.exit(1)
    
    # 创建处理器
    processor = ImageProcessor(
        input_dir=input_dir,
        output_dir=args.output_dir,
        dry_run=args.dry_run,
        verbose=args.verbose
    )
    
    # 准备操作参数
    operation_args = {}
    
    if args.operation == "resize":
        if args.size:
            operation_args["size"] = tuple(args.size)
            operation_args["maintain_aspect"] = not args.no_aspect
        elif args.scale:
            operation_args["scale"] = args.scale
        else:
            print("错误: 调整大小需要指定 --size 或 --scale 参数")
            sys.exit(1)
    
    elif args.operation == "convert":
        if not args.format:
            print("错误: 格式转换需要指定 --format 参数")
            sys.exit(1)
        operation_args["format"] = args.format.upper()
        operation_args["quality"] = args.quality
    
    elif args.operation == "watermark":
        if not args.watermark_text and not args.watermark_image:
            print("错误: 添加水印需要指定 --watermark-text 或 --watermark-image 参数")
            sys.exit(1)
        if args.watermark_text:
            operation_args["text"] = args.watermark_text
        if args.watermark_image:
            operation_args["image_path"] = args.watermark_image
        operation_args["position"] = args.position
        operation_args["opacity"] = args.opacity
    
    elif args.operation == "filter":
        operation_args["filter_type"] = args.filter_type
        operation_args["intensity"] = args.intensity
    
    elif args.operation == "crop":
        if not args.crop:
            print("错误: 裁剪需要指定 --crop 参数")
            sys.exit(1)
        operation_args["left"], operation_args["top"], operation_args["right"], operation_args["bottom"] = args.crop
    
    elif args.operation == "rotate":
        if args.angle is None:
            print("错误: 旋转需要指定 --angle 参数")
            sys.exit(1)
        operation_args["angle"] = args.angle
        operation_args["expand"] = not args.no_expand
    
    # 执行处理
    try:
        stats = processor.batch_process(args.operation, **operation_args)
        
        # 返回适当的退出码
        if stats["errors"] > 0:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n处理被用户中断")
        sys.exit(130)
    except Exception as e:
        print(f"处理失败: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
