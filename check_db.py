import psycopg2
conn = psycopg2.connect(dbname="tfg_embrace", user="ines", password="tfg_password", host="localhost", port="5432")
cur = conn.cursor()
cur.execute("SELECT participant_id, COUNT(*), COUNT(DISTINCT sensor_type), MIN(time), MAX(time) FROM biomarcadores GROUP BY participant_id ORDER BY COUNT(*) ASC LIMIT 5;")
for row in cur.fetchall():
    print(row)
