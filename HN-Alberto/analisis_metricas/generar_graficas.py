import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import seaborn as sns
import glob
import os

sns.set_theme(style="darkgrid", palette="husl")

# Base directory for the data
base_dir = '/home/albduranlopez/Descargas/HN-Alberto/HN'

# Output directory for the script and plots
output_dir = '/home/albduranlopez/Descargas/HN-Alberto/analisis_metricas'
os.makedirs(output_dir, exist_ok=True)

def load_data(metric):
    files = glob.glob(f'{base_dir}/*/digital_biomarkers/aggregated_per_minute/*_{metric}.csv')
    df_list = []
    for f in sorted(files):
        try:
            df = pd.read_csv(f)
            df_list.append(df)
        except Exception as e:
            print(f"Error loading {f}: {e}")
    if not df_list:
        return None
    df = pd.concat(df_list, ignore_index=True)
    df['timestamp'] = pd.to_datetime(df['timestamp_iso'])
    df = df.sort_values('timestamp').reset_index(drop=True)
    return df

# Load datasets
print("Cargando datasets...")
df_sleep = load_data('sleep-detection')
df_steps = load_data('step-counts')
df_pulse = load_data('pulse-rate')
df_acc = load_data('accelerometers-std')
df_temp = load_data('temperature')
df_eda = load_data('eda')

print("Generando graficas...")

def setup_ax(ax, title, ylabel):
    ax.set_title(title, fontsize=14, fontweight='bold')
    ax.set_ylabel(ylabel, fontsize=12)
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M\n%d %b', tz=df_sleep['timestamp'].dt.tz))
    ax.tick_params(axis='x', rotation=45)

# Plot 1: Sleep & Pulse Rate
fig, ax1 = plt.subplots(figsize=(14, 6))
ax2 = ax1.twinx()
if df_sleep is not None and not df_sleep.empty:
    sleep_color = 'indigo'
    ax1.plot(df_sleep['timestamp'], df_sleep['sleep_detection_stage'], color=sleep_color, label='Sleep Stage (0=Awake, 101/102=Sleep)', drawstyle='steps-post', linewidth=2)
    ax1.fill_between(df_sleep['timestamp'], df_sleep['sleep_detection_stage'], step="post", alpha=0.3, color=sleep_color)
    ax1.set_yticks([0, 101, 102])
    ax1.set_yticklabels(['Despierto (0)', 'Sueño Ligero (101)', 'Sueño Profundo (102)'])
    
if df_pulse is not None and not df_pulse.empty:
    pulse_color = 'crimson'
    ax2.plot(df_pulse['timestamp'], df_pulse['pulse_rate_bpm'], color=pulse_color, alpha=0.7, label='Pulsaciones (BPM)', linewidth=1.5)
    ax2.set_ylabel('Pulsaciones (BPM)', color=pulse_color, fontsize=12)
    ax2.tick_params(axis='y', labelcolor=pulse_color)

ax1.set_title('Calidad de Sueño y Frecuencia Cardíaca (15-16 de Mayo)', fontsize=16, fontweight='bold')
ax1.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M\n%d %b', tz=df_sleep['timestamp'].dt.tz))
ax1.tick_params(axis='x', rotation=45)
fig.tight_layout()
fig.savefig(f'{output_dir}/1_sueno_y_pulso.png', dpi=150)
plt.close(fig)

# Plot 2: Activity (Steps & Accelerometer)
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10), sharex=True)
if df_steps is not None and not df_steps.empty:
    ax1.bar(df_steps['timestamp'], df_steps['step_counts'], color='teal', width=0.001, alpha=0.8)
    setup_ax(ax1, 'Pasos por Minuto', 'Pasos')

if df_acc is not None and not df_acc.empty:
    ax2.plot(df_acc['timestamp'], df_acc['accelerometers_std_g'], color='darkorange', linewidth=1.5)
    setup_ax(ax2, 'Desviación Estándar del Acelerómetro (Fuerza G)', 'Fuerza (g)')

fig.tight_layout()
fig.savefig(f'{output_dir}/2_actividad_acelerometro.png', dpi=150)
plt.close(fig)

# Plot 3: EDA & Temperature
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10), sharex=True)
if df_eda is not None and not df_eda.empty:
    ax1.plot(df_eda['timestamp'], df_eda['eda_scl_usiemens'], color='mediumpurple', linewidth=1.5)
    setup_ax(ax1, 'Actividad Electrodérmica (EDA - Sudoración)', 'SCL (\u03bcSiemens)')

if df_temp is not None and not df_temp.empty:
    ax2.plot(df_temp['timestamp'], df_temp['temperature_celsius'], color='tomato', linewidth=1.5)
    setup_ax(ax2, 'Temperatura Cutánea', 'Grados Celsius (\u00b0C)')

fig.tight_layout()
fig.savefig(f'{output_dir}/3_eda_temperatura.png', dpi=150)
plt.close(fig)

print(f"Todas las gráficas se han guardado con éxito en {output_dir}")
