import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ingesta_masiva import procesar_carpeta

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'HN-Alberto', 'HN'))

carpetas = [
    os.path.join(BASE, '15-05-26-HN', 'digital_biomarkers', 'aggregated_per_minute'),
    os.path.join(BASE, '16-05-26-HN', 'digital_biomarkers', 'aggregated_per_minute'),
]

print("Insertando datos HN (investigador=alberto)...")
total = 0
for carpeta in carpetas:
    total += procesar_carpeta(carpeta, 'HN', investigador='alberto')
print(f"\nTotal archivos procesados: {total}")
