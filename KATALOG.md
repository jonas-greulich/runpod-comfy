# Katalog runpod-comfy

Stand: 08.10.2026. Diese Datei ist die Übersicht über alles, was auf RunPod läuft. Wer etwas ändert (Modell, Workflow, Template, Skript), trägt es hier im selben Commit ein.

## Ablage auf dem Mac

| Pfad | Inhalt |
|---|---|
| `~/PROJEKTE/runpod/runpod-comfy/` | dieses Repo (GitHub `jonas-greulich/runpod-comfy`), einzige Quelle für Image, Profile, Workflows, Mac-Skripte |
| `~/PROJEKTE/runpod/runpod-comfy/mac/` | `comfy-pull`, `lora-upload`, `install.sh` |
| `~/PROJEKTE/runpod/output/<Datum>/<Pod-Name>/` | Ergebnisse aller Pods, holt der Hintergrunddienst automatisch |
| `~/bin/comfy-pull`, `~/bin/lora-upload` | Symlinks ins Repo (legt `install.sh` an) |
| `~/Library/Logs/comfy-pull.log` | Log des Hintergrunddienstes |
| `~/.config/comfy-pull/<pod>.txt` | Merkliste schon geladener Dateien je Pod |
| `~/ComfyUI/models/loras/` | eigene LoRAs (Quelle für `lora-upload`) |

## Image

`ghcr.io/jonas-greulich/runpod-comfy:latest`, gebaut per GitHub Action bei jedem Push auf `main`. Ubuntu 24.04, Python 3.12, PyTorch cu128, ComfyUI v0.39.1. Keine Modelle im Image, `scripts/start.sh` lädt sie beim Pod-Start je nach `PROFILE`.

Custom Nodes (für alle Profile, Commit gepinnt in `custom_nodes.txt`): ComfyUI-Manager, was-node-suite-comfyui, Comfyroll, ComfyUI_yanc, RES4LYF, rgthree-comfy, VideoHelperSuite.

## Templates (RunPod)

| Template | ID | PROFILE | GPU | Status |
|---|---|---|---|---|
| comfy-bild | `4lvgyvzo5n` | bild | RTX 4090 (Secure 0,74 $/h) | läuft, mehrfach genutzt |
| comfy-ltx | `lahqon0bno` | ltx | RTX PRO 6000 96 GB, Disk 80 GB | gebaut, noch nicht getestet |
| comfyUI - M3 Max | `uqt3ombt7n` | (altes Image runpod-ltx2) | | Altbestand, nicht mehr nutzen |

Secrets im RunPod-Account: `hf_token`, `civitai_token`. SSH-Key im Account: id_ed25519_runpod.

## Profile und Modelle

### bild (`profiles/bild.txt`)

| Ordner | Datei | Quelle |
|---|---|---|
| checkpoints | Juggernaut_X_RunDiffusion.safetensors | HF RunDiffusion/Juggernaut-X-v10 |
| checkpoints | waiANIHENTAIPONYXL_v60.safetensors | Civitai Version 952743 |
| upscale_models/upscalers_v10/general | 4x_NMKD-Superscale-SP_178000_G.pth | HF uwg/upscaler |
| loras | alle eigenen LoRAs | privates HF-Repo kosmonaut7/loras (`hfrepo:`) |

Offen: WAI-Illustrious (Civitai-Version-ID fehlt).

### ltx (`profiles/ltx.txt`)

LTX-2.5 (Lightricks), alle Nodes nativ in ComfyUI v0.39.1.

| Ordner | Datei |
|---|---|
| diffusion_models | ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors |
| text_encoders | gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors |
| text_encoders | gemma4_e2b_it_int8_convrot.safetensors (Comfy-Org/gemma-4) |
| vae | ltx-2.5-video-vae-bf16.safetensors, ltx-2.5-audio-vae-bf16.safetensors |
| latent_upscale_models | ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors |

### geplant

| Profil | Stand |
|---|---|
| flux | Flux dev, Lizenz nur nicht-kommerziell, vor Einsatz für Kundenjobs klären |
| minimax | MiniMax H3, Lizenz schließt EU aus, vor Einsatz klären |

## Workflows

| Profil | Datei | Herkunft |
|---|---|---|
| bild | `workflows/bild/comic_panels_11.json` | Jonas, Comic-Panels mit Load-Checkpoint-Auswahl, Stand 08.10. (Style/Negative vorbelegt, zwei weitere LoRA-Loader, Node Appearance & Surrounding) |
| ltx | `workflows/ltx/LTX-2.5 Text to Video.json` | offizielle ComfyUI-Vorlage |
| ltx | `workflows/ltx/LTX-2.5 Image to Video.json` | offizielle ComfyUI-Vorlage |
| ltx | `workflows/ltx/LTX-2.5 Start-Endbild.json` | offizielle ComfyUI-Vorlage |

## Ablauf

1. **Pod starten:** Claude über das RunPod-MCP (Template-ID oben, `startSsh: true`) oder Console → Deploy → Template wählen.
2. **Warten:** Image ziehen plus Modelle laden dauert 3 bis 15 Minuten, je nach Host. Fertig, wenn in der Console neben Port 8188 „Ready“ steht.
3. **ComfyUI öffnen:** `https://<POD-ID>-8188.proxy.runpod.net` oder Console → Connect → HTTP Service.
4. **Ergebnisse:** kommen automatisch nach `~/PROJEKTE/runpod/output/`, mit Mitteilung auf dem Mac. Nichts zu tun. Manuell im Terminal geht weiterhin `comfy-pull --watch <POD-ID>`.
5. **Beenden:** Console → Stop (Disk bleibt, kostet weiter Speicher) oder Terminate (alles weg). Die Ergebnisse liegen dann schon auf dem Mac.

## Regeln

- Workflows, die auf dem Pod geändert und gespeichert werden, sind beim Terminieren weg. Ins Template kommt eine Änderung nur per Export (Workflow → Export) und Austausch der Datei unter `workflows/<profil>/`. `start.sh` überschreibt beim Start die Pod-Version mit der Repo-Version.

- Neue Modelle, Workflows oder Custom Nodes kommen nur über dieses Repo dazu (Profil-Datei, `workflows/<profil>/`, `custom_nodes.txt`) und werden hier eingetragen. Was nur auf einem laufenden Pod installiert wird, ist beim nächsten Pod weg.
- Ein neues Profil heißt: `profiles/<name>.txt`, `workflows/<name>/`, Template in RunPod mit `PROFILE=<name>`, Zeile in den Tabellen oben.
- Eigene LoRAs: in `~/ComfyUI/models/loras/` legen, `lora-upload` ausführen, nächster bild-Pod hat sie.
- Ergebnisse vom Pod gelten als Rohmaterial. Was in ein Filmprojekt gehört, wird aus `output/` in dessen Ordner verschoben.

## Offen

- Basic Auth für ComfyUI (Proxy-URL ist sonst für jeden mit Link offen)
- Image-Tag pinnen statt `latest`
- LTX-Pod testen
- Profile flux und minimax
