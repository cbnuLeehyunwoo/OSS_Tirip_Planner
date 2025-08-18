# test_api.py
import requests
import json

# API 주소
url = "http://127.0.0.1:5000/api/plan-trip"

# 보낼 데이터
payload = {
    "prompt": "key : value 형태로 title, date, time and weather 별 일정 짜줘"
}

# 헤더 설정
headers = {
    "Content-Type": "application/json"
}

# POST 요청 보내기
response = requests.post(url, headers=headers, json=payload)

# 응답 확인
print(f"Status Code: {response.status_code}")
print("Response JSON:")
print(response.json())