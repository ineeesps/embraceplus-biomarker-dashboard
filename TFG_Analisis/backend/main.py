from fastapi import FastAPI, UploadFile, File, HTTPException
import psycopg2
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel
import pandas as pd
import io
import os
import sys

# Configurar path para módulos locales
dir_actual = os.path.dirname(os.path.abspath(__file__))
ruta_scripts = os.path.join(dir_actual, '..', 'scripts')
sys.path.append(ruta_scripts)

from cargar_datos import cargar_csv_a_timescale  # type: ignore

app = FastAPI(
    title="EmbracePlus API - TFG Inés",
    description="Backend integrado con Orquestador de Ingesta",
    version="2.0.0"
)

# Configuración de base de datos (Docker o Local)
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": "tfg_embrace",
    "user": "ines",
    "password": "tfg_password",
    "port": "5432"
}

# Diccionario de patrones
PATRONES_SENSORES = {
    'temperature': 'temperature', 'eda': 'eda', 'pulse-rate': 'pulse_rate',
    'respiratory-rate': 'respiratory_rate', 'accelerometers-std': 'accelerometer_std',
    'prv': 'prv', 'step-counts': 'step_count', 'met': 'met',
    'activity-intensity': 'activity_intensity', 'wearing-detection': 'wearing_detection',
    'activity-classification': 'activity_class', 'activity-counts': 'activity_counts',
    'actigraphy-counts': 'actigraphy_vector', 'body-position': 'body_position',
    'acticounts': 'acticounts_total', 'sleep-detection': 'sleep_detection'
}

# Modelos y mapeo de acceso para el TFG
class LoginRequest(BaseModel):
    username: str
    password: str

INVESTIGADORES = {
    "alberto": {
        "password": "123",
        "participantes": ["PRUEBA 1", "PRUEBA 2"]
    },
    "ines": {
        "password": "123",
        "participantes": [f"user{i}" for i in range(1, 21)]
    }
}

@app.post("/login")
async def login(req: LoginRequest):
    user = req.username
    if user in INVESTIGADORES and INVESTIGADORES[user]["password"] == req.password:
        return {
            "status": "success",
            "username": user,
            "participantes_asignados": INVESTIGADORES[user]["participantes"]
        }
    raise HTTPException(status_code=401, detail="Credenciales incorrectas")

@app.get("/")
async def root():
    return {"status": "online", "modulo": "API TFG Inés"}

@app.get("/health")
async def health():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.close()
        return {"status": "ok", "db": "connected"}
    except:
        return {"status": "error", "db": "disconnected"}

