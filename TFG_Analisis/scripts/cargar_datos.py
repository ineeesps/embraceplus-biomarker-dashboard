import pandas as pd
import psycopg2
from psycopg2 import extras
import os
import math

# ==========================================
# PATRÓN ADAPTER: GESTIÓN ESCALABLE DE SENSORES
# ==========================================
class SensorAdapter:
    def map_row(self, row, dataframe):
        raise NotImplementedError

class DefaultAdapter(SensorAdapter):
    def __init__(self, target_column):
        self.target_column = target_column

    def map_row(self, row, dataframe):
        return getattr(row, self.target_column) if self.target_column in dataframe.columns else None

class ActicountsAdapter(SensorAdapter):
    def map_row(self, row, dataframe):
        try:
            x = getattr(row, 'acticounts_x_axis', None)
            y = getattr(row, 'acticounts_y_axis', None)
            z = getattr(row, 'acticounts_z_axis', None)
            if pd.notnull(x) and pd.notnull(y) and pd.notnull(z):
                return math.sqrt(float(x)**2 + float(y)**2 + float(z)**2)
        except Exception:
            pass
        return None

class CategoricalAdapter(SensorAdapter):
    def __init__(self, target_column, category_map):
        self.target_column = target_column
        self.category_map = category_map

    def map_row(self, row, dataframe):
        valor_raw = getattr(row, self.target_column) if self.target_column in dataframe.columns else None
        if isinstance(valor_raw, str) and valor_raw.lower() in self.category_map:
            return self.category_map[valor_raw.lower()]
        return None

class SleepAdapter(SensorAdapter):
    def map_row(self, row, dataframe):
        valor_raw = getattr(row, 'sleep_detection_stage') if 'sleep_detection_stage' in dataframe.columns else None
        if pd.notnull(valor_raw):
            try:
                v = float(valor_raw)
                if 0 <= v <= 99: return 0  # Wake
                elif 100 <= v <= 299: return 1  # Rest/Sleep
                elif 300 <= v <= 399: return 2  # Interruption
                elif v == 400: return 3  # Reserved
            except ValueError:
                pass
        return None

class BodyPositionAdapter(SensorAdapter):
    def __init__(self):
        self.category_map = {'sitting_reclining_lying': 0, 'standing': 1, 'left': 2, 'right': 3, 'prone': 4, 'supine': 5, 'miscellaneous': 6}

    def map_row(self, row, dataframe):
        # El hardware es ambidiestro, leemos ambas columnas posibles
        valor_raw = getattr(row, 'body_position_left', None) if 'body_position_left' in dataframe.columns else None
        if pd.isnull(valor_raw):
            valor_raw = getattr(row, 'body_position_right', None) if 'body_position_right' in dataframe.columns else None
            
        if isinstance(valor_raw, str) and valor_raw.lower() in self.category_map:
            return self.category_map[valor_raw.lower()]
        return None

class AdapterFactory:
    @staticmethod
    def get_adapter(tipo_sensor):
        if tipo_sensor == 'acticounts_total':
            return ActicountsAdapter()
        elif tipo_sensor == 'sleep_detection':
            return SleepAdapter()
        elif tipo_sensor == 'activity_class':
            return CategoricalAdapter('activity_class', {'still': 0, 'walking': 1, 'running': 2, 'generic': 3})
        elif tipo_sensor == 'body_position':
            return BodyPositionAdapter()
        elif tipo_sensor == 'activity_intensity':
            return CategoricalAdapter('activity_intensity', {'sedentary': 0, 'lpa': 1, 'mpa': 2, 'vpa': 3, 'mda': 2})
        else:
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
                'activity_counts': 'activity_counts',
                'actigraphy_vector': 'vector_magnitude'
            }
            return DefaultAdapter(mapa_columnas.get(tipo_sensor))


