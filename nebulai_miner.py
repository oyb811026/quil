import hashlib, time, random, aiohttp, asyncio, numpy as np, os
import warnings
from typing import List, Optional, Tuple
import concurrent.futures

# 忽略numpy的RuntimeWarning
warnings.filterwarnings("ignore", category=RuntimeWarning, module="numpy")

def generate_matrix(seed: int, size: int) -> np.ndarray:
    matrix = np.empty((size, size), dtype=np.float64)
    current_seed = seed
    a, b = 0x4b72e682d, 0x2675dcd22
    for i in range(size):
        for j in range(size):
            value = (a * current_seed + b) % 1000
            matrix[i][j] = float(value)
            current_seed = value
    return matrix

def multiply_matrices(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """分块矩阵乘法避免数值溢出问题"""
    n = a.shape[0]
    chunk_size = 512  # 根据内存调整，Mac M4建议512
    c = np.zeros((n, n), dtype=np.float64)
    
    for i in range(0, n, chunk_size):
        for j in range(0, n, chunk_size):
            for k in range(0, n, chunk_size):
                i_end = min(i + chunk_size, n)
                j_end = min(j + chunk_size, n)
                k_end = min(k + chunk_size, n)
                
                a_block = a[i:i_end, k:k_end]
                b_block = b[k:k_end, j:j_end]
                c[i:i_end, j:j_end] += np.dot(a_block, b_block)
    return c

def flatten_matrix(matrix: np.ndarray) -> str:
    return ''.join(f"{x:.0f}" for x in matrix.flat)

async def compute_hash_mod(matrix: np.ndarray, mod: int = 10**7) -> int:
    flat_str = flatten_matrix(matrix)
    sha256 = hashlib.sha256(flat_str.encode()).hexdigest()
    return int(int(sha256, 16) % mod)

async def fetch_task(session: aiohttp.ClientSession, token: str) -> Tuple[dict, bool]:
    headers = {"Content-Type": "application/json", "token": token}
    try:
        async with session.post("https://nebulai.network/open_compute/finish/task", json={}, headers=headers, timeout=10) as resp:
            data = await resp.json()
            if data.get("code") == 0:
                print(f"[📥] Task OK for {token[:8]} (size: {data['data']['matrix_size']})")
                return data['data'], True
            return None, False
    except Exception as e:
        print(f"[⚠️] Fetch error for {token[:8]}: {str(e)}")
        return None, False

async def submit_results(session: aiohttp.ClientSession, token: str, r1: float, r2: float, task_id: str) -> bool:
    headers = {"Content-Type": "application/json", "token": token}
    payload = {"result_1": f"{r1:.10f}", "result_2": f"{r2:.10f}", "task_id": task_id}
    try:
        async with session.post("https://nebulai.network/open_compute/finish/task", json=payload, headers=headers, timeout=10) as resp:
            data = await resp.json()
            if data.get("code") == 0 and data.get("data", {}).get("calc_status", False):
                print(f"[✅] Accepted for {token[:8]}")
                return True
            print(f"[❌] Rejected for {token[:8]}: {data}")
            return False
    except Exception as e:
        print(f"[⚠️] Submit error for {token[:8]}: {str(e)}")
        return False

async def process_task(token: str, task_data: dict) -> Optional[Tuple[float, float]]:
    seed1, seed2, size = task_data["seed1"], task_data["seed2"], task_data["matrix_size"]
    try:
        with concurrent.futures.ThreadPoolExecutor() as executor:
            t0 = time.time() * 1000
            A_future = executor.submit(generate_matrix, seed1, size)
            B_future = executor.submit(generate_matrix, seed2, size)
            A, B = await asyncio.gather(
                asyncio.wrap_future(A_future),
                asyncio.wrap_future(B_future)
            )
        C = multiply_matrices(A, B)
        f = await compute_hash_mod(C)
        t1 = time.time() * 1000
        
        # 避免除零错误
        time_diff = t1 - t0
        if time_diff == 0:
            time_diff = 1e-9  # 微小值避免除零
        
        result_1 = t0 / f
        result_2 = f / time_diff
        
        return result_1, result_2
    except Exception as e:
        print(f"[❌] Compute error: {str(e)}")
        return None

async def worker_loop(token: str):
    async with aiohttp.ClientSession() as session:
        while True:
            task_data, success = await fetch_task(session, token)
            if not success:
                await asyncio.sleep(2)
                continue
            
            results = await process_task(token, task_data)
            if not results:
                await asyncio.sleep(1)
                continue
            
            submitted = await submit_results(session, token, results[0], results[1], task_data["task_id"])
            await asyncio.sleep(0.5 if submitted else 3)

async def main():
    if not os.path.exists("token.txt"):
        print("token.txt not found!")
        return
    
    with open("token.txt") as f:
        tokens = [line.strip() for line in f if line.strip()]
    
    if not tokens:
        print("No tokens in token.txt!")
        return
    
    # 限制并发任务数避免内存溢出
    semaphore = asyncio.Semaphore(4)  # 根据CPU核心数调整
    
    async def limited_worker(token):
        async with semaphore:
            await worker_loop(token)
    
    await asyncio.gather(*(limited_worker(token) for token in tokens))

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[⛔] Stopped by user")
