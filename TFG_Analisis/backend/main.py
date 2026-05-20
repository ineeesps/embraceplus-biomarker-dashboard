from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from typing import Optional
import psycopg2
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel
import pandas as pd
import asyncio
import io
import os
import sys
import math

dir_actual = os.path.dirname(os.path.abspath(__file__))
ruta_scripts = os.path.join(dir_actual, '..', 'scripts')
sys.path.append(ruta_scripts)

from cargar_datos import cargar_csv_a_timescale  # type: ignore

app = FastAPI(
    title="EmbracePlus API - Plataforma de Gestión de Biomarcadores",
    description="API para la ingesta, gestión y consulta de datos clínicos procedentes de dispositivos EmbracePlus.",
    version="2.1.0"
)

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "tfg_embrace"),
    "user": os.getenv("DB_USER", "ines"),
    "password": os.getenv("DB_PASSWORD", "tfg_password"),
    "port": os.getenv("DB_PORT", "5433"),
    "connect_timeout": 10,
}

PATRONES_SENSORES = {
    'temperature': 'temperature', 
    'eda': 'eda', 
    'pulse-rate': 'pulse_rate', 'pulse_rate': 'pulse_rate',
    'respiratory-rate': 'respiratory_rate', 'respiratory_rate': 'respiratory_rate',
    'accelerometers-std': 'accelerometer_std', 'accelerometer_std': 'accelerometer_std',
    'prv': 'prv', 
    'step-counts': 'step_count', 'step_count': 'step_count',
    'met': 'met',
    'spo2': 'spo2',
    'activity-intensity': 'activity_intensity', 'activity_intensity': 'activity_intensity',
    'wearing-detection': 'wearing_detection', 'wearing_detection': 'wearing_detection',
    'activity-classification': 'activity_class', 'activity_class': 'activity_class',
    'activity-counts': 'activity_counts', 'activity_counts': 'activity_counts',
    'actigraphy-counts': 'actigraphy_vector', 'actigraphy_vector': 'actigraphy_vector',
    'body-position': 'body_position', 'body_position': 'body_position',
    'acticounts': 'acticounts_total', 
    'sleep-detection': 'sleep_detection', 'sleep_detection': 'sleep_detection',
    'acticounts_x': 'acticounts_x', 'acticounts_y': 'acticounts_y', 'acticounts_z': 'acticounts_z'
}

import bcrypt

BUCKET_SIZES_PERMITIDOS = {
    '30 seconds', '1 minute', '2 minutes', '5 minutes',
    '10 minutes', '15 minutes', '30 minutes', '1 hour'
}

class LoginRequest(BaseModel):
    username: str
    password: str

INVESTIGADORES = {
    "alberto": {"password": "123"},
    "ines":    {"password": "123"},
}

