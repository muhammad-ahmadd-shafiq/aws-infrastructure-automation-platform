from flask import Flask, render_template, jsonify
import psutil
import socket
import platform
import os
from datetime import datetime
import shutil

try:
    import docker
    docker_client = docker.from_env()
except:
    docker_client = None

app = Flask(__name__)

def get_uptime():
    boot_time = datetime.fromtimestamp(psutil.boot_time())
    uptime = datetime.now() - boot_time
    return str(uptime).split(".")[0]

def get_containers():
    if docker_client:
        try:
            containers = docker_client.containers.list()
            return [
                {
                    "name": c.name,
                    "status": c.status
                }
                for c in containers
            ]
        except:
            return []
    return []

@app.route("/")
def dashboard():

    total, used, free = shutil.disk_usage("/")
    containers = get_containers()

    data = {
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "cpu": psutil.cpu_percent(interval=1),
        "memory": psutil.virtual_memory().percent,
        "disk": psutil.disk_usage("/").percent,
        "uptime": get_uptime(),
        "container_count": len(containers),
        "containers": containers,
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "build": os.getenv("BUILD_NUMBER", "local"),
        "disk_total": round(total / (1024**3), 2),
        "disk_used": round(used / (1024**3), 2),
        "disk_free": round(free / (1024**3), 2),
    }

    return render_template("index.html", data=data)

@app.route("/health")
def health():

    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "containers": len(get_containers())
    })

@app.route("/api/metrics")
def metrics():

    return jsonify({
        "cpu": psutil.cpu_percent(),
        "memory": psutil.virtual_memory().percent,
        "disk": psutil.disk_usage("/").percent,
        "uptime": get_uptime()
    })

@app.route("/api/containers")
def containers():
    return jsonify(get_containers())

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)