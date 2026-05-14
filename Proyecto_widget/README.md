# Dashboard de Monitorización Clínica Fisiológica

Este proyecto es una plataforma avanzada de visualización y análisis de datos biomédicos procedentes de sensores **EmbracePlus**. Está diseñado específicamente para investigadores y personal clínico, permitiendo la monitorización del estado autonómico, cardiovascular y motor de los participantes.

## Características Principales

*   **Módulo de Movimiento y Actividad**: Seguimiento de pasos, intensidad de actividad, clasificación de tareas y detección de uso del dispositivo (Compliance).
*   **Módulo Cardiorrespiratorio**: Correlación entre la frecuencia cardíaca (HR) y ventilatoria (RR), con análisis de acoplamiento temporal y detección de taquicardia.
*   **Módulo de Estrés y Fisiología**:
    *   Monitorización de la Respuesta Galvánica de la Piel (EDA).
    *   Análisis de la Variabilidad Cardíaca (PRV/HRV) para medir el tono vagal.
    *   Cruce de datos con Demanda Metabólica (METs) y Temperatura Cutánea para descartar falsos positivos.
    *   Detección inteligente de artefactos térmicos (caídas <30ºC).
*   **Diseño Premium y Responsivo**: Interfaz optimizada para Web, Desktop (Linux) y Dispositivos Móviles, bajo un sistema de diseño "Deep Slate & Cyber Blue".
*   **Gestión de Datos**: Sistema de ingesta de CSVs, filtrado temporal dinámico y exportación de métricas procesadas.

## Requisitos Técnicos

*   **Frontend**: Flutter (Canal stable).
*   **Estado**: Provider para gestión reactiva de métricas.
*   **Gráficas**: FL Chart con optimizaciones de rendimiento para grandes conjuntos de datos.
*   **Tipografía**: Google Fonts (Outfit & Inter).

## Instalación y Ejecución

1. Asegúrese de tener el SDK de Flutter instalado.
2. Ejecute `flutter pub get` para instalar las dependencias.
3. Inicie el servidor de backend (API) en el puerto 8000.
4. Ejecute la aplicación:
   ```bash
   flutter run -d linux
   ```

---
*Desarrollado como parte del Trabajo de Fin de Grado (TFG) - Visualización de Biomarcadores de Estrés y Actividad.*
