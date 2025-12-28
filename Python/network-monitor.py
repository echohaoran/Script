#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
网络监控工具
功能：监控网络连接、速度、流量等
使用方法：python3 network-monitor.py [选项]
"""

import os
import sys
import time
import argparse
import json
import socket
import subprocess
import threading
from pathlib import Path
import datetime
import psutil
import ping3

try:
    import speedtest
    SPEEDTEST_AVAILABLE = True
except ImportError:
    SPEEDTEST_AVAILABLE = False

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False


class NetworkMonitor:
    def __init__(self, interval=5, output_file=None, verbose=False):
        """
        初始化网络监控器
        
        参数:
            interval: 监控间隔（秒）
            output_file: 输出文件路径
            verbose: 详细输出
        """
        self.interval = interval
        self.output_file = output_file
        self.verbose = verbose
        self.running = False
        self.stats = {
            "start_time": None,
            "end_time": None,
            "samples": [],
            "alerts": []
        }
        self.thresholds = {
            "ping": 100,  # ms
            "download": 1,  # Mbps
            "upload": 1,  # Mbps
            "packet_loss": 5  # %
        }
        
    def log(self, message):
        """记录日志"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        
        if self.verbose:
            print(log_entry)
        
        if self.output_file:
            with open(self.output_file, "a", encoding="utf-8") as f:
                f.write(log_entry + "\n")
    
    def get_network_interfaces(self):
        """获取网络接口信息"""
        interfaces = {}
        
        # 获取网络接口地址
        addrs = psutil.net_if_addrs()
        stats = psutil.net_if_stats()
        
        for interface_name, interface_addresses in addrs.items():
            interface_info = {
                "name": interface_name,
                "addresses": [],
                "is_up": stats[interface_name].isup,
                "speed": stats[interface_name].speed,
                "mtu": stats[interface_name].mtu
            }
            
            for addr in interface_addresses:
                address_info = {
                    "family": str(addr.family),
                    "address": addr.address,
                    "netmask": addr.netmask,
                    "broadcast": addr.broadcast
                }
                interface_info["addresses"].append(address_info)
            
            interfaces[interface_name] = interface_info
        
        return interfaces
    
    def get_network_io_stats(self):
        """获取网络IO统计"""
        io_counters = psutil.net_io_counters()
        per_nic = psutil.net_io_counters(pernic=True)
        
        stats = {
            "total": {
                "bytes_sent": io_counters.bytes_sent,
                "bytes_recv": io_counters.bytes_recv,
                "packets_sent": io_counters.packets_sent,
                "packets_recv": io_counters.packets_recv,
                "errin": io_counters.errin,
                "errout": io_counters.errout,
                "dropin": io_counters.dropin,
                "dropout": io_counters.dropout
            },
            "per_interface": {}
        }
        
        for interface, data in per_nic.items():
            stats["per_interface"][interface] = {
                "bytes_sent": data.bytes_sent,
                "bytes_recv": data.bytes_recv,
                "packets_sent": data.packets_sent,
                "packets_recv": data.packets_recv,
                "errin": data.errin,
                "errout": data.errout,
                "dropin": data.dropin,
                "dropout": data.dropout
            }
        
        return stats
    
    def get_active_connections(self):
        """获取活动网络连接"""
        connections = []
        
        for conn in psutil.net_connections(kind='inet'):
            if conn.status == 'ESTABLISHED':
                connection_info = {
                    "local_address": f"{conn.laddr.ip}:{conn.laddr.port}",
                    "remote_address": f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else None,
                    "status": conn.status,
                    "pid": conn.pid,
                    "process_name": None
                }
                
                # 获取进程名称
                try:
                    if conn.pid:
                        process = psutil.Process(conn.pid)
                        connection_info["process_name"] = process.name()
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
                
                connections.append(connection_info)
        
        return connections
    
    def ping_host(self, host, count=4):
        """Ping主机"""
        results = {
            "host": host,
            "sent": count,
            "received": 0,
            "lost": 0,
            "min_time": None,
            "max_time": None,
            "avg_time": None,
            "packet_loss": 100
        }
        
        times = []
        
        for _ in range(count):
            try:
                response_time = ping3.ping(host, timeout=2)
                if response_time is not None:
                    times.append(response_time * 1000)  # 转换为毫秒
                    results["received"] += 1
            except:
                pass
        
        results["lost"] = results["sent"] - results["received"]
        
        if times:
            results["min_time"] = min(times)
            results["max_time"] = max(times)
            results["avg_time"] = sum(times) / len(times)
            results["packet_loss"] = (results["lost"] / results["sent"]) * 100
        
        return results
    
    def test_internet_speed(self):
        """测试网络速度"""
        if not SPEEDTEST_AVAILABLE:
            return {"error": "speedtest-cli库未安装"}
        
        try:
            st = speedtest.Speedtest()
            
            # 获取最佳服务器
            st.get_best_server()
            
            # 测试下载速度
            download_speed = st.download() / 1_000_000  # 转换为Mbps
            
            # 测试上传速度
            upload_speed = st.upload() / 1_000_000  # 转换为Mbps
            
            # 获取服务器信息
            server_info = {
                "name": st.best_server["name"],
                "country": st.best_server["country"],
                "sponsor": st.best_server["sponsor"],
                "latency": st.best_server["latency"]
            }
            
            return {
                "download_mbps": round(download_speed, 2),
                "upload_mbps": round(upload_speed, 2),
                "server": server_info
            }
            
        except Exception as e:
            return {"error": str(e)}
    
    def check_dns_resolution(self, domains):
        """检查DNS解析"""
        results = {}
        
        for domain in domains:
            try:
                ip_address = socket.gethostbyname(domain)
                results[domain] = {
                    "success": True,
                    "ip_address": ip_address,
                    "error": None
                }
            except Exception as e:
                results[domain] = {
                    "success": False,
                    "ip_address": None,
                    "error": str(e)
                }
        
        return results
    
    def check_http_status(self, urls):
        """检查HTTP状态"""
        if not REQUESTS_AVAILABLE:
            return {"error": "requests库未安装"}
        
        results = {}
        
        for url in urls:
            try:
                response = requests.get(url, timeout=10)
                results[url] = {
                    "success": True,
                    "status_code": response.status_code,
                    "response_time": response.elapsed.total_seconds(),
                    "error": None
                }
            except Exception as e:
                results[url] = {
                    "success": False,
                    "status_code": None,
                    "response_time": None,
                    "error": str(e)
                }
        
        return results
    
    def collect_sample(self):
        """收集一次网络数据样本"""
        timestamp = datetime.datetime.now()
        
        sample = {
            "timestamp": timestamp.isoformat(),
            "interfaces": self.get_network_interfaces(),
            "io_stats": self.get_network_io_stats(),
            "connections": self.get_active_connections()
        }
        
        # Ping测试
        ping_results = self.ping_host("8.8.8.8", count=3)
        sample["ping"] = ping_results
        
        # 检查阈值并生成告警
        if ping_results["avg_time"] and ping_results["avg_time"] > self.thresholds["ping"]:
            alert = {
                "timestamp": timestamp.isoformat(),
                "type": "ping_high",
                "message": f"Ping延迟过高: {ping_results['avg_time']:.2f}ms",
                "value": ping_results["avg_time"],
                "threshold": self.thresholds["ping"]
            }
            self.stats["alerts"].append(alert)
            self.log(f"告警: {alert['message']}")
        
        if ping_results["packet_loss"] > self.thresholds["packet_loss"]:
            alert = {
                "timestamp": timestamp.isoformat(),
                "type": "packet_loss",
                "message": f"丢包率过高: {ping_results['packet_loss']:.1f}%",
                "value": ping_results["packet_loss"],
                "threshold": self.thresholds["packet_loss"]
            }
            self.stats["alerts"].append(alert)
            self.log(f"告警: {alert['message']}")
        
        return sample
    
    def monitor_loop(self, duration=None):
        """监控循环"""
        self.running = True
        self.stats["start_time"] = datetime.datetime.now().isoformat()
        
        self.log("开始网络监控")
        self.log(f"监控间隔: {self.interval}秒")
        if duration:
            self.log(f"监控时长: {duration}秒")
        
        start_time = time.time()
        
        try:
            while self.running:
                # 收集样本
                sample = self.collect_sample()
                self.stats["samples"].append(sample)
                
                # 检查是否达到时长限制
                if duration and (time.time() - start_time) >= duration:
                    break
                
                # 等待下一次采样
                time.sleep(self.interval)
                
        except KeyboardInterrupt:
            self.log("监控被用户中断")
        finally:
            self.running = False
            self.stats["end_time"] = datetime.datetime.now().isoformat()
    
    def run_speed_test(self):
        """运行速度测试"""
        self.log("开始网络速度测试")
        
        speed_result = self.test_internet_speed()
        
        if "error" in speed_result:
            self.log(f"速度测试失败: {speed_result['error']}")
            return speed_result
        
        self.log(f"下载速度: {speed_result['download_mbps']} Mbps")
        self.log(f"上传速度: {speed_result['upload_mbps']} Mbps")
        self.log(f"服务器: {speed_result['server']['name']} ({speed_result['server']['sponsor']})")
        
        # 检查阈值并生成告警
        if speed_result["download_mbps"] < self.thresholds["download"]:
            alert = {
                "timestamp": datetime.datetime.now().isoformat(),
                "type": "download_low",
                "message": f"下载速度过低: {speed_result['download_mbps']} Mbps",
                "value": speed_result["download_mbps"],
                "threshold": self.thresholds["download"]
            }
            self.stats["alerts"].append(alert)
            self.log(f"告警: {alert['message']}")
        
        if speed_result["upload_mbps"] < self.thresholds["upload"]:
            alert = {
                "timestamp": datetime.datetime.now().isoformat(),
                "type": "upload_low",
                "message": f"上传速度过低: {speed_result['upload_mbps']} Mbps",
                "value": speed_result["upload_mbps"],
                "threshold": self.thresholds["upload"]
            }
            self.stats["alerts"].append(alert)
            self.log(f"告警: {alert['message']}")
        
        return speed_result
    
    def run_connectivity_test(self):
        """运行连接性测试"""
        self.log("开始连接性测试")
        
        # DNS测试
        domains = ["google.com", "baidu.com", "github.com"]
        dns_results = self.check_dns_resolution(domains)
        
        for domain, result in dns_results.items():
            if result["success"]:
                self.log(f"DNS解析 {domain}: {result['ip_address']}")
            else:
                self.log(f"DNS解析失败 {domain}: {result['error']}")
        
        # HTTP测试
        urls = ["http://www.google.com", "http://www.baidu.com", "http://www.github.com"]
        http_results = self.check_http_status(urls)
        
        for url, result in http_results.items():
            if result["success"]:
                self.log(f"HTTP测试 {url}: {result['status_code']} ({result['response_time']:.3f}s)")
            else:
                self.log(f"HTTP测试失败 {url}: {result['error']}")
        
        return {
            "dns": dns_results,
            "http": http_results
        }
    
    def save_report(self, output_file):
        """保存监控报告"""
        report = {
            "monitoring_info": {
                "start_time": self.stats["start_time"],
                "end_time": self.stats["end_time"],
                "interval": self.interval,
                "sample_count": len(self.stats["samples"]),
                "alert_count": len(self.stats["alerts"])
            },
            "samples": self.stats["samples"],
            "alerts": self.stats["alerts"]
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        self.log(f"监控报告已保存到: {output_file}")


def main():
    parser = argparse.ArgumentParser(description="网络监控工具")
    parser.add_argument("-i", "--interval", type=int, default=5, help="监控间隔（秒）")
    parser.add_argument("-d", "--duration", type=int, help="监控时长（秒）")
    parser.add_argument("-o", "--output", help="输出文件路径")
    parser.add_argument("-v", "--verbose", action="store_true", help="详细输出")
    parser.add_argument("--speed-test", action="store_true", help="执行速度测试")
    parser.add_argument("--connectivity-test", action="store_true", help="执行连接性测试")
    parser.add_argument("--ping-threshold", type=float, default=100, help="Ping延迟阈值（毫秒）")
    parser.add_argument("--download-threshold", type=float, default=1, help="下载速度阈值（Mbps）")
    parser.add_argument("--upload-threshold", type=float, default=1, help="上传速度阈值（Mbps）")
    parser.add_argument("--packet-loss-threshold", type=float, default=5, help="丢包率阈值（%）")
    
    args = parser.parse_args()
    
    # 创建监控器
    monitor = NetworkMonitor(
        interval=args.interval,
        output_file=args.output,
        verbose=args.verbose
    )
    
    # 设置阈值
    monitor.thresholds["ping"] = args.ping_threshold
    monitor.thresholds["download"] = args.download_threshold
    monitor.thresholds["upload"] = args.upload_threshold
    monitor.thresholds["packet_loss"] = args.packet_loss_threshold
    
    # 执行测试
    if args.speed_test:
        monitor.run_speed_test()
    
    if args.connectivity_test:
        monitor.run_connectivity_test()
    
    # 执行监控
    if not args.speed_test and not args.connectivity_test:
        monitor.monitor_loop(args.duration)
        
        # 保存报告
        if args.output and monitor.stats["samples"]:
            monitor.save_report(args.output)
        
        # 输出统计
        print("\n监控统计:")
        print(f"  样本数量: {len(monitor.stats['samples'])}")
        print(f"  告警数量: {len(monitor.stats['alerts'])}")
        print(f"  开始时间: {monitor.stats['start_time']}")
        print(f"  结束时间: {monitor.stats['end_time']}")


if __name__ == "__main__":
    main()