def seed_database():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS usuarios (
                id SERIAL PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL CHECK (role IN ('admin', 'investigador')),
                participantes_asignados TEXT[] NOT NULL DEFAULT '{}',
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                last_login TIMESTAMPTZ,
                nombre_completo TEXT
            );
        """)
        
        alberto_parts = ["HN", "PRUEBA 1", "PRUEBA 2"]
        ines_parts = [f"user{i}" for i in range(1, 21)]

        default_users = [
            ("admin", bcrypt.hashpw(b"admin123", bcrypt.gensalt()).decode('utf-8'), "admin", "Administrador del Sistema", []),
            ("alberto", bcrypt.hashpw(b"123", bcrypt.gensalt()).decode('utf-8'), "investigador", "Alberto Durán", alberto_parts),
            ("ines", bcrypt.hashpw(b"123", bcrypt.gensalt()).decode('utf-8'), "investigador", "Inés Pleguezuelos", ines_parts)
        ]
        
        cur.execute("SELECT COUNT(*) FROM usuarios;")
        count = cur.fetchone()[0]
        if count == 0:
            for username, pwd_hash, role, nombre, parts in default_users:
                cur.execute("""
                    INSERT INTO usuarios (username, password_hash, role, nombre_completo, participantes_asignados)
                    VALUES (%s, %s, %s, %s, %s);
                """, (username, pwd_hash, role, nombre, parts))
        else:
            cur.execute("UPDATE usuarios SET nombre_completo = 'Alberto Durán', participantes_asignados = %s WHERE username = 'alberto';", (alberto_parts,))
            cur.execute("UPDATE usuarios SET nombre_completo = 'Inés Pleguezuelos', participantes_asignados = %s WHERE username = 'ines';", (ines_parts,))
        
        conn.commit()
        cur.close()
        conn.close()
        print("Database schema 'usuarios' initialized and seeded successfully.")
    except Exception as e:
        print(f"Error seeding database: {e}")

seed_database()

@app.on_event("startup")
async def startup_event():
    seed_database()

async def check_investigador_valido(username: str) -> bool:
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SELECT id FROM usuarios WHERE username = %s AND is_active = TRUE;", (username,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return row is not None
    except Exception:
        return False

async def get_lista_participantes_db(username: str):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SELECT participantes_asignados FROM usuarios WHERE username = %s AND is_active = TRUE;", (username,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        if row:
            return sorted(list(row[0]))
        return []
    except Exception as e:
        print(f"Error fetching assigned participants: {e}")
        return []

def agregar_participante_asignado(username: str, participant_id: str):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("""
            UPDATE usuarios 
            SET participantes_asignados = ARRAY(
                SELECT DISTINCT unnest(array_append(participantes_asignados, %s))
            )
            WHERE username = %s;
        """, (participant_id, username))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error updating assigned participants: {e}")

def renombrar_participante_asignado(username: str, old_id: str, new_id: str):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("""
            UPDATE usuarios 
            SET participantes_asignados = ARRAY(
                SELECT DISTINCT CASE WHEN val = %s THEN %s ELSE val END 
                FROM unnest(participantes_asignados) AS val
            )
            WHERE username = %s;
        """, (old_id, new_id, username))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error renaming assigned participant: {e}")

def eliminar_participante_asignado(username: str, participant_id: str):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("""
            UPDATE usuarios 
            SET participantes_asignados = array_remove(participantes_asignados, %s)
            WHERE username = %s;
        """, (participant_id, username))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error removing assigned participant: {e}")


def sincronizar_participantes_investigador(cur, username: str, nuevos_participantes: list[str]):
    # 1. Obtener la lista actual de participantes asignados a este investigador
    cur.execute("SELECT participantes_asignados FROM usuarios WHERE username = %s;", (username,))
    row = cur.fetchone()
    viejos_participantes = list(row[0]) if (row and row[0]) else []

    # 2. Desasignar los participantes que ya no están en la lista
    for p in viejos_participantes:
        if p not in nuevos_participantes:
            cur.execute("UPDATE biomarcadores SET investigador = NULL WHERE participant_id = %s AND investigador = %s;", (p, username))

    # 3. Asignar los nuevos participantes
    for p in nuevos_participantes:
        cur.execute("UPDATE biomarcadores SET investigador = %s WHERE participant_id = %s;", (username, p))
        cur.execute("""
            UPDATE usuarios 
            SET participantes_asignados = array_remove(participantes_asignados, %s) 
            WHERE username != %s;
        """, (p, username))


@app.post("/login")
async def login(req: LoginRequest):
    """
    Autenticación de investigadores y obtención de participantes asignados.
    """
    user = req.username
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM usuarios WHERE username = %s AND is_active = TRUE;", (user,))
        db_user = cur.fetchone()
        if db_user:
            hashed = db_user['password_hash']
            if bcrypt.checkpw(req.password.encode('utf-8'), hashed.encode('utf-8')):
                cur.execute("UPDATE usuarios SET last_login = NOW() WHERE id = %s;", (db_user['id'],))
                conn.commit()
                cur.close()
                conn.close()
                return {
                    "status": "success",
                    "username": db_user['username'],
                    "role": db_user['role'],
                    "participantes_asignados": list(db_user['participantes_asignados'])
                }
        if cur:
            cur.close()
        if conn:
            conn.close()
    except Exception as e:
        print(f"Login error: {e}")
        pass

    raise HTTPException(status_code=401, detail="Credenciales inválidas")

@app.get("/participantes/{username}")
async def get_participantes(username: str):
    if not await check_investigador_valido(username):
        raise HTTPException(status_code=404, detail="Investigador no encontrado")
    
    participantes = await get_lista_participantes_db(username)
    return {"investigador": username, "participantes": participantes}

@app.get("/")
async def root():
    return {"status": "online", "modulo": "API TFG"}

@app.get("/health")
async def health():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.close()
        return {"status": "ok", "db": "connected"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "error", "db": "disconnected"})

@app.get("/investigador/{username}/resumen_participantes")
async def resumen_participantes(username: str):
    """
    Calcula las estadísticas vitales de los participantes de un investigador.
    """
    if not await check_investigador_valido(username):
        raise HTTPException(status_code=404, detail="Investigador no autorizado")
        
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                participant_id as id,
                MIN(time) as start_date,
                MAX(time) as end_date,
                SUM(CASE WHEN sensor_type = 'wearing_detection' AND quality_flag NOT LIKE 'device_not%%' THEN 1 ELSE 0 END)::float / 
                GREATEST(SUM(CASE WHEN sensor_type = 'wearing_detection' THEN 1 ELSE 0 END), 1) * 100 as compliance
            FROM biomarcadores
            WHERE investigador = %s
            GROUP BY participant_id
        """
        
        cur.execute(query, (username,))
        res = cur.fetchall()
        
        participantes_data = []
        meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
        
        for row in res:
            start = row['start_date']
            end = row['end_date']
            
            total_hours = 0
            fecha_str = "Sin datos"
            if start and end:
                diff = end - start
                total_hours = int(diff.total_seconds() / 3600)
                fecha_str = f"{start.day} {meses[start.month - 1]} - {end.day} {meses[end.month - 1]}"
            
            comp = row['compliance'] or 0.0
            status = 'ÓPTIMO' if comp >= 90 else ('REVISIÓN' if comp >= 70 else 'CRÍTICO')
                
            participantes_data.append({
                "id": row['id'],
                "compliance": round(comp, 2),
                "status": status,
                "dateRange": fecha_str,
                "totalHours": max(total_hours, 1)
            })

        participantes_data.sort(key=lambda x: x["id"])
        
        cur.close()
        conn.close()
        return {"investigador": username, "participantes": participantes_data}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/participante/{id}/cargar")
