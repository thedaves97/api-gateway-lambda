import datetime
import json
import boto3
import random
import string

dynamodb = boto3.resource('dynamodb')

def insert(table, data):
    
    table.put_item(
        Item={
            'id': data['id'],
            'username': data['username'],
            'score': data['score'],
            'date': data['date'],
        }
    )
  
def get_time():
    return datetime.datetime.now()

def get_method(event):
    return event['httpMethod']

def get_address(event):
    return event['headers']['X-Forwarded-For']

def get_body(event):
    return event['body']

def get_score():
    # seed random number generator
    # random.seed(1)
    # generate some integers
    return random.randint(0, 50)


def get_id(length):
    """Generate a random string"""
    str = string.ascii_lowercase
    return ''.join(random.choice(str) for i in range(length))
	


def lambda_handler(event, context):

    # Creazione oggetto tabella dynamodb
    table = dynamodb.Table('scores')
    
    print(f"EVENTO {event}")

    # Tabella con 4 campi: id, username, punteggio e ora
    method = get_method(event)

    if method == 'POST':
        body = json.loads(get_body(event))
        print(f"BODY {body['username']}")
        print(f"BODY TYPE{type(body['username'])}")
    
    ct = get_time()
    
    obj = {
        'id': get_id(5),
        'username': body['username'],
        'score': get_score(),
        'date': str(ct)
    }

    print(obj)

    insert(table, obj)
    
    print("current time:-", ct)
    
    return {
        'statusCode': 200,
        'body': str(ct)
    }

