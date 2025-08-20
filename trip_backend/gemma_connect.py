# trip_backend/gemma_connect.py

import torch
import os
import json
import re
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
from dotenv import load_dotenv
from flask_cors import CORS
from datetime import datetime, timedelta

# --- 모듈화된 파일들 import ---
from firebase_config import db
from prompt_utils import create_gemma_prompt_for_day, create_gemma_prompt_for_reschedule

load_dotenv()

# --- 모델 로딩 ---
print("모델을 로딩하는 중입니다...")
try:
    model_id = "google/gemma-2-9b-it" # 사용자가 원한 기존 모델 ID 유지
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

# --- 헬퍼 함수들 ---
def fill_in_full_schedule(key_events, start_date_str, end_date_str):
    """AI가 생성한 핵심 이벤트를 기반으로 전체 일정을 생성합니다."""
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
                full_schedule.append({"date": date_str, "time": time_str, "title": title})
        current_date += timedelta(days=1)
    return full_schedule

def get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info):
    """지정된 단 하루의 핵심 일정을 AI에게 요청하는 함수"""
    model_response_text = ""
    try:
        prompt = create_gemma_prompt_for_day(current_date_str, total_trip_info, is_first_day)
        message = [{"role": "user", "content": prompt}]
        
        print(f"--- 모델 입력을 위해 토크나이저를 적용합니다... ---")
        inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
        print(f"--- 모델 생성을 시작합니다... ---")
        outputs = model.generate(inputs, max_new_tokens=512)
        print(f"--- 모델 생성이 완료되었습니다. 디코딩을 시작합니다... ---")
        model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
        print(f"--- 디코딩이 완료되었습니다. ---")

    except Exception as e:
        print(f"!!!!!!!! 모델 생성 또는 처리 중 심각한 오류 발생 !!!!!!!!")
        print(f"오류 타입: {type(e).__name__}")
        print(f"오류 메시지: {e}")
        return []

    print(f"--- Gemma 응답 ({current_date_str}) ---\n{model_response_text}\n--------------------")

    json_match = re.search(r'\[.*\]', model_response_text, re.DOTALL)
    if json_match:
        json_string = json_match.group(0)
        try:
            return json.loads(json_string)
        except json.JSONDecodeError:
            print(f"JSON 파싱 오류 발생: {json_string}")
            return []
    return []


# --- API 엔드포인트 ---
@app.route('/generate-schedule-from-db', methods=['POST'])
def generate_schedule_from_db():
    """Firestore로부터 tripId를 받아 전체 일정 생성 과정을 처리합니다."""
    trip_ref = None
    try:
        data = request.json
        trip_id = data.get('tripId')
        contingency = data.get('contingency') # 돌발 상황 (일정 수정 시에만 존재)

        if not trip_id:
            return jsonify({"error": "tripId가 누락되었습니다."} ), 400

        trip_ref = db.collection('trips').document(trip_id)
        trip_data = trip_ref.get().to_dict()

        if not trip_data:
            return jsonify({"error": "해당 tripId의 문서를 찾을 수 없습니다."} ), 404

        destination = trip_data.get('destination')
        start_date_str = trip_data.get('startDate')
        end_date_str = trip_data.get('endDate')
        theme = trip_data.get('theme')
        all_key_events = []

        # --- 분기 로직: 돌발 상황이 있으면 일정 수정, 없으면 최초 생성 ---
        if contingency:
            print(f"*** 일정 수정 요청 수신: {contingency} ***")
            existing_schedule = trip_data.get('key_events', [])
            # prompt_utils에 있는 재조정 프롬프트 생성 함수를 사용합니다.
            prompt = create_gemma_prompt_for_reschedule(destination, theme, contingency, existing_schedule)
            
            message = [{"role": "user", "content": prompt}]
            inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
            outputs = model.generate(inputs, max_new_tokens=2048)
            model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
            print(f"--- Gemma 수정 제안 ---\n{model_response_text}\n--------------------")
            json_match = re.search(r'\[.*\]', model_response_text, re.DOTALL)
            if json_match:
                all_key_events = json.loads(json_match.group(0))
        else:
            # --- 최초 일정 생성 로직 ---
            total_trip_info = {
                "start_location": "충청북도 청주",
                "destination": destination,
                "start_date": start_date_str,
                "end_date": end_date_str,
                "theme": theme
            }
            current_date = datetime.strptime(start_date_str, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
            is_first_day = True
            while current_date <= end_date:
                current_date_str = current_date.strftime('%Y-%m-%d')
                print(f"*** {current_date_str}의 일정을 생성합니다... ***")
                daily_events = get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info)
                all_key_events.extend(daily_events)
                is_first_day = False
                current_date += timedelta(days=1)
        
        # --- 공통 로직: 최종 일정 생성 및 DB 업데이트 ---
        final_full_schedule = fill_in_full_schedule(all_key_events, start_date_str, end_date_str)
        
        trip_ref.update({
            'key_events': all_key_events,
            'full_schedule': final_full_schedule,
            'status': 'completed'
        })
        
        print(f"--- {trip_id}의 전체 일정 생성/수정 및 DB 업데이트 완료 ---")
        return jsonify({"success": True}), 200

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        if trip_ref:
            trip_ref.update({'status': 'error'})
        return jsonify({"error": "내부 서버 오류가 발생했습니다."} ), 500

# --- 서버 실행 ---
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)