async def cargar_archivo_automatico(id: str, investigador: Optional[str] = None, reemplazar: bool = False, file: UploadFile = File(...)):
    """
    Endpoint para la subida de archivos CSV.
    Realiza la validación del sensor y delega la ingesta al motor ETL.
    """
    if not investigador:
        raise HTTPException(status_code=400, detail="El parámetro 'investigador' es obligatorio.")
    if await check_investigador_valido(investigador):
        conn = None
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            cur = conn.cursor()
            cur.execute(
                "SELECT 1 FROM biomarcadores WHERE participant_id = %s AND investigador != %s LIMIT 1",
                (id, investigador)
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=409,
                    detail=f"El identificador '{id}' ya está en uso por otro investigador."
                )
        except psycopg2.Error:
            pass
        finally:
            if conn:
                conn.close()

    nombre_archivo = file.filename.lower()
    sensor_detectado = next((v for k, v in PATRONES_SENSORES.items() if k in nombre_archivo), None)
    
    if not sensor_detectado:
        raise HTTPException(status_code=400, detail="Tipo de sensor no reconocido")

    if reemplazar:
        conn = None
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            cur = conn.cursor()
            sensores_a_borrar = (
                ('acticounts_total', 'acticounts_x', 'acticounts_y', 'acticounts_z')
                if sensor_detectado == 'acticounts_total'
                else (sensor_detectado,)
            )
            for st in sensores_a_borrar:
                cur.execute(
                    "DELETE FROM biomarcadores WHERE participant_id = %s AND sensor_type = %s AND investigador = %s",
                    (id, st, investigador)
                )
            conn.commit()
            cur.close()
        except Exception as e:
            if conn:
                conn.rollback()
            raise HTTPException(status_code=500, detail=f"Error al eliminar datos previos: {e}")
        finally:
            if conn:
                conn.close()

    try:
        contenido = await file.read()
        df = pd.read_csv(io.BytesIO(contenido), low_memory=False)
        
        if len(df) < 100:
            raise HTTPException(status_code=400, detail="Fichero insuficiente o sin datos")

        ruta_data = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data')
        os.makedirs(ruta_data, exist_ok=True)

        ruta_temp = os.path.join(ruta_data, file.filename)
        with open(ruta_temp, "wb") as f:
            f.write(contenido)
        try:
            resultado = cargar_csv_a_timescale(file.filename, sensor_detectado, id, investigador=investigador)
        finally:
            if os.path.exists(ruta_temp):
                os.remove(ruta_temp)

        total_filas = len(df)
        if 'missing_value_reason' in df.columns:
            df_invalidas = df[df['missing_value_reason'].notnull() & (df['missing_value_reason'] != '')]
            porcentaje_perdida = (len(df_invalidas) / total_filas * 100) if total_filas > 0 else 0
        else:
            porcentaje_perdida = 0.0
        alerta_integridad = porcentaje_perdida > 5.0

        mensaje = "Carga completada"
        if alerta_integridad:
            mensaje += f" (Pérdida de datos: {porcentaje_perdida:.2f}%)"

        # Sincronización in base de datos
        agregar_participante_asignado(investigador, id)

        return {
            "status": "success",
            "participante": id,
            "sensor": sensor_detectado,
            "filas_insertadas": resultado.get('inserted', total_filas),
            "porcentaje_perdida_datos": round(porcentaje_perdida, 2),
            "alerta_integridad_comprometida": alerta_integridad,
            "mensaje": mensaje
        }

    except HTTPException as http_e:
        raise http_e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")

