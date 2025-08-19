import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
from dotenv import load_dotenv
import json
from flask_cors import CORS
from datetime import datetime, timedelta
from firebase_config import db  # Firebase 연결 객체
from prompt_utils import create_travel_prompt # 프롬프트 생성 함수

load_dotenv()

# --- 모델 로딩 ---
print("모델을 로딩하는 중입니다...")
try:
    model_id = "google/gemma-2-9b-it" 
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(
        model_id, torch_dtype=torch.bfloat16, device_map="auto"
    )
    print("모델 로딩이 완료되었습니다.")
except Exception as e:
    print(f"모델 로딩 중 오류 발생: {e}")
    exit()

# --- Flask 앱 초기화 --- 
app = Flask(__name__)
CORS(app)


# --- 유틸리티 함수들 (두 브랜치에서 필요한 함수들을 결합) ---

def parse_gemma_response_to_json(response_text):
    """Gemma가 생성한 텍스트에서 JSON 부분만 안전하게 추출하고 파싱합니다."""
    try:
        # 응답이 코드 블록(```json ... ```) 안에 있을 경우를 대비해 처리
        if '```json' in response_text:
            response_text = response_text.split('```json')[1].split('```')[0]
            
        json_start_index = response_text.find('[')
        if json_start_index != -1:
            json_end_index = response_text.rfind(']')
            if json_end_index != -1:
                json_string = response_text[json_start_index : json_end_index + 1]
                return json.loads(json_string)
        return None
    except Exception as e:
        print(f"JSON 파싱 중 오류 발생: {e}\n원본 응답: {response_text}")
        return None

def transform_plan_data(plan_list):
    """파싱된 JSON 리스트를 Firestore 저장용 딕셔셔너리(날짜별 그룹화)로 변환합니다."""
    plans_by_date = {}
    if not isinstance(plan_list, list): return None
    for item in plan_list:
        date, time, title = item.get('date'), item.get('time'), item.get('title')
        if not all([date, time, title]): continue
        if date not in plans_by_date:
            plans_by_date[date] = {}
        plans_by_date[date][time] = title
    
    for date in plans_by_date:
        plans_by_date[date] = dict(sorted(plans_by_date[date].items()))
        
    return plans_by_date

def fill_in_full_schedule(key_events, start_date_str, end_date_str):
    """
    AI가 생성한 핵심 이벤트(key_events)를 기반으로 24시간 전체 일정(full_schedule)을 생성합니다.
    (AI_NLP 브랜치에서 가져온 유용한 기능)
    """
    full_schedule = []
    
    event_lookup = {f"{event['date']} {event['time']}": event['title'] for event in key_events}

    current_date = datetime.strptime(start_date_str, '%Y-%m-%d')
    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
    
    while current_date <= end_date:
        date_str = current_date.strftime('%Y-%m-%d')
        
        for hour in range(24):
            for minute in [0, 30]:
                time_str = f"{hour:02d}:{minute:02d}"
                datetime_key = f"{date_str} {time_str}"
                
                title = "숙소에서 휴식 또는 자유시간" 

                if datetime_key in event_lookup:
                    title = event_lookup[datetime_key]
                elif hour >= 23 or hour < 7:
                    title = "취침"
                
                full_schedule.append({
                    "date": date_str,
                    "time": time_str,
                    "title": title
                })
        
        current_date += timedelta(days=1)
        
    return full_schedule

# --- 메인 API 엔드포인트: 여행 계획 생성 및 저장 ---
@app.route('/api/generate-plan', methods=['POST'])
def generate_plan():
    if db is None:
        return jsonify({"error": "Firebase 서비스에 연결할 수 없습니다."}), 503

    try:
        data = request.json
        trip_id = data.get('tripId')
        if not trip_id:
            return jsonify({"error": "tripId는 필수 항목입니다."}), 400

        # 1. Firestore에서 tripId로 여행 기본 정보 조회
        trip_ref = db.collection('trips').document(trip_id)
        trip_doc = trip_ref.get()
        if not trip_doc.exists:
            return jsonify({"error": "해당 여행 정보를 찾을 수 없습니다."}), 404
        
        trip_data = trip_doc.to_dict()
        print(f"Firestore에서 조회한 여행 정보: {trip_data}")
        
        # 여행 기간 정보 추출 (fill_in_full_schedule 함수에 필요)
        # trip_data에 'startDate', 'endDate' 필드가 있다고 가정합니다.
        # 만약 'tripPeriod' 같은 필드만 있다면 파싱이 필요합니다.
        start_date = trip_data.get('startDate')
        end_date = trip_data.get('endDate')
        if not start_date or not end_date:
            return jsonify({"error": "여행 정보에 시작일 또는 종료일이 없습니다."}), 400

        # 2. 조회된 정보를 바탕으로 Gemma 프롬프트 생성
        full_prompt = create_travel_prompt(
            destination=trip_data.get('destination', '알 수 없음'),
            start_date=start_date,
            end_date=end_date,
            num_people=trip_data.get('numPeople', '알 수 없음'),
            theme=trip_data.get('theme', '자유 여행'),
            additional_request=trip_data.get('additionalRequest', '')
        )
        print(f"생성된 Gemma 프롬프트:\n{full_prompt}")

        # 3. Gemma 모델 호출
        chat_message = [{"role": "user", "content": full_prompt}]
        inputs = tokenizer.apply_chat_template(chat_message, return_tensors="pt").to(model.device)
        outputs = model.generate(inputs, max_new_tokens=4096, do_sample=True, temperature=0.7) # 긴 계획을 위해 토큰 수 증가
        response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
        print(f"Gemma 원본 응답:\n{response_text}")

        # 4. 응답 파싱 및 데이터 변환
        key_events = parse_gemma_response_to_json(response_text)
        if not key_events:
            trip_ref.update({'status': 'error_parsing'})
            return jsonify({"error": "모델로부터 유효한 여행 계획을 생성하지 못했습니다."}), 500
            
        # 5. [결합된 기능] 핵심 이벤트를 기반으로 전체 24시간 시간표 생성
        full_schedule = fill_in_full_schedule(key_events, start_date, end_date)
        
        # 6. (선택적) 날짜별로 그룹화된 데이터 구조도 생성
        transformed_plans = transform_plan_data(key_events)

        # 7. 변환된 최종 계획을 Firestore의 해당 문서에 업데이트
        trip_ref.update({
            'keyEvents': key_events,           # AI가 생성한 원본 핵심 이벤트
            'fullSchedule': full_schedule,     # 30분 단위로 채워진 전체 일정
            'detailedPlan': transformed_plans, # 날짜별로 그룹화된 계획 (기존 구조 유지)
            'status': 'completed'              # 계획 생성 완료 상태로 변경
        })
        print(f"'{trip_id}' 여행 계획이 Firestore에 성공적으로 저장되었습니다.")
        
        return jsonify({
            "success": True,
            "tripId": trip_id,
            "message": "여행 계획이 생성되어 저장되었습니다.",
            "keyEvents": key_events,
            "fullSchedule": full_schedule,
            "plan": transformed_plans
        })

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        if 'trip_ref' in locals() and trip_ref:
            trip_ref.update({'status': 'error_server'})
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}), 500

# 서버 실행
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)