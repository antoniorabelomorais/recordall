#!/data/data/com.termux/files/usr/bin/zsh
# circular_rec.zsh — Gravação contínua com watchdog e rotação de espaço

# CONFIGURAÇÕES
RECORD_DIR="$HOME/recordings"
SEGMENT_SECONDS=300      # duração de cada segmento (5 min)
MAX_STORAGE_MB=10240     # limite total (10 GB)
BITRATE=64               # kbps AAC
SLEEP_BETWEEN=1          # pausa entre segmentos (segundos)
MAX_RETRIES=5            # número máximo de falhas seguidas antes de cooldown
COOLDOWN_SECONDS=60      # tempo de espera após falhas contínuas

mkdir -p "$RECORD_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_space() {
  local used=$(du -sm "$RECORD_DIR" | awk '{print $1}')
  while [ "$used" -gt "$MAX_STORAGE_MB" ]; do
    oldest=$(ls -t "$RECORD_DIR" | tail -n 1)
    rm -f "$RECORD_DIR/$oldest"
    log "🧹 Espaço cheio (${used}MB), removido: $oldest"
    used=$(du -sm "$RECORD_DIR" | awk '{print $1}')
  done
}

record_segment() {
  local filename="$RECORD_DIR/rec_$(date '+%Y%m%d_%H%M%S').m4a"
  log "🎙️ Gravando: $filename"
  termux-microphone-record -f "$filename" -l "$SEGMENT_SECONDS" -e aac -b "$BITRATE" -r 44100 -c 1
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
  log "⚠️ Falha ao gravar ($exit_code)"
  return 1
  fi
  log "✅ Segmento salvo: $filename"
  return 0

}

# Impede o Android de hibernar Termux
termux-wake-lock
log "🚀 Iniciando gravação contínua com watchdog..."

fail_count=0

while true; do
  record_segment
  if [ "$?" -eq 0 ]; then
    fail_count=0
    check_space
    sleep "$SLEEP_BETWEEN"
  else
    fail_count=$((fail_count + 1))
    log "💀 Falha consecutiva #$fail_count"
    if [ "$fail_count" -ge "$MAX_RETRIES" ]; then
      log "😴 Muitas falhas seguidas, aguardando ${COOLDOWN_SECONDS}s..."
      sleep "$COOLDOWN_SECONDS"
      fail_count=0
    else
      sleep 5
    fi
  fi
done
