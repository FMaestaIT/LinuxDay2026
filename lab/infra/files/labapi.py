"""Claude Lab API: piccola API di gestione server usata nella demo.

La specifica completa è su /openapi.json, la documentazione interattiva su /docs.
Tutti gli endpoint tranne /health richiedono l'header "Authorization: Bearer <token>".
"""

import json
import os
import re
import shutil
import socket
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

API_TOKEN = os.environ["API_TOKEN"]
STATE_DIR = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/labapi"))
DEPLOYMENTS_FILE = STATE_DIR / "deployments.json"
SERVICES = ["nginx", "labapi", "cron", "systemd-journald"]

app = FastAPI(
    title="Claude Lab API",
    version="1.0.0",
    description="API di gestione del server vm-api: stato, servizi, log e deploy simulati.",
)
bearer = HTTPBearer()


def require_token(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> None:
    if creds.credentials != API_TOKEN:
        raise HTTPException(status_code=401, detail="Token non valido")


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def load_deployments() -> list[dict]:
    if DEPLOYMENTS_FILE.exists():
        return json.loads(DEPLOYMENTS_FILE.read_text())
    return [{"version": "1.0.0", "note": "installazione iniziale", "deployed_at": now()}]


class DeployRequest(BaseModel):
    version: str = Field(description="Versione semantica, es. 1.1.0")
    note: str | None = Field(default=None, max_length=200)


@app.get("/health", summary="Liveness check (senza autenticazione)")
def health():
    return {"status": "ok"}


@app.get("/status", summary="Stato del server", dependencies=[Depends(require_token)])
def status():
    meminfo = dict(
        line.split(":", 1) for line in Path("/proc/meminfo").read_text().splitlines()
    )
    mem_kb = {k: int(meminfo[k].split()[0]) for k in ("MemTotal", "MemAvailable")}
    disk = shutil.disk_usage("/")
    uptime_s = float(Path("/proc/uptime").read_text().split()[0])
    return {
        "hostname": socket.gethostname(),
        "time": now(),
        "uptime_hours": round(uptime_s / 3600, 2),
        "load_avg": os.getloadavg(),
        "memory_mb": {"total": mem_kb["MemTotal"] // 1024, "available": mem_kb["MemAvailable"] // 1024},
        "disk_root_gb": {"total": round(disk.total / 1e9, 1), "free": round(disk.free / 1e9, 1)},
        "current_version": load_deployments()[-1]["version"],
    }


@app.get("/services", summary="Stato dei servizi monitorati", dependencies=[Depends(require_token)])
def services():
    result = {}
    for name in SERVICES:
        proc = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
        result[name] = proc.stdout.strip()
    return result


@app.get("/logs", summary="Ultime righe di log di un servizio", dependencies=[Depends(require_token)])
def logs(
    service: str = Query(description=f"Uno tra: {', '.join(SERVICES)}"),
    lines: int = Query(default=50, ge=1, le=500),
):
    if service not in SERVICES:
        raise HTTPException(status_code=404, detail=f"Servizio sconosciuto: {service}")
    proc = subprocess.run(
        ["journalctl", "-u", service, "-n", str(lines), "--no-pager", "-o", "short-iso"],
        capture_output=True,
        text=True,
    )
    return {"service": service, "lines": proc.stdout.splitlines()}


@app.get("/deployments", summary="Storico dei deploy", dependencies=[Depends(require_token)])
def list_deployments():
    return load_deployments()


@app.post("/deployments", status_code=201, summary="Esegue un deploy (simulato)", dependencies=[Depends(require_token)])
def create_deployment(req: DeployRequest):
    if not re.fullmatch(r"\d+\.\d+\.\d+", req.version):
        raise HTTPException(status_code=422, detail="version deve essere nel formato X.Y.Z")
    history = load_deployments()
    if req.version == history[-1]["version"]:
        raise HTTPException(status_code=409, detail=f"La versione {req.version} è già in produzione")
    entry = {"version": req.version, "note": req.note, "deployed_at": now()}
    history.append(entry)
    DEPLOYMENTS_FILE.write_text(json.dumps(history, indent=2))
    return entry