# ==========================================
# PARSEO DE ESTADOS CRÍTICOS DE HARDWARE
# ==========================================
def _parse_hardware_state(calidad, missing_reason, valor_original=None):
    if pd.isnull(missing_reason):
        return calidad
    
    missing_str = str(missing_reason)
    flag_result = missing_str
    
    if 'device_not_recording' in missing_str:
        if ' M' in missing_str or '(M)' in missing_str or 'Memoria' in missing_str:
            flag_result = 'device_not_recording | Hardware: Memory Full'
        elif ' T' in missing_str or '(T)' in missing_str or 'Temperatura' in missing_str:
            flag_result = 'device_not_recording | Hardware: Critical Temp'
        elif ' X' in missing_str or '(X)' in missing_str or 'Desconexión' in missing_str:
            flag_result = 'device_not_recording | Hardware: Disconnected'
            
    # Si tenemos el valor cualitativo original (ej. "walking"), lo añadimos para auditoría
    if isinstance(valor_original, str):
        flag_result = f"{flag_result} | {valor_original}"
        
    return flag_result if missing_str != 'good' else calidad

# ==========================================
# MOTOR PRINCIPAL
# ==========================================
def cargar_csv_a_timescale(archivo_nombre, tipo_sensor, participante):
    if os.path.exists(archivo_nombre):
        ruta_entrada = archivo_nombre
    else:
        dir_actual = os.path.dirname(os.path.abspath(__file__))
        ruta_entrada = os.path.join(dir_actual, '..', 'data', archivo_nombre)

    if not os.path.exists(ruta_entrada): 
        raise FileNotFoundError(f"No se encontró el archivo: {ruta_entrada}")

    try:
        db_host = os.getenv("DB_HOST", "localhost")
        db_port = os.getenv("DB_PORT", "5432")
        conn = psycopg2.connect(dbname="tfg_embrace", user="ines", password="tfg_password", host=db_host, port=db_port)
        cur = conn.cursor()
        
        df = pd.read_csv(ruta_entrada, low_memory=False)
        adapter = AdapterFactory.get_adapter(tipo_sensor)
        
        total_rows = len(df)
        invalid_rows = 0
        datos_finales = []
    
        for r in df.itertuples():
            tiempo = getattr(r, 'time', getattr(r, 'timestamp_iso', None))
            
            # Uso del Patrón Adapter
            valor_num = adapter.map_row(r, df)
            
            # Auditoría de Calidad (Captura garantizada del missing_value_reason)
            calidad_base = getattr(r, 'quality_flag', 'good') if hasattr(r, 'quality_flag') else 'good'
            missing_reason = getattr(r, 'missing_value_reason', None)
            
            # Identificamos el valor crudo cualitativo de forma dinámica y ambidiestra
            valor_crudo_posible = getattr(r, 'activity_class', None)
            if pd.isnull(valor_crudo_posible): valor_crudo_posible = getattr(r, 'activity_intensity', None)
            if pd.isnull(valor_crudo_posible): valor_crudo_posible = getattr(r, 'body_position_left', None)
            if pd.isnull(valor_crudo_posible): valor_crudo_posible = getattr(r, 'body_position_right', None)
            if pd.isnull(valor_crudo_posible): valor_crudo_posible = getattr(r, 'sleep_detection_stage', None)
            
            calidad_final = _parse_hardware_state(calidad_base, missing_reason, valor_original=valor_crudo_posible if isinstance(valor_crudo_posible, str) else None)

            # Módulo de Fiabilidad: Regla estricta de anulación de señal
            is_bad_signal = ('device_not_recording' in str(calidad_final) or 
                             'device_not_worn_correctly' in str(calidad_final) or 
                             'worn_during_motion' in str(calidad_final) or 
                             'low_signal_quality' in str(calidad_final))
            
            if is_bad_signal:
                valor_num = None
                invalid_rows += 1
            
            datos_finales.append((tiempo, participante, tipo_sensor, valor_num, calidad_final))

        # Regla Clínica del 5% de Pérdida
        loss_percentage = (invalid_rows / total_rows * 100) if total_rows > 0 else 0

        if datos_finales:
            sql = "INSERT INTO biomarcadores (time, participant_id, sensor_type, value, quality_flag) VALUES %s"
            extras.execute_values(cur, sql, datos_finales, page_size=1000)
            conn.commit()
            
        return {
            'inserted': len(datos_finales),
            'loss_percentage': loss_percentage,
            'clinical_warning': loss_percentage > 5.0
        }

    except Exception as e:
        if 'conn' in locals(): conn.rollback()
        raise Exception(f"Fallo en la base de datos al procesar {archivo_nombre}: {str(e)}")
    finally:
        if 'cur' in locals(): cur.close()
        if 'conn' in locals(): conn.close()