# ==========================================
# ENDPOINT DE RESUMEN CLÍNICO (FRONTEND)
# ==========================================
@app.get("/investigador/{username}/resumen_pacientes")
async def resumen_pacientes(username: str):
    """
    Calcula en tiempo real las estadísticas vitales de todos los pacientes 
    de un investigador para poblar la Pantalla de Selección (Dashboard Inicial).
    """
    if username not in INVESTIGADORES:
        raise HTTPException(status_code=404, detail="Investigador no autorizado")
        
    participantes = INVESTIGADORES[username]["participantes"]
    if not participantes:
        return {"investigador": username, "pacientes": []}
        
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        format_strings = ','.join(['%s'] * len(participantes))
        query = f"""
            SELECT 
                participant_id as id,
                MIN(time) as start_date,
                MAX(time) as end_date,
                SUM(CASE WHEN quality_flag NOT LIKE 'device_not%%' THEN 1 ELSE 0 END)::float / GREATEST(COUNT(*), 1) * 100 as compliance
            FROM biomarcadores
            WHERE participant_id IN ({format_strings})
            GROUP BY participant_id
        """
        
        cur.execute(query, tuple(participantes))
        res = cur.fetchall()
        
        pacientes_data = []
        meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
        
        for row in res:
            start = row['start_date']
            end = row['end_date']
            
            total_hours = 0
            if start and end:
                diff = end - start
                total_hours = int(diff.total_seconds() / 3600)
            
            comp = row['compliance'] or 0.0
            if comp >= 90:
                status = 'ÓPTIMO'
            elif comp >= 80:
                status = 'REVISIÓN'
            else:
                status = 'CRÍTICO'
                
            fecha_str = "Sin datos"
            if start and end:
                fecha_str = f"{start.day} {meses[start.month - 1]} {start.year} - {end.day} {meses[end.month - 1]} {end.year}"
                
            pacientes_data.append({
                "id": row['id'],
                "compliance": round(comp, 2),
                "status": status,
                "dateRange": fecha_str,
                "totalHours": max(total_hours, 1) # Si grabaron algo, al menos 1 hora para no poner 0
            })
            
        cur.close()
        conn.close()
        
        # Añadir pacientes asignados que aún no han volcado datos a la base de datos
        ids_con_datos = {p["id"] for p in pacientes_data}
        for p_id in participantes:
            if p_id not in ids_con_datos:
                pacientes_data.append({
                    "id": p_id,
                    "compliance": 0.0,
                    "status": "CRÍTICO",
                    "dateRange": "Sin registros",
                    "totalHours": 0
                })
                
        pacientes_data.sort(key=lambda x: x["id"])
        return {"investigador": username, "pacientes": pacientes_data}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# ENDPOINT DE INGESTA REAL
# ==========================================
@app.post("/participante/{id}/cargar")
async def cargar_archivo_automatico(id: str, investigador: str = None, file: UploadFile = File(...)):
    """
    Recibe el CSV, valida su longitud mínima y delega la inyección a TimescaleDB al motor ETL.
    """
    if investigador and investigador in INVESTIGADORES:
        if id not in INVESTIGADORES[investigador]["participantes"]:
            # Seguridad de Datos: Evitar colisión de IDs entre diferentes investigadores
            # Comprobamos en base de datos si el participante ya existe (registrado previamente o por otro usuario)
            try:
                conn = psycopg2.connect(**DB_CONFIG)
                cur = conn.cursor()
                cur.execute("SELECT 1 FROM biomarcadores WHERE participant_id = %s LIMIT 1", (id,))
                if cur.fetchone() is not None:
                    raise HTTPException(
                        status_code=409, 
                        detail=f"Error de Seguridad: El identificador '{id}' ya está siendo usado por otro paciente en el sistema."
                    )
            except psycopg2.Error:
                pass  # Si hay error temporal de BD, delegamos la responsabilidad a TimescaleDB más adelante
            finally:
                if 'conn' in locals() and conn:
                    conn.close()

            INVESTIGADORES[investigador]["participantes"].append(id)

    nombre_archivo = file.filename.lower()
    sensor_detectado = None

    # Detectar el sensor usando tus patrones
    for patron, sensor in PATRONES_SENSORES.items():
        if patron in nombre_archivo:
            sensor_detectado = sensor
            break
    
    if not sensor_detectado:
        raise HTTPException(status_code=400, detail="Tipo de sensor no reconocido")

    try:
        # Leemos el archivo en memoria para validarlo
        contenido = await file.read()
        df = pd.read_csv(io.BytesIO(contenido), low_memory=False)
        
        # Validación de integridad mínima del CSV (evitar archivos vacíos o incompletos)
        if len(df) <= 751:
            raise HTTPException(status_code=400, detail="Fichero vacío o corrupto: sin datos tras fila 752")

        # Almacenamiento temporal para el procesado del motor ETL
        dir_actual = os.path.dirname(os.path.abspath(__file__))
        ruta_data = os.path.join(dir_actual, '..', 'data')
        os.makedirs(ruta_data, exist_ok=True) 
        
        ruta_temp = os.path.join(ruta_data, file.filename)
        with open(ruta_temp, "wb") as f:
            f.write(contenido)
        
        # Ejecución del adaptador ETL e inserción en base de datos
        cargar_csv_a_timescale(file.filename, sensor_detectado, id)
        
        # Limpieza del archivo temporal
        if os.path.exists(ruta_temp):
            os.remove(ruta_temp)

        # REGLA DEL 5% DE RENDIMIENTO ESENCIAL
        total_filas = len(df)
        df_invalidas = df[df['missing_value_reason'].notnull() & (df['missing_value_reason'] != '')]
        porcentaje_perdida = (len(df_invalidas) / total_filas * 100) if total_filas > 0 else 0
        alerta_integridad = porcentaje_perdida > 5.0

        mensaje_final = "Datos validados e insertados correctamente en TimescaleDB"
        if alerta_integridad:
            mensaje_final += f" (ALERTA: Pérdida de integridad del {porcentaje_perdida:.2f}%)"

        return {
            "status": "success",
            "participante": id,
            "sensor": sensor_detectado,
            "filas_insertadas": total_filas,
            "porcentaje_perdida_datos": round(porcentaje_perdida, 2),
            "alerta_integridad_comprometida": alerta_integridad,
            "mensaje": mensaje_final
        }

    except HTTPException as http_e:
        raise http_e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")

