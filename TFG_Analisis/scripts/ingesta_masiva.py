import os
import glob
from cargar_datos import cargar_csv_a_timescale

PATRONES_SENSORES = {
    'temperature': 'temperature', 'eda': 'eda', 'pulse-rate': 'pulse_rate',
    'respiratory-rate': 'respiratory_rate', 'accelerometers-std': 'accelerometer_std',
    'prv': 'prv', 'step-counts': 'step_count', 'met': 'met',
    'activity-intensity': 'activity_intensity', 'wearing-detection': 'wearing_detection',
    'activity-classification': 'activity_class', 'activity-counts': 'activity_counts',
    'actigraphy-counts': 'actigraphy_vector', 'body-position': 'body_position',
    'acticounts': 'acticounts_total', 'sleep-detection': 'sleep_detection'
}

def procesar_carpeta(ruta_base, id_participante):
    print(f"\n[{id_participante}] Buscando archivos en {ruta_base}...")
    archivos_csv = glob.glob(os.path.join(ruta_base, '**', '*.csv'), recursive=True)
    
    conteo = 0
    errores = 0
    for ruta_absoluta in archivos_csv:
        nombre_archivo = os.path.basename(ruta_absoluta).lower()
        sensor_detectado = None
        
        for patron, sensor in PATRONES_SENSORES.items():
            if patron in nombre_archivo:
                sensor_detectado = sensor
                break
                
        if sensor_detectado:
            try:
                # print(f"  Cargando: {sensor_detectado} <- {nombre_archivo}")
                cargar_csv_a_timescale(ruta_absoluta, sensor_detectado, id_participante)
                conteo += 1
            except Exception as e:
                print(f"  [ERROR] {nombre_archivo}: {e}")
                errores += 1
                
    print(f"[{id_participante}] Finalizado: {conteo} archivos cargados, {errores} errores.")
    return conteo

def main():
    base_tfg = '/home/ines/Escritorio/universidad/TFG'
    
    # 1. Participantes de Alberto
    procesar_carpeta(os.path.join(base_tfg, '1a_prueba'), 'PRUEBA 1')
    procesar_carpeta(os.path.join(base_tfg, '2a_prueba'), 'PRUEBA 2')
    
    # 2. Participantes de Inés
    ruta_nuevos = os.path.join(base_tfg, 'nuevos_usuarios')
    if os.path.exists(ruta_nuevos):
        for i in range(1, 21):
            id_participante = f'user{i}'
            ruta_user = os.path.join(ruta_nuevos, id_participante)
            if os.path.exists(ruta_user):
                procesar_carpeta(ruta_user, id_participante)
            else:
                # Intenta sin el 'user' literal si las carpetas se llaman diferente (ej. user1, user 1, etc.)
                pass

if __name__ == '__main__':
    print("INICIANDO INGESTA MASIVA EN TIMESCALEDB...")
    main()
    print("\nPROCESO DE INGESTA TOTAL COMPLETADO.")
