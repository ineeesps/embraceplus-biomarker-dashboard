import os
import sys
import unittest
from fastapi.testclient import TestClient

# Añadir el directorio raíz del backend al path para poder importar backend.main
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from backend.main import app

class TestEmbraceDashboardAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_login_success(self):
        """Verifica que el inicio de sesión del investigador alberto retorne sus pacientes asignados"""
        response = self.client.post("/login", json={"username": "alberto", "password": "123"})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("participantes_asignados", data)
        self.assertIn("HN", data["participantes_asignados"])

    def test_login_invalid_credentials(self):
        """Verifica que credenciales incorrectas retornen código 401"""
        response = self.client.post("/login", json={"username": "bad_user", "password": "bad_password"})
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "Credenciales inválidas")

    def test_get_participants_summary(self):
        """Verifica la obtención del resumen clínico de los participantes asignados a un investigador"""
        response = self.client.get("/investigador/alberto/resumen_participantes")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("participantes", data)
        participants = data["participantes"]
        self.assertTrue(len(participants) > 0)
        hn_list = [p for p in participants if p["id"] == "HN"]
        self.assertEqual(len(hn_list), 1)
        self.assertEqual(hn_list[0]["id"], "HN")
        self.assertIn("status", hn_list[0])

    def test_get_metrics(self):
        """Verifica la obtención y empaquetamiento temporal (time_bucket) de las señales biomédicas"""
        response = self.client.get(
            "/participante/HN/metricas",
            params={
                "investigador": "alberto",
                "bucket_size": "30 seconds",
                "start": "2026-05-15T00:00:00Z",
                "end": "2026-05-15T02:00:00Z"
            }
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("metricas", data)

    def test_export_participant_csv(self):
        """Verifica el motor de alineamiento e imputación en servidor y la exportación a CSV limpio"""
        response = self.client.get(
            "/participante/HN/exportar",
            params={
                "investigador": "alberto",
                "bucket_size": "1 minute",
                "method": "linear",
                "start": "2026-05-15T00:00:00Z",
                "end": "2026-05-15T01:00:00Z"
            }
        )
        self.assertEqual(response.status_code, 200)
        csv_content = response.text
        self.assertIn("timestamp", csv_content)
        self.assertIn("temperature", csv_content)
        # Debe contener columnas alineadas
        self.assertTrue(len(csv_content.splitlines()) > 1)

    def test_nonexistent_participant(self):
        """Verifica que un participante inexistente retorne una lista de métricas vacía de forma segura"""
        response = self.client.get("/participante/INVENTADO/metricas", params={"investigador": "alberto"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["metricas"], [])

    def test_crud_lifecycle(self):
        """Verifica el ciclo de vida completo de un participante: Carga (Upload), Renombrado y Eliminación (DELETE)"""
        # Generar un CSV válido de temperatura de EmbracePlus con al menos 100 registros fisiológicos
        csv_rows = ["time,temperature_celsius,quality_flag"]
        base_time = 1778900000
        for i in range(105):
            time_str = f"2026-05-18T12:{i//60:02d}:{i%60:02d}Z"
            csv_rows.append(f"{time_str},36.{5 + (i%3)},good")
        csv_data = "\n".join(csv_rows) + "\n"
        
        files = {"file": ("temperature.csv", csv_data, "text/csv")}
        
        response = self.client.post(
            "/participante/TEST_CRUD_USER/cargar",
            params={"investigador": "alberto", "reemplazar": "true"},
            files=files
        )
        self.assertEqual(response.status_code, 200, msg=response.text)
        data = response.json()
        self.assertEqual(data["status"], "success")

        # 2. Renombrar el participante de prueba
        response = self.client.put(
            "/participante/TEST_CRUD_USER/renombrar",
            params={"nuevo_id": "TEST_CRUD_USER_NEW", "investigador": "alberto"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "success")

        # 3. Eliminar el participante de prueba y limpiar la base de datos
        response = self.client.delete(
            "/participante/TEST_CRUD_USER_NEW",
            params={"investigador": "alberto", "confirmar": "true"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "success")

if __name__ == "__main__":
    unittest.main()