# ==========================================
# ENDPOINTS DE LECTURA Y EXPORTACIÓN
# ==========================================
@app.get("/participante/{id}/metricas")
async def consultar_datos(id: str, start: str = None, end: str = None, bucket_size: str = '30 seconds'):
    """
    Retorna datos resampleados para visualización con filtrado temporal opcional.
    """
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
                    ELSE AVG(value)
                END as value,
                CASE 
                    WHEN COUNT(*) FILTER (WHERE quality_flag LIKE '%%device_not_recording%%') > 0 THEN 'device_not_recording'
                    WHEN COUNT(*) FILTER (WHERE quality_flag LIKE '%%low_signal_quality%%') > 0 THEN 'low_signal_quality'
                    WHEN COUNT(*) FILTER (WHERE quality_flag LIKE '%%motion%%') > 0 THEN 'worn_during_motion'
                    ELSE 'good'
                END as quality_flag
            FROM biomarcadores
            WHERE participant_id = %s
        """
        params = [bucket_size, id]
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
        
        cur.close()
        conn.close()
        
        return {
            "participante": id, 
            "total_registros": len(res), 
            "metricas": res
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/participante/{id}/exportar")
async def exportar_datos(id: str, bucket_size: str = '1 minute'):
    """
    Módulo de Exportación Unificada:
    Genera un CSV con todas las métricas alineadas temporalmente (pivotado)
    para facilitar la investigación clínica en herramientas como SPSS o R.
    """
    import io
    from fastapi.responses import StreamingResponse
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        
        # Descargamos los datos ya resampleados para alinear las frecuencias
        query = f"""
            SELECT 
                time_bucket(CAST('{bucket_size}' AS INTERVAL), time) AS timestamp,
                sensor_type,
                CASE 
                    WHEN sensor_type IN ('activity_class', 'activity_intensity', 'body_position', 'sleep_detection') 
                    THEN mode() WITHIN GROUP (ORDER BY value)
                    ELSE AVG(value)
                END as value
            FROM biomarcadores
            WHERE participant_id = '{id}'
            GROUP BY timestamp, sensor_type
            ORDER BY timestamp ASC
        """
        
        df = pd.read_sql_query(query, conn)
        conn.close()

        if df.empty:
            raise HTTPException(status_code=404, detail="No hay datos para este participante")

        # Alineación Temporal: Convertimos filas de sensores en columnas
        df_pivot = df.pivot(index='timestamp', columns='sensor_type', values='value').reset_index()
        
        output = io.StringIO()
        df_pivot.to_csv(output, index=False)
        output.seek(0)
        
        return StreamingResponse(
            output,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=dataset_unificado_{id}.csv"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en el módulo de exportación: {str(e)}")