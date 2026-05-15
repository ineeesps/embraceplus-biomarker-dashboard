"""
Script de corrección: re-ingesta de datos acticounts para participantes
que fueron procesados con la versión antigua del adaptador (que solo guardaba
acticounts_total para todos los minutos, sin x/y/z).

Ejecutar desde cualquier directorio:
    python3 TFG_Analisis/scripts/fix_acticounts.py
"""

import os
import sys
import glob
import psycopg2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cargar_datos import cargar_csv_a_timescale

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "tfg_embrace"),
    "user":     os.getenv("DB_USER", "ines"),
    "password": os.getenv("DB_PASSWORD", "tfg_password"),
    "port":     os.getenv("DB_PORT", "5433"),
}


def needs_fix(cur, participant_id: str, investigador: str) -> bool:
    """Devuelve True si tiene acticounts_total pero le faltan los ejes x/y/z."""
    cur.execute(
        "SELECT COUNT(*) FROM biomarcadores "
        "WHERE participant_id = %s AND investigador = %s AND sensor_type = 'acticounts_x'",
        (participant_id, investigador),
    )
    has_x = cur.fetchone()[0] > 0
    cur.execute(
        "SELECT COUNT(*) FROM biomarcadores "
        "WHERE participant_id = %s AND investigador = %s AND sensor_type = 'acticounts_total'",
        (participant_id, investigador),
    )
    has_total = cur.fetchone()[0] > 0
    return has_total and not has_x


def fix_participant(participant_id: str, acticounts_path: str, investigador: str):
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    if not needs_fix(cur, participant_id, investigador):
        print(f"  [{participant_id}] OK — ya tiene acticounts_x/y/z o no tiene acticounts_total. Saltando.")
        cur.close()
        conn.close()
        return

    print(f"  [{participant_id}] Borrando acticounts_total (formato antiguo)...")
    for st in ("acticounts_total", "acticounts_x", "acticounts_y", "acticounts_z"):
        cur.execute(
            "DELETE FROM biomarcadores WHERE participant_id = %s AND sensor_type = %s AND investigador = %s",
            (participant_id, st, investigador),
        )
    conn.commit()
    cur.close()
    conn.close()

    print(f"  [{participant_id}] Re-ingresando {os.path.basename(acticounts_path)}...")
    resultado = cargar_csv_a_timescale(
        acticounts_path, "acticounts_total", participant_id, investigador=investigador
    )
    print(f"  [{participant_id}] Insertadas: {resultado['inserted']} filas "
          f"(pérdida: {resultado['loss_percentage']:.1f}%)")
    if resultado["clinical_warning"]:
        print(f"  [{participant_id}] ⚠️  Alerta clínica: >5% de datos con señal degradada.")


def main():
    dir_script = os.path.dirname(os.path.abspath(__file__))
    base_tfg = os.path.abspath(os.path.join(dir_script, "..", ".."))
    ruta_nuevos = os.path.join(base_tfg, "nuevos_usuarios")

    print(f"Buscando participantes en: {ruta_nuevos}\n")

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    cur.execute(
        "SELECT DISTINCT participant_id FROM biomarcadores "
        "WHERE investigador = 'ines' AND sensor_type = 'acticounts_total'"
    )
    participantes_con_acticounts = [r[0] for r in cur.fetchall()]
    cur.close()
    conn.close()

    print(f"Participantes con acticounts_total en BD: {participantes_con_acticounts}\n")

    fixed = 0
    for participant_id in participantes_con_acticounts:
        ruta_user = os.path.join(ruta_nuevos, participant_id)
        archivos = glob.glob(os.path.join(ruta_user, "**", "*acticounts.csv"), recursive=True)
        if not archivos:
            print(f"  [{participant_id}] No se encontró acticounts.csv en {ruta_user}")
            continue
        fix_participant(participant_id, archivos[0], investigador="ines")
        fixed += 1

    print(f"\nProceso completado. {fixed} participantes procesados.")


if __name__ == "__main__":
    print("=== CORRECCIÓN DE ACTICOUNTS x/y/z ===\n")
    main()
