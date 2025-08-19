# trip_backend/gemma_connect.py

import torch
import os
import json
import re # JSON 파싱을 위해 re 모듈 추가
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
from dotenv import load_dotenv
from flask_cors import CORS
from datetime import datetime, timedelta

# --- 모듈화된 파일들 import ---
from firebase_config import db  # Firebase 연결 객체
# create_travel_prompt 대신 새로 만든 함수를 가져옵니다.
from prompt_utils import create_gemma_prompt_for_day

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

def get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info):
    """지정된 단 하루의 핵심 일정을 AI에게 요청하는 함수"""
    
    # 1. prompt_utils에서 프롬프트 생성
    prompt = create_gemma_prompt_for_day(current_date_str, total_trip_info, is_first_day)

    # 2. 모델 호출
    message = [{"role": "user", "content": prompt}]
    inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
    outputs = model.generate(inputs, max_new_tokens=512)
    model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)

    print(f"--- Gemma 응답 ({current_date_str}) ---\n{model_response_text}\n--------------------")

    # 3. 모델 응답에서 JSON만 파싱 (더 안정적인 방식으로 변경)
    json_match = re.search(r'\[.*]', model_response_text, re.DOTALL)
    if json_match:
        json_string = json_match.group(0)
        try:
            return json.loads(json_string)
        except json.JSONDecodeError:
            print(f"JSON 파싱 오류 발생: {json_string}")
            return []
            
    return [] # JSON을 찾지 못한 경우


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

        is_first_day = True
        while current_date <= end_date:
            current_date_str = current_date.strftime('%Y-%m-%d')
            print(f"*** {current_date_str}의 일정을 생성합니다... ***")
            
            daily_events = get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info)
            all_key_events.extend(daily_events)
            
            is_first_day = False
            current_date += timedelta(days=1)
        
        final_full_schedule = fill_in_full_schedule(all_key_events, start_date_str, end_date_str)
        
        print(f"--- 최종 생성된 전체 일정 ({len(final_full_schedule)}개) ---")
        return jsonify({
            "key_events" : all_key_events,
            "full_schedule": final_full_schedule
        })

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        if 'trip_ref' in locals():
            trip_ref.update({'status': 'error_server'})
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}, 500)

# 서버 실행
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)