@app.get("/participante/{id}/sensor/{sensor_type}/existe")
async def verificar_existencia_sensor(id: str, sensor_type: str, investigador: str):
    """
    Verifica si ya existen registros para un sensor y participante específico.
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()

        if sensor_type not in PATRONES_SENSORES.values():
            sensor_type = PATRONES_SENSORES.get(sensor_type, sensor_type)

        cur.execute(
            "SELECT 1 FROM biomarcadores WHERE participant_id = %s AND sensor_type = %s AND investigador = %s LIMIT 1",
            (id, sensor_type, investigador)
        )
        existe = cur.fetchone() is not None
        
        cur.close()
        conn.close()
        
        return {"id": id, "sensor_type": sensor_type, "existe": existe}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/participante/{id}/kpis_globales")
async def kpis_globales(id: str, investigador: str):
    """
    Obtiene los KPIs globales históricos (sin filtros temporales) para un participante.
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)

        # Pasos totales
        cur.execute("SELECT SUM(value) as val FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND sensor_type = 'step_count'", (id, investigador))
        pasos = cur.fetchone()['val']

        # FC Media
        cur.execute("SELECT AVG(value) as val FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND sensor_type = 'pulse_rate'", (id, investigador))
        fc = cur.fetchone()['val']

        # Estrés Medio
        cur.execute("SELECT AVG(value) as val FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND sensor_type = 'eda'", (id, investigador))
        estres = cur.fetchone()['val']

        # Horas de Sueño
        cur.execute("""
            SELECT COUNT(*) as val FROM (
                SELECT time_bucket('1 minute', time) as b, mode() WITHIN GROUP (ORDER BY value) as v 
                FROM biomarcadores 
                WHERE participant_id = %s AND investigador = %s AND sensor_type = 'sleep_detection' 
                GROUP BY b
            ) sub WHERE v > 0
        """, (id, investigador))
        sleep_minutes = cur.fetchone()['val'] or 0
        horas_sueno = sleep_minutes / 60.0

        # Compliance
        cur.execute("""
            SELECT 
                SUM(CASE WHEN quality_flag NOT LIKE '%%device_not%%' THEN 1 ELSE 0 END)::float / 
                GREATEST(COUNT(*), 1) * 100 as compliance
            FROM biomarcadores
            WHERE participant_id = %s AND investigador = %s AND sensor_type = 'wearing_detection'
        """, (id, investigador))
        compliance_val = cur.fetchone()['compliance']

        # Last Activity
        cur.execute("SELECT value FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND sensor_type IN ('activity_class', 'activity_classification') AND value IS NOT NULL ORDER BY time DESC LIMIT 1", (id, investigador))
        row = cur.fetchone()
        last_activity = row['value'] if row else None

        # Last Position
        cur.execute("SELECT value FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND sensor_type IN ('body_position', 'body_position_left') AND value IS NOT NULL ORDER BY time DESC LIMIT 1", (id, investigador))
        row = cur.fetchone()
        last_position = row['value'] if row else None
        
        cur.close()
        conn.close()

        return {
            "participante": id,
            "total_steps": pasos if pasos is not None else None,
            "avg_bpm": int(fc) if fc is not None else None,
            "avg_stress": float(estres) if estres is not None else None,
            "sleep_hours": horas_sueno,
            "compliance_percentage": float(compliance_val) if compliance_val is not None else None,
            "last_activity": last_activity,
            "last_position": last_position
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/participante/{id}/metricas")
async def consultar_datos(id: str, investigador: str, start: str = None, end: str = None, bucket_size: str = '30 seconds'):
    """
    Consulta de series temporales de biomarcadores con agregación dinámica (Downsampling).
    """
    if bucket_size not in BUCKET_SIZES_PERMITIDOS:
        raise HTTPException(status_code=400, detail=f"bucket_size inválido. Valores permitidos: {sorted(BUCKET_SIZES_PERMITIDOS)}")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                time_bucket(CAST(%s AS INTERVAL), time) AS bucket,
                sensor_type,
                CASE 
                    WHEN sensor_type IN ('activity_class', 'activity_intensity', 'body_position', 'sleep_detection') 
                    THEN mode() WITHIN GROUP (ORDER BY value)
                    WHEN sensor_type IN ('step_count', 'acticounts_total')
                    THEN SUM(value)
                    ELSE AVG(value)
                END as value,
                CASE 
                    WHEN COUNT(*) FILTER (WHERE quality_flag LIKE '%%device_not_recording%%') > 0 THEN 'device_not_recording'
                    WHEN COUNT(*) FILTER (WHERE quality_flag LIKE '%%low_signal_quality%%') > 0 THEN 'low_signal_quality'
                    WHEN COUNT(*) FILTER (WHERE quality_flag LIKE '%%motion%%') > 0 THEN 'worn_during_motion'
                    ELSE 'good'
                END as quality_flag
            FROM biomarcadores
            WHERE participant_id = %s AND investigador = %s
        """
        params = [bucket_size, id, investigador]
        if start:
            query += " AND time >= %s"
            params.append(start)
        if end:
            query += " AND time <= %s"
            params.append(end)

        query += " GROUP BY bucket, sensor_type ORDER BY bucket ASC"
        
        cur.execute(query, tuple(params))
        res = cur.fetchall()
        for row in res:
            row['time'] = row['bucket'].isoformat()
            del row['bucket']
            val = row.get('value')
            if val is not None and isinstance(val, float) and (math.isnan(val) or math.isinf(val)):
                row['value'] = None
        
        cur.close()
        conn.close()
        
        return {
            "participante": id, 
            "total_registros": len(res), 
            "metricas": res
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/participante/{id}")
async def eliminar_participante(id: str, investigador: str, confirmar: bool = False):
    """
    Eliminación completa de un participante y sus registros clínicos.
    Requiere confirmar=true para ejecutar el borrado permanente.
    """
    if not confirmar:
        raise HTTPException(
            status_code=400,
            detail="Se requiere el parámetro confirmar=true para eliminar permanentemente los datos del participante."
        )
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        cur.execute("DELETE FROM biomarcadores WHERE participant_id = %s AND investigador = %s", (id, investigador))
        conn.commit()
        
        # Sincronización in base de datos
        eliminar_participante_asignado(investigador, id)

        cur.close()
        conn.close()
        return {"status": "success", "message": f"Participante {id} eliminado correctamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/participante/{id}/renombrar")
async def renombrar_participante(id: str, nuevo_id: str, investigador: str):
    """
    Cambio de identificador de participante manteniendo la integridad de los datos históricos.
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()

        cur.execute("SELECT 1 FROM biomarcadores WHERE participant_id = %s AND investigador = %s LIMIT 1", (nuevo_id, investigador))
        if cur.fetchone() is not None:
            cur.close()
            conn.close()
            raise HTTPException(status_code=409, detail=f"El ID '{nuevo_id}' ya está en uso por otro participante.")

        cur.execute("""
            UPDATE biomarcadores
            SET participant_id = %s
            WHERE participant_id = %s AND investigador = %s
        """, (nuevo_id, id, investigador))
        conn.commit()
        
        # Sincronización in base de datos
        renombrar_participante_asignado(investigador, id, nuevo_id)

        cur.close()
        conn.close()
        return {"status": "success", "new_id": nuevo_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/participante/{id}/metadata")
async def obtener_metadata_participante(id: str, investigador: str):
    """
    Obtiene el rango temporal real y los sensores disponibles para un participante.
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute(
            "SELECT MIN(time) as start_time, MAX(time) as end_time FROM biomarcadores WHERE participant_id = %s AND investigador = %s",
            (id, investigador)
        )
        range_data = cur.fetchone()

        cur.execute(
            "SELECT MIN(time) as active_start, MAX(time) as active_end FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND value IS NOT NULL",
            (id, investigador)
        )
        active_data = cur.fetchone()

        cur.execute(
            "SELECT DISTINCT sensor_type FROM biomarcadores WHERE participant_id = %s AND investigador = %s AND value IS NOT NULL",
            (id, investigador)
        )
        sensors = [row['sensor_type'] for row in cur.fetchall()]
        
        cur.close()
        conn.close()
        
        return {
            "id": id,
            "start_time": range_data['start_time'].isoformat() if range_data['start_time'] else None,
            "end_time": range_data['end_time'].isoformat() if range_data['end_time'] else None,
            "active_start": active_data['active_start'].isoformat() if active_data['active_start'] else None,
            "active_end": active_data['active_end'].isoformat() if active_data['active_end'] else None,
            "sensors": sensors
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

METHODS_PERMITIDOS = {'linear', 'spline', 'ffill'}

@app.get("/participante/{id}/exportar")
async def exportar_datos(
    id: str,
    investigador: str,
    bucket_size: str = '1 minute',
    method: str = 'linear',
    start: Optional[str] = None,
    end: Optional[str] = None
):
    if bucket_size not in BUCKET_SIZES_PERMITIDOS:
        raise HTTPException(status_code=400, detail=f"bucket_size inválido. Valores permitidos: {sorted(BUCKET_SIZES_PERMITIDOS)}")
    if method not in METHODS_PERMITIDOS:
        raise HTTPException(status_code=400, detail=f"method inválido. Valores permitidos: {sorted(METHODS_PERMITIDOS)}")

    conn = None
    df = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        query = """
            SELECT
                time_bucket(CAST(%s AS INTERVAL), time) AS timestamp,
                sensor_type,
                CASE
                    WHEN sensor_type IN ('activity_class', 'activity_intensity', 'body_position', 'sleep_detection')
                    THEN mode() WITHIN GROUP (ORDER BY value)
                    WHEN sensor_type IN ('step_count', 'acticounts_total')
                    THEN SUM(value)
                    ELSE AVG(value)
                END as value
            FROM biomarcadores
            WHERE participant_id = %s AND investigador = %s
        """
        params = [bucket_size, id, investigador]
        if start:
            query += " AND time >= %s"
            params.append(start)
        if end:
            query += " AND time <= %s"
            params.append(end)

        query += """
            GROUP BY timestamp, sensor_type
            ORDER BY timestamp ASC
        """
        df = pd.read_sql_query(query, conn, params=params)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en el módulo de exportación: {str(e)}")
    finally:
        if conn:
            conn.close()

    if df is None or df.empty:
        raise HTTPException(status_code=404, detail="Sin datos")

    df_pivot = df.pivot(index='timestamp', columns='sensor_type', values='value').reset_index()

    VARS_CATEGORICAS = ['activity_class', 'activity_intensity', 'body_position', 'sleep_detection']
    cols_categoricas = [c for c in df_pivot.columns if c in VARS_CATEGORICAS]
    cols_continuas   = [c for c in df_pivot.columns
                        if c not in VARS_CATEGORICAS and pd.api.types.is_numeric_dtype(df_pivot[c])]

    if method == 'spline':
        df_pivot[cols_continuas] = df_pivot[cols_continuas].interpolate(
            method='spline', order=3, limit_direction='both'
        )
    elif method == 'linear':
        df_pivot[cols_continuas] = df_pivot[cols_continuas].interpolate(
            method='linear', limit_direction='both'
        )
    elif method == 'ffill':
        df_pivot[cols_continuas] = df_pivot[cols_continuas].ffill().bfill()

    if cols_categoricas:
        df_pivot[cols_categoricas] = df_pivot[cols_categoricas].ffill().bfill()

    output = io.StringIO()
    df_pivot.to_csv(output, index=False)
    output.seek(0)

    return StreamingResponse(
        output,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename=export_{id}.csv"}
    )

class CreateUserRequest(BaseModel):
    username: str
    password: str
    nombre_completo: str
    role: str = "investigador"
    participantes_asignados: list[str] = []

class ToggleActiveRequest(BaseModel):
    is_active: bool

class UpdateInvestigatorRequest(BaseModel):
    nombre_completo: str
    username: str

@app.get("/admin/investigadores")
async def get_investigadores():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, username, nombre_completo, role, is_active, last_login, participantes_asignados 
            FROM usuarios 
            ORDER BY id ASC;
        """)
        rows = cur.fetchall()
        cur.close()
        conn.close()
        
        res = []
        for r in rows:
            last_login_str = r['last_login'].isoformat() if r['last_login'] else None
            res.append({
                "id": r['id'],
                "username": r['username'],
                "nombre_completo": r['nombre_completo'],
                "role": r['role'],
                "is_active": r['is_active'],
                "last_login": last_login_str,
                "participantes_asignados": list(r['participantes_asignados']),
                "pacientes_count": len(r['participantes_asignados'])
            })
        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/admin/investigadores")
async def create_investigador(req: CreateUserRequest):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        cur.execute("SELECT 1 FROM usuarios WHERE username = %s LIMIT 1;", (req.username,))
        if cur.fetchone() is not None:
            cur.close()
            conn.close()
            raise HTTPException(status_code=400, detail="El nombre de usuario ya está registrado.")
        
        hashed = bcrypt.hashpw(req.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        
        cur.execute("""
            INSERT INTO usuarios (username, password_hash, role, nombre_completo, participantes_asignados)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id;
        """, (req.username, hashed, req.role, req.nombre_completo, req.participantes_asignados))
        
        new_id = cur.fetchone()[0]
        sincronizar_participantes_investigador(cur, req.username, req.participantes_asignados)
        conn.commit()
        cur.close()
        conn.close()
        return {"status": "success", "id": new_id, "message": "Investigador creado con éxito."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/admin/investigadores/{id}/estado")
async def toggle_investigador_estado(id: int, req: ToggleActiveRequest):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("UPDATE usuarios SET is_active = %s WHERE id = %s RETURNING username;", (req.is_active, id))
        row = cur.fetchone()
        if not row:
            cur.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        conn.commit()
        cur.close()
        conn.close()
        return {"status": "success", "username": row[0], "is_active": req.is_active}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/admin/investigadores/{id}/pacientes")
async def update_investigador_pacientes(id: int, req: list[str]):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SELECT username FROM usuarios WHERE id = %s;", (id,))
        row_username = cur.fetchone()
        if not row_username:
            cur.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        username = row_username[0]
        
        sincronizar_participantes_investigador(cur, username, req)
        
        cur.execute("UPDATE usuarios SET participantes_asignados = %s WHERE id = %s;", (req, id))
        conn.commit()
        cur.close()
        conn.close()
        return {"status": "success", "username": username, "participantes_asignados": req}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/admin/investigadores/{id}")
async def update_investigador_details(id: int, req: UpdateInvestigatorRequest):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        # Check if username is taken by another user
        cur.execute("SELECT id FROM usuarios WHERE username = %s AND id != %s;", (req.username, id))
        if cur.fetchone():
            cur.close()
            conn.close()
            raise HTTPException(status_code=400, detail="El nombre de usuario ya está en uso")
            
        cur.execute("SELECT username FROM usuarios WHERE id = %s;", (id,))
        old_user_row = cur.fetchone()
        if not old_user_row:
            cur.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        old_username = old_user_row[0]

        cur.execute("""
            UPDATE usuarios 
            SET nombre_completo = %s, username = %s 
            WHERE id = %s 
            RETURNING id, username, nombre_completo;
        """, (req.nombre_completo, req.username, id))
        row = cur.fetchone()
        
        if old_username != req.username:
            cur.execute("UPDATE biomarcadores SET investigador = %s WHERE investigador = %s;", (req.username, old_username))

        conn.commit()
        cur.close()
        conn.close()
        return {"status": "success", "id": row[0], "username": row[1], "nombre_completo": row[2]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/admin/investigadores/{id}")
async def delete_investigador(id: int):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        # Check if user exists and get username
        cur.execute("SELECT username FROM usuarios WHERE id = %s;", (id,))
        row = cur.fetchone()
        if not row:
            cur.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        username = row[0]
        
        # Don't allow deleting the admin user
        if username == "admin":
            cur.close()
            conn.close()
            raise HTTPException(status_code=400, detail="No se puede eliminar el administrador del sistema")
            
        # Delete from usuarios
        cur.execute("DELETE FROM usuarios WHERE id = %s;", (id,))
        
        # Update biomarcadores to disassociate
        cur.execute("UPDATE biomarcadores SET investigador = NULL WHERE investigador = %s;", (username,))
        
        conn.commit()
        cur.close()
        conn.close()
        return {"status": "success", "message": f"Investigador {username} eliminado correctamente"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



@app.get("/admin/participantes")
async def get_all_participantes():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SELECT DISTINCT participant_id FROM biomarcadores ORDER BY participant_id;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return [row[0] for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))