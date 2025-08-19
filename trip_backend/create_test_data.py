# trip_backend/create_test_data.py
from firebase_config import db
import datetime

def create_initial_trip():
    if db is None:
        print("Firebase에 연결할 수 없습니다. 설정을 확인하세요.")
        return

    # 만들 여행 데이터
    test_trip_id = "my-busan-trip-123"
    trip_info = {
        "userId": "user_test_abc",
        "destination": "부산",
        "tripPeriod": "2박 3일",
        "numPeople": "2명",
        "theme": "맛집과 카페 위주의 힐링 여행",
        "additionalRequest": "너무 붐비는 곳은 피하고 싶어요. 예쁜 사진 찍을 곳도 추천해주세요.",
        "status": "pending", # 계획 생성 대기 상태
        "createdAt": datetime.datetime.now()
    }

    # Firestore의 'trips' 컬렉션에 문서 생성
    db.collection('trips').document(test_trip_id).set(trip_info)
    print(f"테스트 데이터 생성 완료! tripId: {test_trip_id}")

if __name__ == "__main__":
    create_initial_trip()