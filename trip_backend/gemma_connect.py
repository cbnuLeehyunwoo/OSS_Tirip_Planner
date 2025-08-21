# trip_backend/gemma_connect.py

import torch
import os
import json
import re
import random
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
from dotenv import load_dotenv
from flask_cors import CORS
from datetime import datetime, timedelta

from firebase_config import db
from prompt_utils import create_gemma_prompt, create_gemma_prompt_for_reschedule

load_dotenv()

print("모델을 로딩하는 중입니다...")
try:
    # 더 크고 성능이 좋은 4B 모델로 변경
    model_id = "google/gemma-3-4b-it"
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(
        model_id, torch_dtype=torch.bfloat16, device_map="auto"
    )
    print(f"모델 로딩이 완료되었습니다: {model_id}")
except Exception as e:
    print(f"모델 로딩 중 오류 발생: {e}")
    exit()

app = Flask(__name__)
CORS(app)

def fill_in_full_schedule(key_events, start_date_str, end_date_str):
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

def generate_daily_schedule_from_ai(current_date_str, is_first_day, total_trip_info, tourist_spots, restaurants):
    model_response_text = ""
    try:
        prompt = create_gemma_prompt(current_date_str, total_trip_info, is_first_day, tourist_spots, restaurants)
        message = [{"role": "user", "content": prompt}]
        inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
        outputs = model.generate(inputs, max_new_tokens=1024) 
        model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
    except Exception as e:
        print(f"!!!!!!!! 모델 생성 또는 처리 중 심각한 오류 발생 !!!!!!!!\n{e}")
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

@app.route('/generate-schedule-from-db', methods=['POST'])
def generate_schedule_from_db():
    trip_ref = None
    try:
        data = request.json
        trip_id = data.get('tripId')
        contingency = data.get('contingency')

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
        
        tourist_spots = trip_data.get('tourist_spots_data', [])
        restaurants = trip_data.get('restaurants_data', [])
        accommodations = trip_data.get('accommodations_data', [])
        places_data = tourist_spots + restaurants + accommodations

        all_key_events = []

        if contingency:
            print(f"*** 일정 수정 요청 수신: {contingency} ***")
            existing_schedule = trip_data.get('key_events', [])
            prompt = create_gemma_prompt_for_reschedule(destination, theme, contingency, existing_schedule, places_data)
            message = [{"role": "user", "content": prompt}]
            inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
            outputs = model.generate(inputs, max_new_tokens=2048)
            model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
            print(f"--- Gemma 수정 제안 ---\n{model_response_text}\n--------------------")
            json_match = re.search(r'\[.*\]', model_response_text, re.DOTALL)
            if json_match:
                all_key_events = json.loads(json_match.group(0))
        else:
            total_trip_info = {
                "start_location": "충청북도 청주",
                "destination": destination,
                "start_date": start_date_str,
                "end_date": end_date_str,
                "theme": theme
            }
            used_tourist_spots = []
            used_restaurants = []
            current_date = datetime.strptime(start_date_str, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
            is_first_day = True

            while current_date <= end_date:
                current_date_str = current_date.strftime('%Y-%m-%d')
                
                # 샘플링 로직 제거: 전체 목록을 사용
                available_spots = [p for p in tourist_spots if p['name'] not in used_tourist_spots]
                available_restaurants = [p for p in restaurants if p['name'] not in used_restaurants]

                print(f"*** {current_date_str}의 일정을 생성합니다. 사용 가능한 관광지: {len(available_spots)}, 식당: {len(available_restaurants)} ***")
                
                daily_events = generate_daily_schedule_from_ai(current_date_str, is_first_day, total_trip_info, available_spots, available_restaurants)
                
                for event in daily_events:
                    all_key_events.append(event)
                    title = event.get('title')
                    # Check if the title matches the 'name' key in any available spot/restaurant
                    is_spot = any(p['name'] == title for p in available_spots)
                    if is_spot:
                        used_tourist_spots.append(title)
                    else:
                        used_restaurants.append(title)

                is_first_day = False
                current_date += timedelta(days=1)
        
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

if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)
