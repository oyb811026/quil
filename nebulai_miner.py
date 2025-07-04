import hashlib
import time
import aiohttp
import asyncio
import numpy as np
import os
import gc
from typing import Optional, Tuple
import concurrent.futures

class MemoryOptimizer:
    """内存优化管理器"""
    def __init__(self, max_mem_mb=4096):
        self.max_mem = max_mem_mb * 1024 * 1024
        self.chunk_sizes = {
            500: 256,
            1000: 128,
            1500: 64,
            2000: 32
        }
    
    def get_chunk_size(self, matrix_size):
        """根据矩阵大小动态调整分块大小"""
        for size, chunk in sorted(self.chunk_sizes.items()):
            if matrix_size <= size:
                return chunk
        return 16  # 默认最小分块

    def memory_safe(self):
        """检查系统内存是否安全"""
        try:
            import psutil
            avail = psutil.virtual_memory().available
            return avail > self.max_mem * 0.3  # 保留30%余量
        except:
            return True  # 无psutil时默认安全

mem_optimizer = MemoryOptimizer()

def generate_matrix_chunked(seed: int, size: int) -> np.ndarray:
    """分块生成矩阵避免内存峰值"""
    chunk_size = mem_optimizer.get_chunk_size(size)
    matrix = np.zeros((size, size), dtype=np.float32)  # 使用float32节省内存
    
    for i in range(0, size, chunk_size):
        for j in range(0, size, chunk_size):
            np.random.seed(seed + i + j)
            chunk = np.random.uniform(1, 1000, (chunk_size, chunk_size))
            matrix[i:i+chunk_size, j:j+chunk_size] = chunk
            del chunk
            gc.collect()
    
    return matrix

async def safe_matmul(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """内存安全的矩阵乘法"""
    size = a.shape[0]
    chunk_size = mem_optimizer.get_chunk_size(size)
    result = np.zeros((size, size), dtype=np.float32)
    
    for i in range(0, size, chunk_size):
        for j in range(0, size, chunk_size):
            for k in range(0, size, chunk_size):
                if not mem_optimizer.memory_safe():
                    await asyncio.sleep(0.1)
                    gc.collect()
                
                a_chunk = a[i:i+chunk_size, k:k+chunk_size]
                b_chunk = b[k:k+chunk_size, j:j+chunk_size]
                result[i:i+chunk_size, j:j+chunk_size] += np.dot(a_chunk, b_chunk)
                
                del a_chunk, b_chunk
                gc.collect()
    
    return result

async def compute_task(token: str, task_data: dict) -> Optional[Tuple[float, float]]:
    """内存优化的任务处理"""
    seed1, seed2, size = task_data["seed1"], task_data["seed2"], task_data["matrix_size"]
    
    try:
        # 阶段1: 生成矩阵 (分块并行)
        t0 = time.time() * 1000
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            a_future = executor.submit(generate_matrix_chunked, seed1, size)
            b_future = executor.submit(generate_matrix_chunked, seed2, size)
            A, B = await asyncio.gather(
                asyncio.wrap_future(a_future),
                asyncio.wrap_future(b_future)
            )
        
        # 阶段2: 矩阵乘法 (分块异步)
        C = await safe_matmul(A, B)
        
        # 阶段3: 计算结果
        flat_str = ''.join(f"{x:.0f}" for x in C.flat)
        sha256 = hashlib.sha256(flat_str.encode()).hexdigest()
        f = int(int(sha256, 16) % 10**7
        
        t1 = time.time() * 1000
        result_1 = t0 / max(f, 1)  # 避免除零
        result_2 = f / max((t1 - t0), 1)
        
        # 立即释放内存
        del A, B, C, flat_str
        gc.collect()
        
        return result_1, result_2
        
    except Exception as e:
        print(f"[❌] 计算失败 {token[:8]}: {str(e)}")
        return None

async def lightweight_worker(token: str):
    """内存优化的worker"""
    session = aiohttp.ClientSession()
    backoff = 1
    
    while True:
        try:
            # 内存检查
            if not mem_optimizer.memory_safe():
                print(f"[⏳] {token[:8]} 等待内存释放...")
                await asyncio.sleep(backoff)
                backoff = min(backoff * 2, 10)
                continue
                
            backoff = 1
            
            # 获取任务
            headers = {"token": token}
            async with session.post(
                "https://nebulai.network/open_compute/finish/task",
                json={},
                headers=headers,
                timeout=10
            ) as resp:
                data = await resp.json()
                if data.get("code") != 0:
                    await asyncio.sleep(2)
                    continue
                    
                task_data = data['data']
                print(f"[📥] {token[:8]} 获取{task_data['matrix_size']}阶矩阵任务")
                
                # 处理任务
                results = await compute_task(token, task_data)
                if not results:
                    await asyncio.sleep(3)
                    continue
                    
                # 提交结果
                payload = {
                    "result_1": f"{results[0]:.10f}",
                    "result_2": f"{results[1]:.10f}",
                    "task_id": task_data["task_id"]
                }
                async with session.post(
                    "https://nebulai.network/open_compute/finish/task",
                    json=payload,
                    headers=headers,
                    timeout=10
                ) as resp_submit:
                    submit_data = await resp_submit.json()
                    if submit_data.get("code") == 0:
                        print(f"[✅] {token[:8]} 提交成功")
                        await asyncio.sleep(0.5)
                    else:
                        print(f"[❌] {token[:8]} 提交失败: {submit_data}")
                        await asyncio.sleep(2)
                        
        except Exception as e:
            print(f"[⚠️] {token[:8]} 发生错误: {str(e)}")
            await asyncio.sleep(3)
        finally:
            gc.collect()

async def main():
    """入口函数"""
    if not os.path.exists("token.txt"):
        print("请创建token.txt文件并填入访问令牌")
        return
        
    with open("token.txt") as f:
        tokens = [line.strip() for line in f if line.strip()]
        
    if not tokens:
        print("token.txt中没有有效令牌")
        return
        
    # 限制并发worker数量
    semaphore = asyncio.Semaphore(min(4, len(tokens)))
    
    async def limited_worker(token):
        async with semaphore:
            await lightweight_worker(token)
    
    await asyncio.gather(*[limited_worker(token) for token in tokens])

if __name__ == "__main__":
    # 配置NumPy内存策略
    os.environ["NPY_USE_CBLAS"] = "0"
    os.environ["OMP_NUM_THREADS"] = "1"
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[🛑] 程序已停止")
