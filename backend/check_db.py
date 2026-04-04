from pymongo import MongoClient
c = MongoClient('mongodb://localhost:27017')
db = c['agrilens']
print('Users:', list(db.users.find({}, {'name':1, 'phone':1, 'role':1})))
print('Farms:', list(db.farms.find({}, {'name':1, 'owner_id':1})))
print('Scans:', list(db.scans.find({}, {'status':1, 'detection_result.disease':1})))
