import base64
import json
import os
import boto3
from decimal import Decimal
from datetime import datetime, timedelta
from boto3.dynamodb.conditions import Key

# forcing update

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABLE_NAME = os.environ['TABLE_NAME']
TOPIC_ARN = os.environ['TOPIC_ARN']


def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)
    for record in event['Records']:
        try:
            # Parse Current Data (Kinesis Sends In Base64)
            payload_bytes = base64.b64decode(record['kinesis']['data'])
            data = json.loads(payload_bytes.decode('utf-8'))
            current_price = float(data['price'])
            current_id = data['id']
            print(f"Processing {current_id}: ${current_price}")

            # Query Past Data (10 Hours)
            past_time = (datetime.utcnow() - timedelta(hours=10)).isoformat()
            response = table.query(
                KeyConditionExpression=Key('id').eq(current_id)
                & Key('timestamp').lte(past_time),
                ScanIndexForward=False,
                Limit=1
            )

            # Check Percent Drop
            if response['Items']:
                old_price = float(response['Items'][0]['price'])
                drop_percent = ((old_price - current_price) / old_price) * 100
                print(
                    f"Price 10h ago: ${old_price} "
                    f"| Drop: {drop_percent:.2f}%"
                )
                if drop_percent >= 5.0:
                    message = (
                        f"🚨 CRASH ALERT: {current_id} is down"
                        f"{drop_percent:.2f}% in 10h!\n"
                        f"Current: ${current_price:,.2f}\n"
                        f"10h Ago: ${old_price:,.2f}"
                    )
                    sns.publish(
                        TopicArn=TOPIC_ARN,
                        Subject="Crypto Crash Alert",
                        Message=message)
            else:
                print("Not enough history to calculate 10h dip yet.")

            # Save Current Record
            item = {
                'id': current_id,
                'timestamp': data['timestamp'],
                'price': Decimal(str(current_price)),
                'source': 'Coinbase'
            }
            table.put_item(Item=item)

        except Exception as e:
            print(f"Error: {e}")
            continue

    return {"status": "Batch Processed"}
