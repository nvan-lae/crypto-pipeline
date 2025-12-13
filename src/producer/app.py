import json
import os
import urllib.request
import boto3
from datetime import datetime

kinesis = boto3.client('kinesis')
STREAM_NAME = os.environ['STREAM_NAME']


# Fetch current Bitcoin price
def lambda_handler(event, context):
    url = "https://api.coinbase.com/v2/prices/BTC-USD/spot"
    try:
        with urllib.request.urlopen(url) as response:
            raw_data = json.loads(response.read().decode())
            price = float(raw_data['data']['amount'])
            print(f"BTC Price fetched from Coinbase: ${price}")
    except Exception as e:
        print(f"Error fetching price: {e}")
        return {"status": "Error", "message": str(e)}

    payload = {
        'id': 'bitcoin',
        'price': price,
        'timestamp': datetime.utcnow().isoformat()
    }

    kinesis.put_record(
        StreamName=STREAM_NAME,
        Data=json.dumps(payload),
        PartitionKey='bitcoin'
    )

    return {
        "status": "Success",
        "source": "Coinbase",
        "price": price
    }
