from pymongo import MongoClient
from dotenv import load_dotenv
import os

load_dotenv()
uri = os.getenv('MONGO_URI')
c = MongoClient(uri)
db = c['agrilens']
print('Users:', list(db.users.find({}, {'name':1, 'phone':1, 'role':1})))
print('Farms:', list(db.farms.find({}, {'name':1, 'owner_id':1})))
print('Scans:', list(db.scans.find({}, {'status':1, 'detection_result.disease':1, 'image_url':1, 'storage_backend':1})))