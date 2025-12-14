import json
import os
import boto3
from boto3.dynamodb.conditions import Key
from datetime import datetime, timedelta
from decimal import Decimal

# force update

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ['TABLE_NAME']


# Decimal to float for JSON
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    # Get data from last 24 hours
    day_ago = (datetime.utcnow() - timedelta(hours=24)).isoformat()
    try:
        response = table.query(
            KeyConditionExpression=Key('id').eq('bitcoin')
            & Key('timestamp').gte(day_ago)
        )
        items = response.get('Items', [])
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(items, cls=DecimalEncoder)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": str(e)
        }
