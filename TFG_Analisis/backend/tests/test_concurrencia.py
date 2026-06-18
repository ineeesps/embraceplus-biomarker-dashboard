import os
import sys
import unittest
import time
import concurrent.futures
from fastapi.testclient import TestClient

# Añadir el directorio raíz del backend al path para poder importar backend.main
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from backend.main import app

class TestConcurrencyAndLoad(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_concurrent_logins(self):
        """Prueba de concurrencia: Simula 20 accesos simultáneos al sistema (/login)"""
        workers = 20
        payload = {"username": "alberto", "password": "123"}
        
        def send_login():
            t_start = time.perf_counter()
            response = self.client.post("/login", json=payload)
            t_end = time.perf_counter()
            return response.status_code, t_end - t_start

        latencies = []
        success_count = 0

        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(send_login) for _ in range(workers)]
            for future in concurrent.futures.as_completed(futures):
                try:
                    status, duration = future.result()
                    latencies.append(duration)
                    if status == 200:
                        success_count += 1
                except Exception as e:
                    print(f"Error en login concurrente: {e}")

        avg_latency = sum(latencies) / len(latencies) if latencies else 0
        print(f"\n[TEST CONCURRENCIA - LOGIN] Simulados: {workers} usuarios concurrentes")
        print(f"  - Tasa de éxito: {success_count}/{workers} ({success_count/workers*100:.1f}%)")
        print(f"  - Latencia media: {avg_latency*1000:.2f} ms")
        print(f"  - Latencia máxima: {max(latencies)*1000:.2f} ms")
        print(f"  - Latencia mínima: {min(latencies)*1000:.2f} ms")

        self.assertEqual(success_count, workers, f"Solo {success_count} de {workers} logins concurrentes tuvieron éxito")

    def test_concurrent_metrics_query(self):
        """Prueba de concurrencia y estrés: Simula 30 peticiones concurrentes de telemetría de gran volumen"""
        workers = 30
        params = {
            "investigador": "alberto",
            "bucket_size": "5 minutes",
            "start": "2026-05-15T00:00:00Z",
            "end": "2026-05-15T06:00:00Z"
        }

        def fetch_metrics():
            t_start = time.perf_counter()
            response = self.client.get("/participante/HN/metricas", params=params)
            t_end = time.perf_counter()
            return response.status_code, t_end - t_start

        latencies = []
        success_count = 0

        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(fetch_metrics) for _ in range(workers)]
            for future in concurrent.futures.as_completed(futures):
                try:
                    status, duration = future.result()
                    latencies.append(duration)
                    if status == 200:
                        success_count += 1
                except Exception as e:
                    print(f"Error en consulta de métricas concurrente: {e}")

        avg_latency = sum(latencies) / len(latencies) if latencies else 0
        print(f"\n[TEST CONCURRENCIA - LECTURA DE MÉTRICAS] Simuladas: {workers} consultas concurrentes")
        print(f"  - Tasa de éxito: {success_count}/{workers} ({success_count/workers*100:.1f}%)")
        print(f"  - Latencia media: {avg_latency*1000:.2f} ms")
        print(f"  - Latencia máxima: {max(latencies)*1000:.2f} ms")
        print(f"  - Latencia mínima: {min(latencies)*1000:.2f} ms")

        self.assertEqual(success_count, workers, f"Solo {success_count} de {workers} consultas concurrentes tuvieron éxito")

    def test_mixed_load_stress_simulation(self):
        """Prueba de estrés de carga mixta: Simula 50 peticiones aleatorias concurrentes de múltiples endpoints"""
        total_requests = 50
        max_workers = 15

        endpoints = [
            ("/login", "POST", {"username": "alberto", "password": "123"}),
            ("/investigador/alberto/resumen_participantes", "GET", None),
            ("/participante/HN/metadata?investigador=alberto", "GET", None),
            ("/participante/HN/metricas?investigador=alberto&bucket_size=1+hour", "GET", None)
        ]

        def send_request(index):
            endpoint, method, payload = endpoints[index % len(endpoints)]
            t_start = time.perf_counter()
            if method == "POST":
                response = self.client.post(endpoint, json=payload)
            else:
                response = self.client.get(endpoint)
            t_end = time.perf_counter()
            return response.status_code, t_end - t_start

        latencies = []
        success_count = 0

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(send_request, i) for i in range(total_requests)]
            for future in concurrent.futures.as_completed(futures):
                try:
                    status, duration = future.result()
                    latencies.append(duration)
                    if status == 200:
                        success_count += 1
                except Exception as e:
                    print(f"Error en petición de estrés concurrente: {e}")

        avg_latency = sum(latencies) / len(latencies) if latencies else 0
        sorted_latencies = sorted(latencies)
        p95_latency = sorted_latencies[int(len(sorted_latencies) * 0.95)] if sorted_latencies else 0

        print(f"\n[TEST STRESS - CARGA MIXTA CONCURRENTE] Simuladas: {total_requests} peticiones concurrentes")
        print(f"  - Hilos de ejecución (Workers): {max_workers}")
        print(f"  - Tasa de éxito: {success_count}/{total_requests} ({success_count/total_requests*100:.1f}%)")
        print(f"  - Latencia media: {avg_latency*1000:.2f} ms")
        print(f"  - Latencia percentil 95 (P95): {p95_latency*1000:.2f} ms")
        print(f"  - Latencia máxima: {max(latencies)*1000:.2f} ms")
        print(f"  - Latencia mínima: {min(latencies)*1000:.2f} ms")

        self.assertEqual(success_count, total_requests, f"Solo {success_count} de {total_requests} peticiones mixtas tuvieron éxito")

if __name__ == "__main__":
    unittest.main()
