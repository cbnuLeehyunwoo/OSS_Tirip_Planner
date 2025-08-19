# trip_backend/firebase_config.py

import firebase_admin
from firebase_admin import credentials, firestore
import os

# serviceAccountKey.json 파일의 경로를 설정합니다.
# .gitignore에 이 파일이 추가되었는지 꼭 확인하세요!
cred_path = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")

try:
    cred = credentials.Certificate(cred_path)
    # 파이어베이스 앱이 아직 초기화되지 않았다면 초기화합니다.
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK가 성공적으로 초기화되었습니다.")
except FileNotFoundError:
    print(f"오류: 서비스 계정 키 파일을 찾을 수 없습니다. 경로: {cred_path}")
    print("파이어베이스 콘솔에서 키 파일을 다운로드하여 위 경로에 배치해주세요.")
    # 파일이 없으면 db 객체를 None으로 설정하여 이후 코드에서 오류를 인지할 수 있게 함
    db = None
except Exception as e:
    print(f"Firebase 초기화 중 오류 발생: {e}")
    db = None
else:
    # Firestore 클라이언트 인스턴스를 생성합니다.
    db = firestore.client()