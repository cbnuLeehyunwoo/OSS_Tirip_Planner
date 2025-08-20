import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
from dotenv import load_dotenv
import json
from flask_cors import CORS
from datetime import datetime, timedelta

# .env 파일에서 환경 변수 로드
load_dotenv()

# --- 모델 로딩 ---
print("모델을 로딩하는 중입니다...")
try:
    model_id = "google/gemma-3-1b-it"
    # 토크나이저와 모델 로드 (성능 최적화 옵션 포함)
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16, device_map="auto")
    print("모델 로딩이 완료되었습니다.")
    print(f"로드된 모델 ID: {model_id}")
except Exception as e:
    print(f"모델 로딩 중 오류 발생: {e}")
    exit() # 모델 로딩 실패 시 서버 실행 중지

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
        contingency = data.get('contingency') # 예: "비가 옴"
        existing_schedule = data.get('existing_schedule') # 기존 전체 일정

        if not all([destination, start_date_str, end_date_str]):
            return jsonify({"error": "필수 필드가 누락되었습니다."}), 400

        all_key_events = []
        
        if contingency and existing_schedule:
            # --- 일정 수정 로직 ---
            print(f"*** 일정 수정 요청 수신: {contingency} ***")
            
            # AI에게 기존 일정과 문제 상황을 알려주고 수정을 요청하는 새 프롬프트
            prompt = f"""
            You are an adaptive travel planner AI. A user's original travel plan needs to be modified due to an unexpected situation.

            **Original Trip Details:**
            - Destination: {destination}
            - Theme: {theme if theme else 'Flexible'}

            **Unexpected Situation:**
            - {contingency} (e.g., "It's raining", "Overslept", "Feeling unwell")

            **Existing Key Activities:**
            - {json.dumps(existing_schedule, ensure_ascii=False, indent=2)}

            **Task:**
            Modify the "Existing Key Activities" to suit the "Unexpected Situation".
            For example, if it's raining, change outdoor activities to indoor ones (like museums, indoor cafes, shopping malls). If the user overslept, adjust the morning schedule.
            The output MUST BE a new, revised list of key activities in the exact same JSON format as the input.
            """
            
            message = [{"role": "user", "content": prompt}]
            inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
            outputs = model.generate(inputs, max_new_tokens=2048)
            model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
            
            print(f"--- Gemma 수정 제안 ---\n{model_response_text}\n--------------------")

            start_index = model_response_text.find('[')
            end_index = model_response_text.rfind(']')
            if start_index != -1 and end_index != -1:
                json_string = model_response_text[start_index:end_index+1]
                all_key_events = json.loads(json_string) # 수정된 핵심 일정
            else:
                 all_key_events = [] # 실패 시 빈 리스트
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
        
        # 최종적으로, 핵심 일정을 기반으로 전체 상세 일정을 채움
        final_full_schedule = fill_in_full_schedule(all_key_events, start_date_str, end_date_str)
        
        return jsonify({
            "key_events": all_key_events,
            "full_schedule": final_full_schedule
        })

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}), 500

# 서버 실행
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)