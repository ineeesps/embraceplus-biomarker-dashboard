# OpenWear: Sistema de Gestión y Análisis de Biomarcadores en Dispositivos Wearables

Este repositorio contiene el código de **OpenWear**, una plataforma de código abierto diseñada para la ingesta, almacenamiento, procesamiento y visualización de registros temporales procedentes de dispositivos wearables, desarrollada en el marco de un Trabajo de Fin de Grado (TFG).

La plataforma permite mitigar el cuello de botella de las inserciones continuas de alta frecuencia y eliminar la dependencia de infraestructuras propietarias, facilitando la monitorización local y el análisis clínico de biomarcadores.

## Arquitectura y Componentes del Sistema

El sistema implementa una arquitectura cliente-servidor desacoplada desplegada en contenedores Docker:

*   **Persistencia (TimescaleDB)**: Base de datos relacional y de series temporales que soluciona los problemas de rendimiento en inserción continua mediante particionado temporal automático por bloques.
*   **Backend (FastAPI)**: Servidor Python que expone una interfaz API REST. Integra un proceso de Extracción, Transformación y Carga (ETL) estructurado con patrones de diseño (Estrategia, Fábrica y Adaptador) para abstraer la dependencia del hardware físico y normalizar los formatos de las señales. Además, detecta periodos de inactividad física y alinea temporalmente los registros.
*   **Frontend (Flutter)**: Interfaz de usuario que delega la agrupación temporal (downsampling) de los datos en la base de datos para evitar saturar la memoria y la red del cliente. Incorpora algoritmos de interpolación (spline cúbico, lineal y forward fill) para la imputación de valores vacíos y la exportación de series continuas.
*   **Seguridad y Privacidad**: Gestión de acceso basada en roles (RBAC) y borrados en cascada de los datos clínicos de participantes para garantizar el cumplimiento del Reglamento General de Protección de Datos (RGPD).

## Estructura del Repositorio

*   **/TFG_Analisis**: Código fuente del backend en FastAPI, Dockerfile, configuración de servicios en `docker-compose.yml`, scripts de importación de datos y suite de pruebas de concurrencia.
*   **/Proyecto_widget**: Código fuente del cliente frontend desarrollado en Flutter.
*   **/aux_pruebas**: Archivos CSV de prueba correspondientes a las lecturas de sensores y scripts de verificación de base de datos.

## Requisitos Previos

*   Docker y Docker Compose.
*   Flutter SDK (canal stable).
*   Python 3.10 o superior (para ejecución de scripts de prueba de forma local).

## Instrucciones de Despliegue

### 1. Iniciar Base de Datos y API

Compile y levante los contenedores en segundo plano desde el directorio del backend:

```bash
cd TFG_Analisis
docker-compose up -d --build
```

Esto iniciará:
*   Un contenedor de PostgreSQL con la extensión TimescaleDB expuesto en el puerto `5433`.
*   Un contenedor del servicio FastAPI en el puerto `8000`.

La documentación interactiva de la API y el listado de endpoints se encuentran en `http://localhost:8000/docs`.

### 2. Ingesta de Datos de Prueba

Para importar los registros CSV de prueba incluidos en la carpeta `aux_pruebas` a las tablas particionadas:

```bash
docker-compose exec api_v2 python scripts/ingesta_masiva.py
```

### 3. Ejecutar el Cliente Frontend

Acceda a la carpeta del proyecto Flutter, instale las dependencias necesarias y ejecute la aplicación en modo desarrollo (soporta plataformas web y escritorio Linux):

```bash
cd ../Proyecto_widget
flutter pub get
flutter run
```

*Las credenciales por defecto configuradas en la siembra de la base de datos son:*
*   *Investigador 1: Usuario `ines`, Contraseña `123`*
*   *Investigador 2: Usuario `alberto`, Contraseña `123`*
*   *Administrador: Usuario `admin`, Contraseña `admin123`*

---

## Licencia Educativa y de Software Libre

Este proyecto se distribuye bajo la Licencia MIT. Ha sido diseñado y desarrollado con fines exclusivamente académicos, educativos y de investigación científica en el ámbito de la ingeniería universitaria, sin propósito comercial o de lucro.

### Licencia MIT

Copyright (c) 2026 Inés Pleguezuelos Salcedo

Por la presente se concede permiso de forma gratuita a cualquier persona que obtenga una copia de este software y de los archivos de documentación asociados (el "Software"), para utilizar el Software sin restricción, incluyendo sin limitación los derechos de usar, copiar, modificar, fusionar, publicar, distribuir, sublicenciar y/o vender copias del Software, y para permitir a las personas a las que se les proporcione el Software a hacer lo mismo, bajo las siguientes condiciones:

El aviso de copyright anterior y este aviso de permiso se incluirán en todas las copias o partes sustanciales del Software.

EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA, INCLUYENDO PERO NO LIMITADO A GARANTÍAS DE COMERCIALIZACIÓN, IDONEIDAD PARA UN PROPÓSITO PARTICULAR Y NO INFRACCIÓN. EN NINGÚN CASO LOS AUTORES O PROPIETARIOS DE LOS DERECHOS DE AUTOR SERÁN RESPONSABLES DE NINGUNA RECLAMACIÓN, DAÑOS U OTRAS RESPONSABILIDADES, YA SEA EN UNA ACCIÓN DE CONTRATO, AGRAVIO O DE OTRO MODO, QUE SURJA DE, FUERA DE O EN CONEXIÓN CON EL SOFTWARE O EL USO U OTROS NEGOCIOS EN EL SOFTWARE.
