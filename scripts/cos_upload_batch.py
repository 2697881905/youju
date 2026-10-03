#!/usr/bin/env python3
"""Batch upload local files to COS using cos-python-sdk-v5 (tmp STS credentials).
Reads a JSON list: [{local_path, bucket, region, secret_id, secret_key, token, cos_key, content_type}]
Prints one line per item: OK <etag> or ERR <msg>.
"""
import sys, json
from qcloud_cos import CosConfig, CosS3Client

def main():
    batch = json.load(open(sys.argv[1], encoding="utf-8"))
    for it in batch:
        try:
            conf = CosConfig(
                Region=it["region"],
                SecretId=it["secret_id"],
                SecretKey=it["secret_key"],
                Token=it["token"],
                Endpoint=f"cos.{it['region']}.myqcloud.com",
            )
            client = CosS3Client(conf)
            with open(it["local_path"], "rb") as f:
                body = f.read()
            resp = client.put_object(
                Bucket=it["bucket"],
                Body=body,
                Key=it["cos_key"],
                ContentType=it["content_type"],
            )
            etag = resp.get("ETag", "")
            print(f"OK {it['cos_key']} {etag}")
        except Exception as e:
            print(f"ERR {it['cos_key']} {type(e).__name__}: {e}")

if __name__ == "__main__":
    main()
