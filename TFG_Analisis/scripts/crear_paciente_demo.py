#!/usr/bin/env python3
import os
import psycopg2
import datetime
import math

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "tfg_embrace"),
    "user": os.getenv("DB_USER", "ines"),
    "password": os.getenv("DB_PASSWORD", "tfg_password"),
    "port": os.getenv("DB_PORT", "5433"),
    "connect_timeout": 10,
}

def crear_paciente_demo():
    print("Conectando a la base de datos...")
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    # 1. Asegurar que 'DEMO' esté asignado a la investigadora 'ines'
    print("Asignando el participante 'DEMO' a la investigadora 'ines'...")
    cur.execute("""
        UPDATE usuarios 
        SET participantes_asignados = ARRAY(
            SELECT DISTINCT unnest(array_append(participantes_asignados, 'DEMO'))
        )
        WHERE username = 'ines';
    """)
    conn.commit()

    # 2. Limpiar registros antiguos de 'DEMO'
    print("Limpiando datos previos del participante 'DEMO'...")
    cur.execute("DELETE FROM biomarcadores WHERE participant_id = 'DEMO';")
    conn.commit()

    # 3. Generación de datos temporal
    # Rango de 24 horas: 2026-05-23 00:00:00+02:00 a 2026-05-24 00:00:00+02:00
    tz = datetime.timezone(datetime.timedelta(hours=2))
    start_time = datetime.datetime(2026, 5, 23, 0, 0, 0, tzinfo=tz)
    total_minutes = 24 * 60

    print("Generando registros fisiológicos...")
    records = []

    for m in range(total_minutes):
        t = start_time + datetime.timedelta(minutes=m)

        # Simular desconexiones físicas del dispositivo (tasa de uso imperfecta)
        # Períodos: 03:00 - 03:30 (minutos 180 a 210) y 19:30 - 20:15 (minutos 1170 a 1215)
        es_desconexion = (180 <= m < 210) or (1170 <= m < 1215)

        if es_desconexion:
            # En desconexión, wearing_detection es 0.0 y todos los sensores son NULL
            records.append((t, 'DEMO', 'wearing_detection', 0.0, 'device_not_recording', 'ines'))
            sensores_todos = [
                'step_count', 'activity_intensity', 'met', 'accelerometer_std',
                'acticounts_total', 'acticounts_x', 'acticounts_y', 'acticounts_z',
                'pulse_rate', 'respiratory_rate', 'eda', 'prv', 'temperature',
                'actigraphy_vector', 'activity_counts', 'sleep_detection',
                'activity_class', 'body_position'
            ]
            for s in sensores_todos:
                records.append((t, 'DEMO', s, None, 'device_not_recording', 'ines'))
            continue

        # Determinar si el minuto cae en algún hueco de señal (para pruebas de interpolación)
        # Gaps: 12:00 - 12:15 (minutos 720 a 735) y 18:00 - 18:10 (minutos 1080 a 1090)
        es_hueco = (720 <= m < 735) or (1080 <= m < 1090)

        # ----------------------------------------------------
        # COMPLIANCE (wearing_detection) - Siempre activo si no hay desconexión
        # ----------------------------------------------------
        records.append((t, 'DEMO', 'wearing_detection', 1.0, 'good', 'ines'))

        # Si es hueco, insertamos con calidad baja y valor NULL para todos los sensores fisiológicos
        if es_hueco:
            sensores_nulos = [
                'step_count', 'activity_intensity', 'met', 'accelerometer_std',
                'acticounts_total', 'acticounts_x', 'acticounts_y', 'acticounts_z',
                'pulse_rate', 'respiratory_rate', 'eda', 'prv', 'temperature',
                'actigraphy_vector', 'activity_counts'
            ]
            for s in sensores_nulos:
                records.append((t, 'DEMO', s, None, 'low_signal_quality', 'ines'))
            continue

        # ----------------------------------------------------
        # ESCENARIO 1: MOVIMIENTO
        # ----------------------------------------------------
        # Pico de Actividad Vigorosa (VPA): 10:00 a 11:00 (minutos 600 a 660)
        if 600 <= m < 660:
            step_count = 120.0
            activity_intensity = 3.0  # VPA
            met = 8.5
            accelerometer_std = 0.6
            acticounts_total = 1200.0
            acticounts_x = 700.0 + math.sin(m) * 100.0
            acticounts_y = 800.0 + math.cos(m) * 100.0
            acticounts_z = 500.0 + math.sin(m * 2) * 100.0
            actigraphy_vector = 4.2
            activity_counts = 180.0
        # Resto del día (despierto): 07:00 a 24:00 (minutos 420 a 1440)
        elif 420 <= m < 1440:
            step_count = 2.0 if m % 10 == 0 else 0.0  # Pocos pasos ocasionales
            activity_intensity = 0.0  # Sedentario
            met = 1.0
            accelerometer_std = 0.05
            acticounts_total = 10.0
            acticounts_x = 50.0 + math.sin(m / 10) * 10.0
            acticounts_y = 50.0 + math.cos(m / 10) * 10.0
            acticounts_z = 30.0 + math.sin(m / 5) * 5.0
            actigraphy_vector = 0.3
            activity_counts = 12.0
        # Horas de Sueño: 00:00 a 07:00 (minutos 0 a 420)
        else:
            step_count = 0.0
            activity_intensity = 0.0
            met = 0.9
            accelerometer_std = 0.01
            acticounts_total = 2.0
            acticounts_x = 10.0
            acticounts_y = 10.0
            acticounts_z = 8.0
            actigraphy_vector = 0.02
            activity_counts = 1.0

        records.append((t, 'DEMO', 'step_count', step_count, 'good', 'ines'))
        records.append((t, 'DEMO', 'activity_intensity', activity_intensity, 'good', 'ines'))
        records.append((t, 'DEMO', 'met', met, 'good', 'ines'))
        records.append((t, 'DEMO', 'accelerometer_std', accelerometer_std, 'good', 'ines'))
        records.append((t, 'DEMO', 'acticounts_total', acticounts_total, 'good', 'ines'))
        records.append((t, 'DEMO', 'acticounts_x', acticounts_x, 'good', 'ines'))
        records.append((t, 'DEMO', 'acticounts_y', acticounts_y, 'good', 'ines'))
        records.append((t, 'DEMO', 'acticounts_z', acticounts_z, 'good', 'ines'))
        records.append((t, 'DEMO', 'actigraphy_vector', actigraphy_vector, 'good', 'ines'))
        records.append((t, 'DEMO', 'activity_counts', activity_counts, 'good', 'ines'))

        # ----------------------------------------------------
        # ESCENARIO 2: CARDIORRESPIRATORIO
        # ----------------------------------------------------
        # Taquicardia y desacoplamiento: 14:00 a 14:30 (minutos 840 a 870)
        if 840 <= m < 870:
            pulse_rate = 125.0
            respiratory_rate = 16.0  # Desacoplamiento (baja/estable)
        else:
            pulse_rate = 70.0 + math.sin(m / 10.0) * 3.0
            respiratory_rate = 17.5 + math.cos(m / 10.0) * 0.5

        records.append((t, 'DEMO', 'pulse_rate', pulse_rate, 'good', 'ines'))
        records.append((t, 'DEMO', 'respiratory_rate', respiratory_rate, 'good', 'ines'))

        # ----------------------------------------------------
        # ESCENARIO 3: ESTRÉS PSICOLÓGICO
        # ----------------------------------------------------
        # Estrés: 16:00 a 17:00 (minutos 960 a 1020)
        if 960 <= m < 1020:
            pct = (m - 960) / 60.0
            eda = 1.5 + pct * 5.3  # Sube de 1.5 a 6.8 uS
            prv = 75.0 - pct * 53.0  # Baja de 75 a 22 ms (Relajación baja)
            temperature = 34.2 - pct * 1.7  # Vasoconstricción (baja a 32.5 °C)
        else:
            eda = 1.5 + math.sin(m / 30.0) * 0.2
            prv = 75.0 + math.cos(m / 30.0) * 3.0
            temperature = 34.2 + math.sin(m / 60.0) * 0.1

        records.append((t, 'DEMO', 'eda', eda, 'good', 'ines'))
        records.append((t, 'DEMO', 'prv', prv, 'good', 'ines'))
        records.append((t, 'DEMO', 'temperature', temperature, 'good', 'ines'))

        # ----------------------------------------------------
        # ESCENARIO 4: ARQUITECTURA DE SUEÑO Y ERGONOMÍA (00:00 a 07:00)
        # ----------------------------------------------------
        if 0 <= m < 420:
            # 00:00 - 00:30 (minutos 0 a 30): Vigilia (0)
            if 0 <= m < 30:
                sleep_detection = 0.0
                activity_class = 0.0
            # 00:30 - 01:30 (minutos 30 a 90): Ligero (1)
            elif 30 <= m < 90:
                sleep_detection = 1.0
                activity_class = 0.0
            # 01:30 - 02:30 (minutos 90 a 150): Profundo (2)
            elif 90 <= m < 150:
                sleep_detection = 2.0
                activity_class = 0.0
            # 02:30 - 03:30 (minutos 150 a 210): Ligero (1)
            elif 150 <= m < 210:
                sleep_detection = 1.0
                activity_class = 0.0
            # 03:30 - 03:40 (minutos 210 a 220): Microdespertar (0) + Espasmos (actividad)
            elif 210 <= m < 220:
                sleep_detection = 0.0
                activity_class = 1.0  # Desencadena espasmos en hipnograma
            # 03:40 - 04:40 (minutos 220 a 280): Profundo (2)
            elif 220 <= m < 280:
                sleep_detection = 2.0
                activity_class = 0.0
            # 04:40 - 06:30 (minutos 280 a 390): Ligero (1)
            elif 280 <= m < 390:
                sleep_detection = 1.0
                activity_class = 0.0
            # 06:30 - 07:00 (minutos 390 a 420): Vigilia (0)
            else:
                sleep_detection = 0.0
                activity_class = 0.0

            # Postura corporal:
            # 00:00 - 02:00 (minutos 0 a 120): Boca arriba (5)
            if 0 <= m < 120:
                body_position = 5.0
            # 02:00 - 04:00 (minutos 120 a 240): Lado izquierdo (2)
            elif 120 <= m < 240:
                body_position = 2.0
            # 04:00 - 06:00 (minutos 240 a 360): Lado derecho (3)
            elif 240 <= m < 360:
                body_position = 3.0
            # 06:00 - 07:00 (minutos 360 a 420): Boca abajo (4)
            else:
                body_position = 4.0

            records.append((t, 'DEMO', 'sleep_detection', sleep_detection, 'good', 'ines'))
            records.append((t, 'DEMO', 'activity_class', activity_class, 'good', 'ines'))
            records.append((t, 'DEMO', 'body_position', body_position, 'good', 'ines'))

    print(f"Insertando {len(records)} filas en TimescaleDB...")
    
    # Inserción masiva para máxima velocidad
    insert_query = """
        INSERT INTO biomarcadores (time, participant_id, sensor_type, value, quality_flag, investigador)
        VALUES (%s, %s, %s, %s, %s, %s);
    """
    cur.executemany(insert_query, records)
    conn.commit()

    cur.close()
    conn.close()
    print("Paciente 'DEMO' creado con éxito con todos los escenarios clínicos preconfigurados.")

if __name__ == "__main__":
    crear_paciente_demo()
