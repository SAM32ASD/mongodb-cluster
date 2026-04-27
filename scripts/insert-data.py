#!/usr/bin/env python3
import pymongo
import random
import time
from datetime import datetime
import sys

# Récupérer l'IP depuis les arguments ou demander
if len(sys.argv) > 1:
    MONGOS_IP = sys.argv[1]
else:
    MONGOS_IP = input("IP du mongos US (voir terraform output): ").strip() or "localhost"

print(f"Connecting to {MONGOS_IP}:27017...")
client = pymongo.MongoClient(
    f"mongodb://{MONGOS_IP}:27017/",
    serverSelectionTimeoutMS=15000,
    connectTimeoutMS=15000,
    socketTimeoutMS=60000
)
print("Testing connection...")
client.admin.command('ping')
print("Connection successful!")

db = client.sensordb
collection = db.readings

TARGET_DOCS = 1_500_000
BATCH_SIZE = 1000

def generate_doc(doc_id):
    return {
        "_id": doc_id,
        "sensor_id": random.randint(1, 10000),
        "region": random.choice(["US", "EU", "AP"]),
        "temperature": round(random.uniform(-20, 50), 2),
        "humidity": round(random.uniform(0, 100), 2),
        "pressure": round(random.uniform(980, 1050), 2),
        "timestamp": datetime.utcnow(),
        "status": random.choice(["active", "inactive", "maintenance"]),
        "readings": [round(random.uniform(0, 100), 2) for _ in range(20)],
        "metadata": {
            "firmware": f"1.{random.randint(0,9)}.{random.randint(0,99)}",
            "battery": random.randint(0, 100),
            "location": {
                "lat": round(random.uniform(-90, 90), 6),
                "lon": round(random.uniform(-180, 180), 6)
            },
            "padding": "X" * 300
        }
    }

def main():
    print(f"=== Insertion de {TARGET_DOCS:,} documents (~1.5 GB) ===")

    print("Clearing existing data...")
    collection.delete_many({})
    print("Data cleared!")
    
    start = time.time()
    inserted = 0
    
    for i in range(0, TARGET_DOCS, BATCH_SIZE):
        batch = [generate_doc(j) for j in range(i, i + BATCH_SIZE)]
        try:
            collection.insert_many(batch, ordered=False)
            inserted += len(batch)
        except Exception as e:
            print(f"Erreur batch {i}: {e}")
        
        if i % 50000 == 0:
            print(f"Progress: {(i/TARGET_DOCS)*100:.1f}% ({inserted:,} docs)")
    
    duration = time.time() - start
    stats = db.command("collStats", "readings")
    
    print(f"\n=== RÉSULTATS ===")
    print(f"Documents: {inserted:,}")
    print(f"Taille: {stats['size'] / (1024**2):.2f} MB")
    print(f"Storage: {stats['storageSize'] / (1024**2):.2f} MB")
    print(f"Chunks: {stats.get('chunks', 'N/A')}")
    print(f"Débit: {inserted/duration:.0f} docs/sec")
    print(f"Temps: {duration:.2f}s")

if __name__ == "__main__":
    main()