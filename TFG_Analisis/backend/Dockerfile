# 1. Usamos una versión oficial y ligera de Python 3.10
FROM python:3.10-slim

# 2. Instalamos herramientas del sistema necesarias para que funcione la base de datos (psycopg2)
RUN apt-get update && apt-get install -y gcc libpq-dev

# 3. Le decimos a Docker que trabaje dentro de una carpeta llamada /app
WORKDIR /app

# 4. Instalamos las librerías
RUN pip install fastapi uvicorn pandas scipy psycopg2-binary python-multipart bcrypt

# 5. Comando para arrancar la API
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]