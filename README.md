# runpod-comfy

ComfyUI-Image für RunPod. Ein Image ohne Modelle; beim Pod-Start lädt `scripts/start.sh` die Modelle des gewählten Profils.

**Übersicht über Templates, Modelle, Workflows und Ablauf: [KATALOG.md](KATALOG.md).**

## Aufbau

| Pfad | Inhalt |
|---|---|
| `Dockerfile` | Ubuntu 24.04, Python 3.12, PyTorch cu128, ComfyUI (Tag gepinnt) |
| `custom_nodes.txt` | Custom Nodes mit Commit, gelten für alle Profile |
| `profiles/<name>.txt` | Modell-Downloads pro Profil |
| `workflows/<name>/` | Workflow-JSONs, landen beim Start im ComfyUI-Menü |
| `scripts/start.sh` | SSH, Modell-Download, Workflows, ComfyUI-Start |
| `mac/` | Mac-Skripte: `comfy-pull` (Ergebnisse holen), `lora-upload`, `install.sh` |

## Pod-Env-Vars

| Variable | Zweck |
|---|---|
| `PROFILE` | `bild`, `flux`, `ltx` (Default `bild`) |
| `HF_TOKEN` | Hugging Face Read-Token (Pflicht für Flux 2) |
| `CIVITAI_TOKEN` | Civitai API-Key |
| `PUBLIC_KEY` | setzt RunPod automatisch aus dem Account-SSH-Key |

## Build

Push auf `main` → GitHub Action baut `ghcr.io/<owner>/runpod-comfy:latest` (linux/amd64).

## Profilformat

```
<quelle>  <zielordner unter models/>  <dateiname>
hf:<repo>/<pfad>  |  civitai:<modelVersionId>  |  hfrepo:<repo> (ganzes Repo)  |  https://…
```
