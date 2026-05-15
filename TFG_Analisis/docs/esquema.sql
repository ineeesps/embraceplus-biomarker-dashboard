-- 1. Creamos la tabla base
CREATE TABLE biomarcadores (
    time           TIMESTAMPTZ      NOT NULL,
    participant_id TEXT             NOT NULL,
    sensor_type    TEXT             NOT NULL,
    value          DOUBLE PRECISION,          -- NULL permitido (señal ausente o mala calidad)
    quality_flag   TEXT,
    investigador   TEXT             NOT NULL DEFAULT 'ines'
);

-- 2. Convertimos la tabla en Hypertable
-- Particionamos por bloques de 7 días como he planeado para optimizar memoria
SELECT create_hypertable('biomarcadores', 'time', chunk_time_interval => INTERVAL '7 days');

-- 3. Definición de Índices
-- Creamos un índice compuesto para cumplir el RNF1.2 (Carga en < 7 segundos)
CREATE INDEX idx_participant_time ON biomarcadores (participant_id, time DESC);

-- 4. Índice para búsquedas rápidas por tipo de sensor
CREATE INDEX idx_sensor_type ON biomarcadores (sensor_type, time DESC);

-- 5. Índice multi-tenant
CREATE INDEX idx_investigador ON biomarcadores (investigador, participant_id, time DESC);