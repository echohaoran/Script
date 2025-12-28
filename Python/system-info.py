#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
系统信息收集工具
功能：收集系统硬件、软件、网络等信息并生成报告
使用方法：python3 system-info.py [选项]
"""

import os
import sys
import platform
import subprocess
import json
import datetime
import socket
import psutil
import distro
from pathlib import Path


class SystemInfo:
    def __init__(self):
        self.info = {}
        self.timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        self.report_file = f"system-report-{self.timestamp}.txt"
        
    def run_command(self, command):
        """执行命令并返回输出"""
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=30)
            return result.stdout.strip()
        except Exception as e:
            return f"Error: {str(e)}"
    
    def get_basic_info(self):
        """获取系统基本信息"""
        print("收集系统基本信息...")
        
        self.info['basic'] = {
            'hostname': socket.gethostname(),
            'platform': platform.platform(),
            'system': platform.system(),
            'release': platform.release(),
            'version': platform.version(),
            'machine': platform.machine(),
            'processor': platform.processor(),
            'python_version': platform.python_version(),
            'timestamp': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # 获取Linux发行版信息
        if platform.system() == "Linux":
            try:
                self.info['basic']['distribution'] = distro.name(pretty=True)
                self.info['basic']['distribution_version'] = distro.version()
            except:
                pass
    
    def get_cpu_info(self):
        """获取CPU信息"""
        print("收集CPU信息...")
        
        cpu_info = {
            'physical_cores': psutil.cpu_count(logical=False),
            'total_cores': psutil.cpu_count(logical=True),
            'max_frequency': psutil.cpu_freq().max if psutil.cpu_freq() else "N/A",
            'current_frequency': psutil.cpu_freq().current if psutil.cpu_freq() else "N/A",
            'cpu_usage_per_core': dict(enumerate(psutil.cpu_percent(percpu=True, interval=1))),
            'total_cpu_usage': psutil.cpu_percent(interval=1)
        }
        
        # 获取CPU型号
        if platform.system() == "Linux":
            model = self.run_command("grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs")
            if model and model != "Error:":
                cpu_info['model'] = model
        elif platform.system() == "Darwin":  # macOS
            model = self.run_command("sysctl -n machdep.cpu.brand_string")
            if model and model != "Error:":
                cpu_info['model'] = model
        elif platform.system() == "Windows":
            model = self.run_command("wmic cpu get name /value | findstr Name")
            if model and model != "Error:":
                cpu_info['model'] = model.split("=")[1].strip()
        
        self.info['cpu'] = cpu_info
    
    def get_memory_info(self):
        """获取内存信息"""
        print("收集内存信息...")
        
        virtual_mem = psutil.virtual_memory()
        swap_mem = psutil.swap_memory()
        
        self.info['memory'] = {
            'total': self._bytes_to_human(virtual_mem.total),
            'available': self._bytes_to_human(virtual_mem.available),
            'used': self._bytes_to_human(virtual_mem.used),
            'percentage': virtual_mem.percent,
            'swap_total': self._bytes_to_human(swap_mem.total),
            'swap_used': self._bytes_to_human(swap_mem.used),
            'swap_percentage': swap_mem.percent
        }
    
    def get_disk_info(self):
        """获取磁盘信息"""
        print("收集磁盘信息...")
        
        disk_partitions = psutil.disk_partitions()
        disk_info = []
        
        for partition in disk_partitions:
            try:
                partition_usage = psutil.disk_usage(partition.mountpoint)
                disk_info.append({
                    'device': partition.device,
                    'mountpoint': partition.mountpoint,
                    'fstype': partition.fstype,
                    'total': self._bytes_to_human(partition_usage.total),
                    'used': self._bytes_to_human(partition_usage.used),
                    'free': self._bytes_to_human(partition_usage.free),
                    'percentage': round((partition_usage.used / partition_usage.total) * 100, 2)
                })
            except PermissionError:
                continue
        
        self.info['disk'] = disk_info
    
    def get_network_info(self):
        """获取网络信息"""
        print("收集网络信息...")
        
        network_info = {}
        
        # 网络接口
        network_interfaces = psutil.net_if_addrs()
        network_stats = psutil.net_if_stats()
        
        interfaces = {}
        for interface_name, interface_addresses in network_interfaces.items():
            interface_info = {
                'addresses': [],
                'is_up': network_stats[interface_name].isup,
                'speed': network_stats[interface_name].speed,
                'mtu': network_stats[interface_name].mtu
            }
            
            for address in interface_addresses:
                interface_info['addresses'].append({
                    'family': str(address.family),
                    'address': address.address,
                    'netmask': address.netmask,
                    'broadcast': address.broadcast
                })
            
            interfaces[interface_name] = interface_info
        
        network_info['interfaces'] = interfaces
        
        # 网络IO统计
        net_io = psutil.net_io_counters()
        network_info['io_stats'] = {
            'bytes_sent': self._bytes_to_human(net_io.bytes_sent),
            'bytes_recv': self._bytes_to_human(net_io.bytes_recv),
            'packets_sent': net_io.packets_sent,
            'packets_recv': net_io.packets_recv
        }
        
        # 网络连接
        connections = []
        for conn in psutil.net_connections(kind='inet'):
            if conn.status == 'ESTABLISHED':
                connections.append({
                    'local_address': f"{conn.laddr.ip}:{conn.laddr.port}",
                    'remote_address': f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else "N/A",
                    'status': conn.status,
                    'pid': conn.pid
                })
        
        network_info['connections'] = connections[:20]  # 只显示前20个连接
        
        self.info['network'] = network_info
    
    def get_process_info(self):
        """获取进程信息"""
        print("收集进程信息...")
        
        # 获取CPU使用率最高的前10个进程
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent', 'memory_info']):
            try:
                processes.append(proc.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
        
        # 按CPU使用率排序
        processes.sort(key=lambda x: x.get('cpu_percent', 0), reverse=True)
        
        self.info['processes'] = {
            'total_count': len(processes),
            'top_cpu': processes[:10],
            'top_memory': sorted(processes, key=lambda x: x.get('memory_percent', 0), reverse=True)[:10]
        }
    
    def get_system_services(self):
        """获取系统服务信息"""
        print("收集系统服务信息...")
        
        services = []
        
        if platform.system() == "Linux":
            # 获取systemd服务
            output = self.run_command("systemctl list-units --type=service --state=running --no-legend")
            if output and output != "Error:":
                for line in output.split('\n')[:20]:  # 只取前20个
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 4:
                            services.append({
                                'name': parts[0],
                                'load': parts[1],
                                'active': parts[2],
                                'sub': parts[3],
                                'description': ' '.join(parts[4:]) if len(parts) > 4 else ""
                            })
        
        self.info['services'] = services
    
    def _bytes_to_human(self, bytes_value):
        """将字节转换为人类可读格式"""
        if bytes_value == 0:
            return "0B"
        
        size_names = ["B", "KB", "MB", "GB", "TB", "PB"]
        i = 0
        while bytes_value >= 1024 and i < len(size_names) - 1:
            bytes_value /= 1024.0
            i += 1
        
        return f"{bytes_value:.2f}{size_names[i]}"
    
    def generate_report(self):
        """生成报告"""
        print("生成报告...")
        
        with open(self.report_file, 'w', encoding='utf-8') as f:
            f.write("=" * 50 + "\n")
            f.write("        系统信息收集报告\n")
            f.write("=" * 50 + "\n\n")
            
            # 基本信息
            f.write("==== 系统基本信息 ====\n")
            for key, value in self.info['basic'].items():
                f.write(f"{key}: {value}\n")
            f.write("\n")
            
            # CPU信息
            f.write("==== CPU 信息 ====\n")
            for key, value in self.info['cpu'].items():
                f.write(f"{key}: {value}\n")
            f.write("\n")
            
            # 内存信息
            f.write("==== 内存信息 ====\n")
            for key, value in self.info['memory'].items():
                f.write(f"{key}: {value}\n")
            f.write("\n")
            
            # 磁盘信息
            f.write("==== 磁盘信息 ====\n")
            for disk in self.info['disk']:
                f.write(f"设备: {disk['device']}\n")
                f.write(f"  挂载点: {disk['mountpoint']}\n")
                f.write(f"  文件系统: {disk['fstype']}\n")
                f.write(f"  总容量: {disk['total']}\n")
                f.write(f"  已使用: {disk['used']}\n")
                f.write(f"  可用空间: {disk['free']}\n")
                f.write(f"  使用率: {disk['percentage']}%\n\n")
            
            # 网络信息
            f.write("==== 网络信息 ====\n")
            for interface_name, interface_data in self.info['network']['interfaces'].items():
                f.write(f"接口: {interface_name}\n")
                f.write(f"  状态: {'启用' if interface_data['is_up'] else '禁用'}\n")
                f.write(f"  速度: {interface_data['speed']} Mbps\n")
                for addr in interface_data['addresses']:
                    f.write(f"  地址: {addr['address']}\n")
                f.write("\n")
            
            # 进程信息
            f.write("==== 进程信息 ====\n")
            f.write(f"总进程数: {self.info['processes']['total_count']}\n\n")
            f.write("CPU使用率最高的进程:\n")
            for proc in self.info['processes']['top_cpu']:
                f.write(f"  PID: {proc['pid']}, 名称: {proc['name']}, CPU: {proc.get('cpu_percent', 0)}%, 内存: {proc.get('memory_percent', 0)}%\n")
            f.write("\n")
            
            # 服务信息
            if self.info['services']:
                f.write("==== 系统服务 ====\n")
                for service in self.info['services']:
                    f.write(f"{service['name']} - {service['active']} {service['sub']} - {service['description']}\n")
                f.write("\n")
        
        print(f"报告已生成: {self.report_file}")
    
    def collect_all_info(self):
        """收集所有信息"""
        self.get_basic_info()
        self.get_cpu_info()
        self.get_memory_info()
        self.get_disk_info()
        self.get_network_info()
        self.get_process_info()
        self.get_system_services()
    
    def save_json(self):
        """保存为JSON格式"""
        json_file = f"system-info-{self.timestamp}.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(self.info, f, indent=2, ensure_ascii=False)
        print(f"JSON信息已保存: {json_file}")


def main():
    print("=" * 50)
    print("        系统信息收集工具")
    print("=" * 50)
    
    # 检查依赖
    try:
        import psutil
    except ImportError:
        print("错误: 需要安装psutil库")
        print("请运行: pip install psutil")
        sys.exit(1)
    
    try:
        import distro
    except ImportError:
        print("警告: 未安装distro库，Linux发行版信息可能不完整")
        print("可选安装: pip install distro")
    
    # 创建系统信息收集器
    collector = SystemInfo()
    
    # 收集信息
    collector.collect_all_info()
    
    # 生成报告
    collector.generate_report()
    
    # 保存JSON
    if len(sys.argv) > 1 and sys.argv[1] == "--json":
        collector.save_json()
    
    print("\n系统信息收集完成！")


if __name__ == "__main__":
    main()
