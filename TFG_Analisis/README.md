# TFG-embraceplus-biomarker-dashboard

Este proyecto forma parte de un **Trabajo de Fin de Grado (TFG)** centrado en la monitorización de salud mediante el dispositivo wearable *EmbracePlus* de Empatica. La plataforma permite la ingesta, procesamiento (ETL), limpieza y visualización de biomarcadores biomédicos complejos.

## 🚀 Características Principales
* **Aislamiento Multi-Investigador:** Sistema de login que garantiza que cada investigador solo gestione y visualice sus propios participantes.
* **Gestión Interactiva de Participantes:** Funcionalidad para añadir (vía CSV), renombrar y eliminar participantes directamente desde la interfaz.
* **Limpieza Automática (ETL):** Motor en Python que detecta periodos de inactividad, baja calidad de señal o movimiento excesivo.
* **Dashboard Clínico:** Visualización reactiva con superposición de biomarcadores para análisis comparativo y detección de anomalías.
* **Ingesta de Alta Frecuencia:** Soporte para 16 streams de datos, incluyendo acelerometría (STD), EDA, Pulso y Sueño.

## 🛠️ Stack Tecnológico
* **Frontend:** Flutter (Arquitectura basada en Providers).
* **Backend:** FastAPI (Python 3.10+).
* **Base de Datos:** TimescaleDB (PostgreSQL optimizado para series temporales).
* **Infraestructura:** Docker & Docker Compose.

## 📂 Estructura del Proyecto
* `/TFG_Analisis`: Contiene el backend, scripts de ingesta y configuración de Docker.
* `/Proyecto_widget`: Código fuente de la aplicación Flutter.

## 🏁 Inicio Rápido

1. **Levantar Infraestructura:**
   ```bash
   cd TFG_Analisis
   docker-compose up -d --build
   ```

2. **Ejecutar Frontend:**
   ```bash
   cd Proyecto_widget
   flutter run
   ```

3. **Acceso:**
   * **Credenciales por defecto:** `ines` / `123` o `alberto` / `123`.
   * **API Docs:** `http://localhost:8000/docs`

---
*Desarrollado como proyecto de ingeniería para el análisis de biomarcadores digitales.*
