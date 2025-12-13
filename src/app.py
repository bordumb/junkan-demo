import os
# Expects payment_db_host from Terraform
DB_HOST = os.getenv("PAYMENT_DB_HOST")

def connect():
    if not DB_HOST:
        raise ValueError("Database host not configured!")
    print(f"Connecting to {DB_HOST}...")
