import pandas as pd
import psycopg2
from psycopg2 import extras
import os

def cargar_csv_a_timescale(archivo_nombre, tipo_sensor, participante):
    if os.path.exists(archivo_nombre):
        ruta_entrada = archivo_nombre
    else:
        dir_actual = os.path.dirname(os.path.abspath(__file__))
        ruta_entrada = os.path.join(dir_actual, '..', 'data', archivo_nombre)

    # Diccionario Completo
    mapa_columnas = {
        'pulse_rate': 'pulse_rate_bpm',
        'eda': 'eda_scl_usiemens',
        'temperature': 'temperature_celsius',
        'respiratory_rate': 'respiratory_rate_brpm',
        'accelerometer_std': 'accelerometers_std_g',
        'prv': 'prv_rmssd_ms',
        'step_count': 'step_counts',
        'wearing_detection': 'wearing_detection_percentage',
        'met': 'met',
        'activity_intensity': 'activity_intensity',
        'activity_class': 'activity_class',
        'activity_counts': 'activity_counts',
        'actigraphy_vector': 'vector_magnitude',
        'body_position': 'body_position_left',
        'sleep_detection': 'sleep_detection_stage'
    }

    # Mapeo de texto a número (Para columnas categóricas)
    mapeo_categorias = {
        'still': 0, 'walking': 1, 'running': 2, 'generic': 3, # activity_class
        'sitting_reclining_lying': 0, 'standing': 1, 'left': 2, 'right': 3, 'prone': 4, 'supine': 5, 'miscellaneous': 6, # body_position
        'sedentary': 0, 'lpa': 1, 'mpa': 2, 'vpa': 3, 'mda': 2 # activity_intensity (MDA as fallback for MPA)
    }

    if not os.path.exists(ruta_entrada): 
        raise FileNotFoundError(f"No se encontró el archivo: {ruta_entrada}")

    try:
        # Usamos variables de entorno para que funcione tanto en Docker como en local
        db_host = os.getenv("DB_HOST", "localhost")
        db_port = os.getenv("DB_PORT", "5432")
        conn = psycopg2.connect(dbname="tfg_embrace", user="ines", password="tfg_password", host=db_host, port=db_port)
        cur = conn.cursor()
        
        df = pd.read_csv(ruta_entrada, low_memory=False)
        
        # Limpieza 
        # Ya NO eliminamos los 'device_not_recording' para que el Dashboard pueda pintarlos de gris
        df['quality_flag'] = df['missing_value_reason'].fillna('good')

        columna_valor = mapa_columnas.get(tipo_sensor)
        datos_finales = []
    
        for r in df.itertuples():
            tiempo = getattr(r, 'time', getattr(r, 'timestamp_iso', None))
            if tipo_sensor == 'acticounts_total':
                try:
                    x = getattr(r, 'acticounts_x_axis', None)
                    y = getattr(r, 'acticounts_y_axis', None)
                    z = getattr(r, 'acticounts_z_axis', None)
                    if pd.notnull(x) and pd.notnull(y) and pd.notnull(z):
                        import math
                        valor_raw = math.sqrt(float(x)**2 + float(y)**2 + float(z)**2)
                    else:
                        valor_raw = None
                except Exception:
                    valor_raw = None
            else:
                valor_raw = getattr(r, columna_valor) if columna_valor in df.columns else None
                
            calidad = getattr(r, 'quality_flag', 'good') if hasattr(r, 'quality_flag') else getattr(r, 'missing_value_reason', 'good')
            
            # Lógica de Mapeo Numérico para Categorías (Texto -> Número)
            if isinstance(valor_raw, str) and valor_raw.lower() in mapeo_categorias:
                valor_num = mapeo_categorias[valor_raw.lower()]
                calidad = f"{calidad} | {valor_raw}" # Guardamos el texto original en la calidad
            else:
                valor_num = valor_raw if pd.notnull(valor_raw) else None

            # Lógica específica de rangos para sleep_detection
            if tipo_sensor == 'sleep_detection' and valor_num is not None:
                try:
                    v = float(valor_num)
                    if 0 <= v <= 99:
                        valor_num = 0  # Wake
                        calidad = f"{calidad} | Wake ({v})"
                    elif 100 <= v <= 299:
                        valor_num = 1  # Rest/Sleep
                        calidad = f"{calidad} | Rest ({v})"
                    elif 300 <= v <= 399:
                        valor_num = 2  # Interruption
                        calidad = f"{calidad} | Interruption ({v})"
                    elif v == 400:
                        valor_num = 3  # Reserved
                        calidad = f"{calidad} | Reserved ({v})"
                except ValueError:
                    pass

            # Módulo de Fiabilidad: forzamos a nulo si hay error de señal (gap, motion, low_signal, mal puesto)
            # para no ensuciar el análisis estadístico. 
            # Preservamos la fila y la etiqueta (calidad) para auditoría en el Dashboard.
            if str(calidad).startswith('device_not_recording') or 'device_not_worn_correctly' in str(calidad) or 'worn_during_motion' in str(calidad) or 'low_signal_quality' in str(calidad):
                valor_num = None
            # Si la señal es buena, valor_num mantiene el valor mapeado o crudo
            
            datos_finales.append((tiempo, participante, tipo_sensor, valor_num, calidad))

        if datos_finales:
            sql = "INSERT INTO biomarcadores (time, participant_id, sensor_type, value, quality_flag) VALUES %s"
            extras.execute_values(cur, sql, datos_finales, page_size=1000)
            conn.commit()
            print(f"¡ÉXITO! {len(datos_finales)} registros de {tipo_sensor} cargados.")

    except Exception as e:
        if 'conn' in locals(): conn.rollback()
        # Lanzamos el error hacia arriba para que FastAPI (main.py) se entere
        raise Exception(f"Fallo en la base de datos al procesar {archivo_nombre}: {str(e)}")
    finally:
        if 'cur' in locals(): cur.close()
        if 'conn' in locals(): conn.close()