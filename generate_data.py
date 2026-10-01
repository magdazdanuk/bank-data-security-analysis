import os
import random
from datetime import datetime, timedelta
import psycopg2
from faker import Faker

# Initialize Faker for Polish realistic banking data
fake = Faker('pl_PL')

# Database Connection Settings (Update via environment variables or direct config)
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "banking_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

def seed_customers(cursor, count=100):
    print(f"Generating {count} customers...")
    customer_ids = []
    for _ in range(count):
        first_name = fake.first_name()
        last_name = fake.last_name()
        email = fake.unique.email()
        phone = fake.phone_number()
        
        cursor.execute(
            """
            INSERT INTO customers (first_name, last_name, email, phone)
            VALUES (%s, %s, %s, %s) RETURNING customer_id;
            """,
            (first_name, last_name, email, phone)
        )
        customer_ids.append(cursor.fetchone()[0])
    return customer_ids

def seed_transactions(cursor, customer_ids, count=2000):
    print(f"Generating {count} realistic banking transactions...")
    cities = ['Warszawa', 'Kraków', 'Wrocław', 'Gdańsk', 'Poznań', 'Katowice', 'Łódź']
    tx_types = ['CARD_PAYMENT', 'TRANSFER', 'ATM_WITHDRAWAL', 'LOAN_REPAYMENT']
    categories = ['Groceries', 'Electronics', 'Travel', 'Dining', 'Utilities', 'Entertainment']

    base_time = datetime.now() - timedelta(days=60)

    for i in range(count):
        cust_id = random.choice(customer_ids)
        amount = round(random.triangular(10.0, 5000.0, 150.0), 2)
        tx_type = random.choice(tx_types)
        category = random.choice(categories)
        city = random.choice(cities)
        
        # Incremental timestamp generation
        tx_time = base_time + timedelta(minutes=random.randint(1, 45) * i)

        cursor.execute(
            """
            INSERT INTO transactions 
            (customer_id, amount, currency, transaction_type, merchant_category, location_city, transaction_time)
            VALUES (%s, %s, 'PLN', %s, %s, %s, %s);
            """,
            (cust_id, amount, tx_type, category, city, tx_time)
        )

def main():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        print("Connected to PostgreSQL successfully.")
        cust_ids = seed_customers(cursor, count=50)
        seed_transactions(cursor, cust_ids, count=1000)
        
        conn.commit()
        print("Data ingestion pipeline completed successfully!")
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error executing ingestion script: {e}")

if __name__ == "__main__":
    main()
