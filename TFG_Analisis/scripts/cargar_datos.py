import pandas as pd
import psycopg2
from psycopg2 import extras
import os
import math

class SensorAdapter:
    def map_row(self, row, dataframe):
        raise NotImplementedError

class DefaultAdapter(SensorAdapter):
    def __init__(self, target_column, tipo_sensor):
        self.target_column = target_column
        self.tipo_sensor = tipo_sensor

    def map_row(self, row, dataframe):
        if self.target_column in dataframe.columns:
            return [(self.tipo_sensor, getattr(row, self.target_column))]

        alternativas = [self.tipo_sensor, self.tipo_sensor.replace('_', '-')]
        for alt in alternativas:
            if alt in dataframe.columns:
                return [(self.tipo_sensor, getattr(row, alt))]
        
        return [(self.tipo_sensor, None)]

class ActicountsAdapter(SensorAdapter):
    def map_row(self, row, dataframe):
        try:
            x = getattr(row, 'acticounts_x_axis', None)
            y = getattr(row, 'acticounts_y_axis', None)
            z = getattr(row, 'acticounts_z_axis', None)
            
            res = []
            if pd.notnull(x): res.append(('acticounts_x', float(x)))
            if pd.notnull(y): res.append(('acticounts_y', float(y)))
            if pd.notnull(z): res.append(('acticounts_z', float(z)))
            
            x_val = float(x) if pd.notnull(x) else 0.0
            y_val = float(y) if pd.notnull(y) else 0.0
            z_val = float(z) if pd.notnull(z) else 0.0
            res.append(('acticounts_total', math.sqrt(x_val**2 + y_val**2 + z_val**2)))
            return res
        except Exception:
            return res

class CategoricalAdapter(SensorAdapter):
    def __init__(self, target_column, category_map):
        self.target_column = target_column
        self.category_map = category_map

    def map_row(self, row, dataframe):
        val = getattr(row, self.target_column, None)
        if pd.isnull(val): return [(self.target_column, None)]
        if isinstance(val, (int, float)): return [(self.target_column, int(val))]
        s_val = str(val).lower().strip()
        return [(self.target_column, self.category_map.get(s_val))]

class SleepAdapter(SensorAdapter):
    def map_row(self, row, dataframe):
        try:
            stage = getattr(row, 'sleep_detection_stage', None)
            if pd.notnull(stage):
                v = int(stage)
                if 0 <= v <= 99:      res = 0   # wake
                elif 100 <= v <= 299: res = 1   # rest/sleep
                elif 300 <= v <= 399: res = 2   # rest interruption
                else:                 res = None  # reservado (400+)
                return [('sleep_detection', res)]
        except Exception:
            pass
        return [('sleep_detection', None)]

class BodyPositionAdapter(SensorAdapter):
    def __init__(self):
        self.category_map = {
            'sitting_reclining_lying': 0, 'standing': 1, 'left': 2, 'right': 3, 
            'prone': 4, 'supine': 5, 'miscellaneous': 6
        }

    def map_row(self, row, dataframe):
        val = getattr(row, 'body_position_left', None)
        if pd.isnull(val): val = getattr(row, 'body_position_right', None)
        if val is None or pd.isnull(val): return [('body_position', None)]
        if isinstance(val, (int, float)): return [('body_position', int(val))]
        s_val = str(val).lower().strip()
        return [('body_position', self.category_map.get(s_val))]

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
                'spo2': 'spo2_percentage',
                'activity_counts': 'activity_counts',
                'actigraphy_vector': 'vector_magnitude'
            }
            return DefaultAdapter(mapa_columnas.get(tipo_sensor, tipo_sensor), tipo_sensor)

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
            
    if isinstance(valor_original, str):
        flag_result = f"{flag_result} | {valor_original}"
        
    return flag_result if missing_str != 'good' else calidad

def cargar_csv_a_timescale(archivo_nombre, tipo_sensor, participante, investigador='ines'):
    if investigador is None:
        investigador = 'ines'
    if os.path.isabs(archivo_nombre):
        ruta_entrada = archivo_nombre
    else:
        dir_actual = os.path.dirname(os.path.abspath(__file__))
        ruta_entrada = os.path.join(dir_actual, '..', 'data', archivo_nombre)

    if not os.path.exists(ruta_entrada):
        raise FileNotFoundError(f"No encontrado: {ruta_entrada}")

    try:
        conn = psycopg2.connect(
            dbname=os.getenv("DB_NAME", "tfg_embrace"),
            user=os.getenv("DB_USER", "ines"),
            password=os.getenv("DB_PASSWORD", "tfg_password"),
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5433")
        )
        cur = conn.cursor()

        df = pd.read_csv(ruta_entrada, low_memory=False)
        adapter = AdapterFactory.get_adapter(tipo_sensor)

        col_tiempo = next((c for c in df.columns if c.lower() in ['time', 'timestamp', 'timestamp_iso', 'time (iso)']), None)
        timestamps = df[col_tiempo].tolist() if col_tiempo else []

        total_rows = len(df)
        invalid_rows = 0
        datos_finales = []

        for i, r in enumerate(df.itertuples()):
            try:
                tiempo = timestamps[i] if timestamps else None
                if pd.isnull(tiempo):
                    invalid_rows += 1
                    continue

                resultados = adapter.map_row(r, df)
                if not isinstance(resultados, list):
                    resultados = [(tipo_sensor, resultados)]

                calidad_base = getattr(r, 'quality_flag', 'good') if hasattr(r, 'quality_flag') else 'good'
                missing_reason = getattr(r, 'missing_value_reason', None)

                valor_crudo = None
                for col in ['activity_class', 'activity_intensity', 'body_position_left', 'body_position_right', 'sleep_detection_stage']:
                    if hasattr(r, col):
                        v = getattr(r, col)
                        if pd.notnull(v):
                            valor_crudo = v
                            break

                calidad_final = _parse_hardware_state(calidad_base, missing_reason, valor_original=str(valor_crudo) if valor_crudo else None)
                is_bad_signal = bool(
                    missing_reason
                    and str(missing_reason).strip()
                    and str(missing_reason).strip() != 'good'
                )
                if is_bad_signal:
                    invalid_rows += 1

                for s_type, s_val in resultados:
                    if s_val is None and not is_bad_signal:
                        continue
                    datos_finales.append((tiempo, participante, s_type, s_val, calidad_final, investigador))
            except Exception:
                continue

        if datos_finales:
            seen = set()
            deduped = []
            for rec in datos_finales:
                key = (rec[0], rec[1], rec[2])
                if key not in seen:
                    seen.add(key)
                    deduped.append(rec)
            sql = "INSERT INTO biomarcadores (time, participant_id, sensor_type, value, quality_flag, investigador) VALUES %s"
            extras.execute_values(cur, sql, deduped, page_size=1000)
            conn.commit()
        else:
            deduped = []

        return {
            'inserted': len(deduped),
            'loss_percentage': (invalid_rows / total_rows * 100) if total_rows > 0 else 0,
            'clinical_warning': (invalid_rows / total_rows) > 0.05 if total_rows > 0 else False
        }

    except Exception as e:
        if 'conn' in locals():
            conn.rollback()
        raise Exception(f"Error en ingesta ({tipo_sensor}): {str(e)}")
    finally:
        if 'cur' in locals():
            cur.close()
        if 'conn' in locals():
            conn.close()