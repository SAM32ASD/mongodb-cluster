#!/usr/bin/env python3
"""
Insertion continue de donnees aleatoires dans sensordb.readings.
Tourne jusqu'a arret via systemctl stop continuous-insert.
Debit faible (~10-50 docs/s) pour observer la distribution dans Grafana.
"""
import pymongo
import random
import time
import signal
import sys
from datetime import datetime, timezone

MONGOS_URI = "mongodb://localhost:27017/"
BATCH_SIZE = 50
SLEEP_SECONDS = 0.5

running = True


def stop(signum, frame):
    global running
    running = False
    print(f"Signal {signum} recu, arret propre...", flush=True)


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


def generate_doc():
    return {
        "sensor_id": random.randint(1, 100_000),
        "timestamp": datetime.now(timezone.utc),
        "temperature": round(random.uniform(-10, 45), 2),
        "humidity": round(random.uniform(0, 100), 2),
        "pressure": round(random.uniform(950, 1050), 2),
        "location": {
            "lat": round(random.uniform(-90, 90), 4),
            "lon": round(random.uniform(-180, 180), 4),
        },
        "status": random.choice(["ok", "warning", "critical"]),
        "batch": "continuous",
    }


def main():
    print(f"Connexion a {MONGOS_URI}...", flush=True)
    client = pymongo.MongoClient(
        MONGOS_URI,
        serverSelectionTimeoutMS=15000,
        connectTimeoutMS=15000,
    )
    client.admin.command("ping")
    print("Connexion OK", flush=True)

    collection = client.sensordb.readings
    total = 0
    start = time.time()

    while running:
        batch = [generate_doc() for _ in range(BATCH_SIZE)]
        try:
            collection.insert_many(batch, ordered=False)
            total += len(batch)
            elapsed = time.time() - start
            rate = total / elapsed if elapsed > 0 else 0
            print(
                f"[{datetime.now().strftime('%H:%M:%S')}] "
                f"Inserted batch of {BATCH_SIZE} "
                f"(total={total:,}, rate={rate:.1f} docs/s)",
                flush=True,
            )
        except Exception as exc:
            print(f"Erreur insertion: {exc}", flush=True)
            time.sleep(5)
        time.sleep(SLEEP_SECONDS)

    print(f"Arret. Total insere: {total:,} documents", flush=True)
    client.close()


if __name__ == "__main__":
    main()
