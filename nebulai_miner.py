import hashlib, time, random, aiohttp, asyncio, numpy as np, os
import warnings
from typing import List, Optional, Tuple
import concurrent.futures

# 忽略numpy的RuntimeWarning，防止警告信息干扰输出
warnings.filterwarnings("ignore", category=RuntimeWarning, module="numpy")

def generate_matrix(seed: int, size: int) -> np.ndarray:
    """生成指定大小的矩阵
    Args:
        seed: 随机种子
        size: 矩阵大小 (size x size)
    Returns:
        生成的矩阵
    """
    matrix = np.empty((size, size), dtype=np.float64)
    current_seed = seed
    # 使用固定系数确保矩阵生成的可重复性
    a, b = 0x4b72e682d, 0x2675dcd22
    for i in range(size):
        for j in range(size):
            # 使用线性同余算法生成矩阵元素值
            value = (a * current_seed + b) % 1000
            matrix[i][j] = float(value)
            current_seed = value
    return matrix

def multiply_matrices(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """分块矩阵乘法避免数值溢出问题
    Args:
        a: 第一个矩阵
        b: 第二个矩阵
    Returns:
        矩阵乘积结果
    """
    n = a.shape[0]
    chunk_size = 512  # 分块大小，根据内存调整（Mac M4建议512）
    c = np.zeros((n, n), dtype=np.float64)  # 结果矩阵
    
    # 三重循环实现分块矩阵乘法
    for i in range(0, n, chunk_size):
        for j in range(0, n, chunk_size):
            for k in range(0, n, chunk_size):
                # 计算当前块的结束位置
                i_end = min(i + chunk_size, n)
                j_end = min(j + chunk_size, n)
                k_end = min(k + chunk_size, n)
                
                # 提取当前子矩阵块
                a_block = a[i:i_end, k:k_end]
                b_block = b[k:k_end, j:j_end]
                
                # 计算子矩阵乘积并累加到结果矩阵
                c[i:i_end, j:j_end] += np.dot(a_block, b_block)
    return c

def flatten_matrix(matrix: np.ndarray) -> str:
    """将矩阵扁平化为字符串
    Args:
        matrix: 输入矩阵
    Returns:
        扁平化后的字符串表示
    """
    return ''.join(f"{x:.0f}" for x in matrix.flat)

async def compute_hash_mod(matrix: np.ndarray, mod: int = 10**7) -> int:
    """计算矩阵的SHA256哈希模值
    Args:
        matrix: 输入矩阵
        mod: 模数 (默认10^7)
    Returns:
        哈希模值
    """
    flat_str = flatten_matrix(matrix)
    sha256 = hashlib.sha256(flat_str.encode()).hexdigest()
    return int(int(sha256, 16) % mod)

async def fetch_task(session: aiohttp.ClientSession, token: str) -> Tuple[dict, bool]:
    """从服务器获取计算任务
    Args:
        session: aiohttp会话对象
        token: 用户认证令牌
    Returns:
        (任务数据, 是否成功)
    """
    headers = {"Content-Type": "application/json", "token": token}
    try:
        async with session.post("https://nebulai.network/open_compute/finish/task", 
                                json={}, headers=headers, timeout=10) as resp:
            data = await resp.json()
            if data.get("code") == 0:
                print(f"[📥] 任务获取成功 {token[:8]} (矩阵大小: {data['data']['matrix_size']})")
                return data['data'], True
            return None, False
    except Exception as e:
        print(f"[⚠️] 任务获取失败 {token[:8]}: {str(e)}")
        return None, False

async def submit_results(session: aiohttp.ClientSession, token: str, 
                         r1: float, r2: float, task_id: str) -> bool:
    """向服务器提交计算结果
    Args:
        session: aiohttp会话对象
        token: 用户认证令牌
        r1: 计算结果1
        r2: 计算结果2
        task_id: 任务ID
    Returns:
        提交是否成功
    """
    headers = {"Content-Type": "application/json", "token": token}
    payload = {
        "result_1": f"{r1:.10f}", 
        "result_2": f"{r2:.10f}", 
        "task_id": task_id
    }
    try:
        async with session.post("https://nebulai.network/open_compute/finish/task", 
                                json=payload, headers=headers, timeout=10) as resp:
            data = await resp.json()
            if data.get("code") == 0 and data.get("data", {}).get("calc_status", False):
                print(f"[✅] 结果提交成功 {token[:8]}")
                return True
            print(f"[❌] 结果被拒绝 {token[:8]}: {data}")
            return False
    except Exception as e:
        print(f"[⚠️] 提交失败 {token[:8]}: {str(e)}")
        return False

async def process_task(token: str, task_data: dict) -> Optional[Tuple[float, float]]:
    """处理单个计算任务
    Args:
        token: 用户认证令牌
        task_data: 任务数据
    Returns:
        (计算结果1, 计算结果2) 或 None（处理失败时）
    """
    seed1, seed2, size = task_data["seed1"], task_data["seed2"], task_data["matrix_size"]
    try:
        # 使用线程池并行生成两个矩阵
        with concurrent.futures.ThreadPoolExecutor() as executor:
            t0 = time.time() * 1000  # 记录开始时间（毫秒）
            A_future = executor.submit(generate_matrix, seed1, size)
            B_future = executor.submit(generate_matrix, seed2, size)
            A, B = await asyncio.gather(
                asyncio.wrap_future(A_future),
                asyncio.wrap_future(B_future)
            )
        
        # 计算矩阵乘积和哈希
        C = multiply_matrices(A, B)
        f = await compute_hash_mod(C)
        t1 = time.time() * 1000  # 记录结束时间（毫秒）
        
        # 避免除零错误
        time_diff = t1 - t0
        if time_diff == 0:
            time_diff = 1e-9  # 微小值避免除零
        
        # 计算最终结果
        result_1 = t0 / f
        result_2 = f / time_diff
        
        return result_1, result_2
    except Exception as e:
        print(f"[❌] 计算错误: {str(e)}")
        return None

async def worker_loop(token: str):
    """单个token的工作循环
    Args:
        token: 用户认证令牌
    """
    async with aiohttp.ClientSession() as session:
        while True:
            # 1. 获取任务
            task_data, success = await fetch_task(session, token)
            if not success:
                await asyncio.sleep(2)  # 失败后短暂等待重试
                continue
            
            # 2. 处理任务
            results = await process_task(token, task_data)
            if not results:
                await asyncio.sleep(1)  # 计算失败后短暂等待
                continue
            
            # 3. 提交结果
            submitted = await submit_results(
                session, token, results[0], results[1], task_data["task_id"])
            
            # 根据提交结果调整等待时间
            await asyncio.sleep(0.5 if submitted else 3)

async def main():
    """主函数：启动所有工作循环"""
    # 检查token文件是否存在
    if not os.path.exists("token.txt"):
        print("未找到token.txt文件!")
        return
    
    # 读取所有token
    with open("token.txt") as f:
        tokens = [line.strip() for line in f if line.strip()]
    
    if not tokens:
        print("token.txt中没有有效的token!")
        return
    
    # 创建信号量限制并发任务数（防止内存溢出）
    semaphore = asyncio.Semaphore(4)  # 根据CPU核心数调整（Mac M4建议4-8）
    
    async def limited_worker(token):
        """带并发限制的工作函数"""
        async with semaphore:
            await worker_loop(token)
    
    # 启动所有工作循环
    await asyncio.gather(*(limited_worker(token) for token in tokens))

if __name__ == "__main__":
    try:
        # 启动主异步循环
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[⛔] 用户中断程序")
