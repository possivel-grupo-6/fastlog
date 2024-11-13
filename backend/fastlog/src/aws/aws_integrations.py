import json
import boto3
import platform
from os import getenv

os = platform.system()

if os == "Windows":
    session = boto3.Session(
        aws_access_key_id=getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=getenv("AWS_SECRET_ACCESS_KEY"),
        aws_session_token=getenv("AWS_SESSION_TOKEN")
    )

else:
    session = boto3.Session()

s3_client = session.client("s3")
bucket_fastlog = getenv("BUCKET_FAST_LOG")

def send_json_to_s3(json_data: dict, json_name: str):    
    s3_client.put_object(
        Bucket=bucket_fastlog,
        Key=json_name,
        Body=json.dumps(json_data).encode('UTF-8')
    )
    print(f"{json_name} - {json_data} sended to bucket")