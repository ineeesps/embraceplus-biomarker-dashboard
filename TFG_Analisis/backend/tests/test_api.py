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

    def test_admin_flow(self):
        """Verifica el flujo completo de administración (RBAC y gestión de investigadores)"""
        # Limpiar usuario de prueba si ya existe
        try:
            import psycopg2
            from backend.main import DB_CONFIG
            conn = psycopg2.connect(**DB_CONFIG)
            cur = conn.cursor()
            cur.execute("DELETE FROM usuarios WHERE username LIKE 'test_admin_investigador%';")
            conn.commit()
            cur.close()
            conn.close()
        except Exception:
            pass

        # 1. Login como administrador
        response = self.client.post("/login", json={"username": "admin", "password": "admin123"})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["role"], "admin")
        self.assertEqual(data["username"], "admin")

        # 2. Obtener lista de investigadores
        response = self.client.get("/admin/investigadores")
        self.assertEqual(response.status_code, 200)
        users = response.json()
        self.assertTrue(len(users) >= 3) # admin, alberto, ines

        # 3. Crear nuevo investigador
        new_user = {
            "username": "test_admin_investigador",
            "password": "secret_password",
            "nombre_completo": "Test Admin Inv",
            "role": "investigador",
            "participantes_asignados": ["HN"]
        }
        response = self.client.post("/admin/investigadores", json=new_user)
        self.assertEqual(response.status_code, 200)
        res_data = response.json()
        self.assertEqual(res_data["status"], "success")
        new_db_id = res_data["id"]

        # 4. Iniciar sesión con el nuevo investigador
        response = self.client.post("/login", json={"username": "test_admin_investigador", "password": "secret_password"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["participantes_asignados"], ["HN"])

        # 4b. Actualizar pacientes asignados
        response = self.client.put(f"/admin/investigadores/{new_db_id}/pacientes", json=["HN", "PRUEBA 1"])
        self.assertEqual(response.status_code, 200)
        
        response = self.client.post("/login", json={"username": "test_admin_investigador", "password": "secret_password"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(sorted(response.json()["participantes_asignados"]), ["HN", "PRUEBA 1"])

        # 4c. Actualizar nombre completo y nombre de usuario
        response = self.client.put(f"/admin/investigadores/{new_db_id}", json={
            "nombre_completo": "Test Admin Inv Modificado",
            "username": "test_admin_investigador_new"
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["nombre_completo"], "Test Admin Inv Modificado")
        self.assertEqual(response.json()["username"], "test_admin_investigador_new")

        # 5. Desactivar temporalmente al investigador
        response = self.client.put(f"/admin/investigadores/{new_db_id}/estado", json={"is_active": False})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["is_active"], False)

        # 6. Intentar iniciar sesión desactivado (debe fallar 401)
        response = self.client.post("/login", json={"username": "test_admin_investigador_new", "password": "secret_password"})
        self.assertEqual(response.status_code, 401)

        # 7. Eliminar al investigador de prueba (debe tener éxito y limpiar la BD)
        response = self.client.delete(f"/admin/investigadores/{new_db_id}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "success")

        # Intentar eliminar de nuevo (debe fallar con 404)
        response = self.client.delete(f"/admin/investigadores/{new_db_id}")
        self.assertEqual(response.status_code, 404)

        # 8. Obtener listado global de participantes
        response = self.client.get("/admin/participantes")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(isinstance(response.json(), list))

    def test_get_participantes_by_investigador(self):
        """Verifica la obtención de participantes asignados a un investigador"""
        response = self.client.get("/participantes/alberto")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["investigador"], "alberto")
        self.assertIn("HN", data["participantes"])

    def test_verificar_existencia_sensor(self):
        """Verifica si un sensor y participante específico existen en la base de datos"""
        response = self.client.get(
            "/participante/HN/sensor/temperature/existe",
            params={"investigador": "alberto"}
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["id"], "HN")
        self.assertEqual(data["sensor_type"], "temperature")
        self.assertEqual(data["existe"], True)

    def test_obtener_metadata_participante(self):
        """Verifica la obtención del rango temporal y sensores de un participante"""
        response = self.client.get(
            "/participante/HN/metadata",
            params={"investigador": "alberto"}
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["id"], "HN")
        self.assertIn("start_time", data)
        self.assertIn("end_time", data)
        self.assertIn("temperature", data["sensors"])

    def test_resumen_participantes_alberto_and_ines(self):
        """Verifica que el resumen de participantes devuelva datos reales y exactos para alberto e ines"""
        # Test alberto
        response_alberto = self.client.get("/investigador/alberto/resumen_participantes")
        self.assertEqual(response_alberto.status_code, 200)
        data_alberto = response_alberto.json()
        self.assertEqual(data_alberto["investigador"], "alberto")
        participantes_alberto = data_alberto["participantes"]
        self.assertEqual(len(participantes_alberto), 3)
        
        # Verificar HN
        hn = next(p for p in participantes_alberto if p["id"] == "HN")
        self.assertEqual(hn["compliance"], 51.11)
        self.assertEqual(hn["dateRange"], "15 May - 16 May")
        self.assertEqual(hn["totalHours"], 47)
        self.assertEqual(hn["status"], "CRÍTICO")

        # Verificar PRUEBA 1
        prueba1 = next(p for p in participantes_alberto if p["id"] == "PRUEBA 1")
        self.assertEqual(prueba1["compliance"], 1.88)
        self.assertEqual(prueba1["dateRange"], "22 Feb - 22 Feb")
        self.assertEqual(prueba1["totalHours"], 23)
        self.assertEqual(prueba1["status"], "CRÍTICO")

        # Test ines
        response_ines = self.client.get("/investigador/ines/resumen_participantes")
        self.assertEqual(response_ines.status_code, 200)
        data_ines = response_ines.json()
        self.assertEqual(data_ines["investigador"], "ines")
        participantes_ines = data_ines["participantes"]
        self.assertEqual(len(participantes_ines), 20)

        # Verificar user1
        user1 = next(p for p in participantes_ines if p["id"] == "user1")
        self.assertEqual(user1["compliance"], 16.11)
        self.assertEqual(user1["dateRange"], "14 Ene - 14 Ene")
        self.assertEqual(user1["totalHours"], 23)
        self.assertEqual(user1["status"], "CRÍTICO")

if __name__ == "__main__":
    unittest.main()
