"""
Database connection module.
Initializes and provides access to the MongoDB client.
"""
import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/agrilens')

client = MongoClient(MONGO_URI)
db = client.get_default_database()


def get_db():
    """Returns the MongoDB database instance."""
    return db
