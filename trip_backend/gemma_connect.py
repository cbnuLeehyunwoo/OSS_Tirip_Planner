# trip_backend/gemma_connect.py

import torch
import os
import json
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
from dotenv import load_dotenv
from flask_cors import CORS
from datetime import datetime, timedelta

# --- 모듈화된 파일들 import ---
from firebase_config import db  # Firebase 연결 객체
from prompt_utils import create_travel_prompt # 프롬프트 생성 함수

from dotenv import load_dotenv
load_dotenv()

# --- 모델 로딩 (기존과 동일) ---
# ... (모델 로딩 코드는 변경 없이 그대로 둡니다) ...
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

def fill_in_full_schedule(key_events, start_date_str, end_date_str):
    """
    AI가 생성한 핵심 이벤트(sparse schedule)를 기반으로 24시간 전체 일정(full schedule)을 생성합니다.
    """
    full_schedule = []
    
    # AI가 제안한 일정을 { 'YYYY-MM-DD HH:MM': '활동 제목' } 형태의 딕셔너리로 변환하여 검색 속도를 높임
    event_lookup = {f"{event['date']} {event['time']}": event['title'] for event in key_events}

    current_date = datetime.strptime(start_date_str, '%Y-%m-%d')
    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
    
    # 여행 기간 동안 하루씩 반복
    while current_date <= end_date:
        date_str = current_date.strftime('%Y-%m-%d')
        
        # 하루 48개의 30분 슬롯에 대해 반복
        for hour in range(24):
            for minute in [0, 30]:
                time_str = f"{hour:02d}:{minute:02d}"
                datetime_key = f"{date_str} {time_str}"
                
                title = "숙소에서 휴식 또는 자유시간" # 기본값

                # 1. AI가 제안한 핵심 일정이 있는지 확인
                if datetime_key in event_lookup:
                    title = event_lookup[datetime_key]
                
                # 2. 프로그래밍 로직으로 특정 시간대 채우기 (취침 시간 등)
                elif hour >= 23 or hour < 7:
                    title = "취침"
                
                full_schedule.append({
                    "date": date_str,
                    "time": time_str,
                    "title": title
                })
        
        current_date += timedelta(days=1)
        
    return full_schedule

def get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info):
    """지정된 단 하루의 핵심 일정을 AI에게 요청하는 함수"""
    
    # 첫날인지 아닌지에 따라 프롬프트의 일부를 동적으로 변경
    first_day_instruction = ""
    if is_first_day:
        first_day_instruction = f"This is the first day of the trip. The first event MUST be the travel from '{total_trip_info['start_location']}' to the destination. "

    prompt = f"""
    You are a travel planner AI. Your task is to suggest 2 to 4 key activities for a single day: {current_date_str}.

    **Trip Context:**
    - Destination: {total_trip_info['destination']}
    - Full Trip Period: {total_trip_info['start_date']} to {total_trip_info['end_date']}
    - Preferred Theme: {total_trip_info['theme'] if total_trip_info['theme'] else 'Flexible'}

    **Instructions for today ({current_date_str}):**
    {first_day_instruction}Suggest 2 to 4 diverse and interesting main activities for this single day.
    The response MUST BE ONLY a valid JSON list of objects for this date.
    Each object must have "date": "{current_date_str}", "time": "HH:MM", and "title".

    **Example Output for a single day:**
    [
      {{"date": "{current_date_str}", "time": "10:30", "title": "Visit a famous local landmark"}},
      {{"date": "{current_date_str}", "time": "13:00", "title": "Lunch at a highly-rated restaurant"}},
      {{"date": "{current_date_str}", "time": "19:00", "title": "Enjoy the city's night view"}}
    ]
    """

    # 모델 호출
    message = [{"role": "user", "content": prompt}]
    inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
    outputs = model.generate(inputs, max_new_tokens=512) # 하루치만 만드므로 토큰을 줄여도 됨
    model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)

    print(f"--- Gemma 응답 ({current_date_str}) ---\n{model_response_text}\n--------------------")

    # JSON 파싱
    start_index = model_response_text.find('[')
    end_index = model_response_text.rfind(']')
    if start_index != -1 and end_index != -1:
        json_string = model_response_text[start_index:end_index+1]
        return json.loads(json_string)
    return [] # 실패 시 빈 리스트 반환


@app.route('/generate-schedule', methods=['POST'])
def generate_schedule_endpoint():
    try:
        data = request.json
        destination = data.get('destination')
        start_date_str = data.get('startDate')
        end_date_str = data.get('endDate')
        theme = data.get('theme')

        if not all([destination, start_date_str, end_date_str]):
            return jsonify({"error": "필수 필드가 누락되었습니다."}), 400

        all_key_events = []
        current_date = datetime.strptime(start_date_str, '%Y-%m-%d')
        end_date = datetime.strptime(end_date_str, '%Y-%m-%d')

        total_trip_info = {
            "start_location": "충청북도 청주",
            "destination": destination,
            "start_date": start_date_str,
            "end_date": end_date_str,
            "theme": theme
        }

        # 여행 기간 동안 하루씩 반복하며 AI에게 개별적으로 질문
        is_first_day = True
        while current_date <= end_date:
            current_date_str = current_date.strftime('%Y-%m-%d')
            print(f"*** {current_date_str}의 일정을 생성합니다... ***")
            
            daily_events = get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info)
            all_key_events.extend(daily_events) # 결과 리스트에 추가
            
            is_first_day = False
            current_date += timedelta(days=1)
        
        # 모든 날짜의 핵심 일정이 합쳐지면, 전체 일정을 채움
        final_full_schedule = fill_in_full_schedule(all_key_events, start_date_str, end_date_str)
        
        print(f"--- 최종 생성된 전체 일정 ({len(final_full_schedule)}개) ---")
        return jsonify({
            "key_events" : all_key_events,
            "full_schedule": final_full_schedule
        })

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        # 오류 발생 시에도 tripId가 있으면 상태를 업데이트 해주는 것이 좋음
        if 'trip_ref' in locals():
            trip_ref.update({'status': 'error_server'})
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}), 500

# 서버 실행
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)