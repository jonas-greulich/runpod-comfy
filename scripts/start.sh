#!/usr/bin/env bash
# Pod-Start: SSH an, Modelle des Profils laden, Workflows einspielen, ComfyUI starten.
# Env-Vars: PROFILE (Default: bild), HF_TOKEN, CIVITAI_TOKEN, PUBLIC_KEY (setzt RunPod)
set -euo pipefail

PROFILE="${PROFILE:-bild}"
COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
PROFILE_FILE="/opt/profiles/${PROFILE}.txt"
MODELS_DIR="${COMFY_DIR}/models"

log() { echo "[start] $*"; }

# --- SSH für comfy-pull / comfy-stop -------------------------------------
if [[ -n "${PUBLIC_KEY:-}" ]]; then
  mkdir -p /root/.ssh
  echo "${PUBLIC_KEY}" > /root/.ssh/authorized_keys
  chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys
  ssh-keygen -A >/dev/null
  /usr/sbin/sshd
  log "sshd läuft"
fi

# --- Modelle laden --------------------------------------------------------
download() {
  local src="$1" dir="$2" name="$3" url
  local -a hdr=()
  case "$src" in
    hf:*)
      local path="${src#hf:}"
      local repo; repo="$(cut -d/ -f1-2 <<<"$path")"
      local file; file="$(cut -d/ -f3- <<<"$path")"
      url="https://huggingface.co/${repo}/resolve/main/${file}"
      [[ -n "${HF_TOKEN:-}" ]] && hdr=(--header="Authorization: Bearer ${HF_TOKEN}")
      ;;
    civitai:*)
      url="https://civitai.com/api/download/models/${src#civitai:}"
      [[ -n "${CIVITAI_TOKEN:-}" ]] && hdr=(--header="Authorization: Bearer ${CIVITAI_TOKEN}")
      ;;
    http*) url="$src" ;;
    *) log "unbekannte Quelle: $src"; return 1 ;;
  esac

  mkdir -p "${MODELS_DIR}/${dir}"
  if [[ -s "${MODELS_DIR}/${dir}/${name}" ]]; then
    log "vorhanden: ${dir}/${name}"
    return 0
  fi
  log "lade ${dir}/${name}"
  if [[ "$src" == civitai:* ]]; then
    # Civitai leitet auf einen signierten Storage-Link um. aria2c schickt den
    # Authorization-Header dorthin mit, der Storage antwortet dann mit 400.
    # curl lässt den Header bei Umleitung auf einen anderen Host weg.
    curl -fL --retry 3 -o "${MODELS_DIR}/${dir}/${name}.part" "${hdr[@]/--header=/-H}" "$url" \
      && mv "${MODELS_DIR}/${dir}/${name}.part" "${MODELS_DIR}/${dir}/${name}"
  else
    aria2c --console-log-level=warn --summary-interval=30 -x 16 -s 16 -k 1M \
      "${hdr[@]}" -d "${MODELS_DIR}/${dir}" -o "${name}" "$url"
  fi
}

# Ganzes Hugging-Face-Repo laden (z. B. eigene LoRAs), Unterordner bleiben erhalten
download_repo() {
  local repo="$1" dir="$2" f sub
  local -a hdr=()
  [[ -n "${HF_TOKEN:-}" ]] && hdr=(-H "Authorization: Bearer ${HF_TOKEN}")
  local list
  list="$(curl -fsSL "${hdr[@]}" "https://huggingface.co/api/models/${repo}/tree/main?recursive=true" \
    | python -c 'import json,sys; [print(e["path"]) for e in json.load(sys.stdin) if e.get("type")=="file" and not e["path"].startswith(".") and not e["path"].endswith((".md",".gitattributes"))]')" \
    || { log "Repo nicht lesbar: ${repo}"; return 1; }
  [[ -z "$list" ]] && { log "Repo leer: ${repo}"; return 0; }
  local rc=0
  while read -r f; do
    sub="$(dirname "$f")"; [[ "$sub" == "." ]] && sub="" || sub="/${sub}"
    download "hf:${repo}/${f}" "${dir}${sub}" "$(basename "$f")" || { log "FEHLER: ${f}"; rc=1; }
  done <<<"$list"
  return $rc
}

if [[ ! -f "$PROFILE_FILE" ]]; then
  log "Profil nicht gefunden: $PROFILE_FILE"
  exit 1
fi

log "Profil: $PROFILE"
failed=0
while read -r src dir name; do
  [[ -z "${src:-}" || "$src" == \#* ]] && continue
  if [[ "$src" == hfrepo:* ]]; then
    download_repo "${src#hfrepo:}" "$dir" || failed=1
  else
    download "$src" "$dir" "$name" || { log "FEHLER: $name"; failed=1; }
  fi
done < "$PROFILE_FILE"
[[ $failed -eq 1 ]] && log "Nicht alle Modelle geladen, ComfyUI startet trotzdem"

# --- Workflows einspielen ---------------------------------------------------
WF_DST="${COMFY_DIR}/user/default/workflows"
mkdir -p "$WF_DST"
if [[ -d "/opt/workflows/${PROFILE}" ]]; then
  cp -n /opt/workflows/"${PROFILE}"/*.json "$WF_DST"/ 2>/dev/null || true
  log "Workflows aus /opt/workflows/${PROFILE} eingespielt"
fi

# --- ComfyUI ---------------------------------------------------------------
log "starte ComfyUI auf Port 8188"
cd "$COMFY_DIR"
exec python main.py --listen 0.0.0.0 --port 8188
