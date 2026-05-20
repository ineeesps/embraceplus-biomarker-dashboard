from abc import ABC, abstractmethod
import pandas as pd

class ProcesadorDispositivo(ABC):
    """
    Interfaz común (Estrategia) para procesar datos de distintos dispositivos wearables.
    Define los métodos que cada modelo específico debe implementar.
    """
    
    @abstractmethod
    def detectar_sensor(self, nombre_archivo: str) -> str:
        """
        Detecta el tipo de sensor a partir del nombre del archivo.
        Debe devolver None si el sensor no es reconocido.
        """
        pass

    @abstractmethod
    def obtener_sensores_a_borrar(self, sensor_detectado: str) -> tuple:
        """
        Devuelve una tupla con los nombres de los sensores que deben ser borrados
        de la base de datos antes de un reemplazo.
        """
        pass

    @abstractmethod
    def calcular_integridad(self, df: pd.DataFrame) -> float:
        """
        Calcula el porcentaje de pérdida de datos (0.0 a 100.0) basado en las 
        reglas de validación específicas del dispositivo.
        """
        pass


class EstrategiaEmbracePlus(ProcesadorDispositivo):
    """
    Estrategia específica para la pulsera Empatica EmbracePlus.
    """
    
    PATRONES_SENSORES = {
        'temperature': 'temperature',
        'pulse-rate': 'pulse_rate',
        'respiratory-rate': 'respiratory_rate',
        'accelerometers-std': 'accelerometer_std',
        'eda': 'eda',
        'prv': 'prv',
        'step-counts': 'step_count',
        'wearing-detection': 'wearing_detection',
        'met': 'met',
        'spo2': 'spo2',
        'activity-counts': 'activity_counts',
        'sleep-detection': 'sleep_detection',
        'activity-class': 'activity_class',
        'actigraphy': 'actigraphy_vector',
        'body-position': 'body_position',
        'activity-intensity': 'activity_intensity'
    }

    def detectar_sensor(self, nombre_archivo: str) -> str:
        nombre_lower = nombre_archivo.lower()
        return next((v for k, v in self.PATRONES_SENSORES.items() if k in nombre_lower), None)

    def obtener_sensores_a_borrar(self, sensor_detectado: str) -> tuple:
        if sensor_detectado == 'activity_counts':
            return ('acticounts_total', 'acticounts_x', 'acticounts_y', 'acticounts_z')
        return (sensor_detectado,)

    def calcular_integridad(self, df: pd.DataFrame) -> float:
        total_filas = len(df)
        if total_filas == 0:
            return 0.0
            
        if 'missing_value_reason' in df.columns:
            df_invalidas = df[df['missing_value_reason'].notnull() & (df['missing_value_reason'] != '')]
            return (len(df_invalidas) / total_filas) * 100
        
        return 0.0


class FabricaProcesadores:
    """
    Fábrica que instancia la estrategia correcta en base al modelo del dispositivo.
    """
    
    _estrategias = {
        "embrace_plus": EstrategiaEmbracePlus,
        # Aquí se añadirán otras pulseras en el futuro, ej. "fitbit": EstrategiaFitbit
    }
    
    @classmethod
    def obtener_estrategia(cls, device_type: str) -> ProcesadorDispositivo:
        estrategia_clase = cls._estrategias.get(device_type, EstrategiaEmbracePlus) # Por defecto EmbracePlus
        return estrategia_clase()
