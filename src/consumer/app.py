import base64
import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABLE_NAME = os.environ['TABLE_NAME']
TOPIC_ARN = os.environ['TOPIC_ARN']
PRICE_THRESHOLD = float(os.environ.get('PRICE_THRESHOLD', 200000))


def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)
    # Decode Kineses Data
    for record in event['Records']:
        try:
            payload_bytes = base64.b64decode(record['kinesis']['data'])
            payload_str = payload_bytes.decode('utf-8')
            data = json.loads(payload_str)
            price = float(data['price'])
            timestamp = data['timestamp']
            print(f"Processing BTC Price: ${price}")

            # Check for Anomaly
            if price < PRICE_THRESHOLD:
                print(
                    f"ALERT: Price {price}",
                    f"is below threshold {PRICE_THRESHOLD}!")
                formatted_price = "${:,.2f}".format(price)
                subject = f"🚨 BTC CRASH ALERT: {formatted_price}"
                message = (
                    "WARNING: Bitcoin has dropped below "
                    f"your threshold of ${PRICE_THRESHOLD}.\n\n"
                    f"Current Price: {formatted_price}\n"
                )

                sns.publish(
                    TopicArn=TOPIC_ARN,
                    Subject=subject,
                    Message=message
                )
            # Save to DynamoDB (requires decimals)
            item = {
                'id': data['id'],
                'timestamp': timestamp,
                'price': Decimal(str(price)),
                'source': 'Coinbase'
            }
            table.put_item(Item=item)
        except Exception as e:
            print(f"Error processing record: {e}")
            continue

    return {"status": "Batch Processed"}
