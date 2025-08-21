import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
from dotenv import load_dotenv
import json
from flask_cors import CORS
from datetime import datetime, timedelta
import re

# .env 파일에서 환경 변수 로드
load_dotenv()

# --- 모델 로딩 ---
print("모델을 로딩하는 중입니다...")
try:
    # 사용하시는 모델 ID로 설정해주세요.
    model_id = "google/gemma-3-4b-it" 
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16, device_map="auto")
    print("모델 로딩이 완료되었습니다.")
    print(f"로드된 모델 ID: {model_id}")
except Exception as e:
    print(f"모델 로딩 중 오류 발생: {e}")
    exit()

# --- Flask 앱 초기화 --- 
app = Flask(__name__)
CORS(app)


# --- 헬퍼 함수 정의 ---

def parse_duration(duration_str):
    #"90 minutes", "2.5 hours" 같은 문자열을 분(minute) 단위의 timedelta로 변환합니다. 
    try:
        num_str = re.findall(r'[\d.]+', duration_str)[0]
        num = float(num_str)
        if 'hour' in duration_str.lower():
            return timedelta(minutes=int(num * 60))
        elif 'minute' in duration_str.lower():
            return timedelta(minutes=int(num))
    except:
        pass
    return timedelta(minutes=60) # 실패 시 기본값 1시간

def fill_in_full_schedule(key_events, start_date_str, end_date_str):
    # AI가 생성한 핵심 이벤트를 기반으로 24시간 전체 48개 슬롯 일정을 생성
    full_schedule = []
    processed_events = []
    for event in key_events:
        try:
            start_time_str = event.get('start_time') or event.get('time')
            if not start_time_str: continue
            start_datetime = datetime.strptime(f"{event['date']} {start_time_str}", '%Y-%m-%d %H:%M')
            duration = parse_duration(event.get('duration', '60 minutes'))
            end_datetime = start_datetime + duration
            end_marker_datetime = end_datetime - timedelta(minutes=30)
            processed_events.append({'start': start_datetime, 'end': end_datetime, 'end_marker': end_marker_datetime, 'title': event['title']})
        except:
            continue

    current_date = datetime.strptime(start_date_str, '%Y-%m-%d')
    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
    
    while current_date <= end_date:
        date_str = current_date.strftime('%Y-%m-%d')
        for hour in range(24):
            for minute in [0, 30]:
                time_str = f"{hour:02d}:{minute:02d}"
                current_slot_start = datetime.strptime(f"{date_str} {time_str}", '%Y-%m-%d %H:%M')
                title = "숙소에서 휴식 또는 자유시간"
                active_event = None
                for event in processed_events:
                    if current_slot_start >= event['start'] and current_slot_start < event['end']:
                        active_event = event
                        break
                if active_event:
                    base_title = active_event['title']
                    if current_slot_start == active_event['start']:
                        title = f"{base_title} (시작)"
                    elif current_slot_start == active_event['end_marker']:
                        title = f"{base_title} (끝)"
                    else:
                        title = f"{base_title} (진행 중)"
                elif hour >= 23 or hour < 7:
                    title = "취침"
                full_schedule.append({"date": date_str, "time": time_str, "title": title})
        current_date += timedelta(days=1)
    return full_schedule

def create_event_blocks(key_events):
    # AI가 생성한 핵심 이벤트를 '일정 블록' 데이터로 가공
    event_blocks = []
    for event in key_events:
        try:
            start_time_str = event.get('start_time') or event.get('time')
            if not start_time_str: continue
            start_datetime = datetime.strptime(f"{event['date']} {start_time_str}", '%Y-%m-%d %H:%M')
            duration = parse_duration(event.get('duration', '60 minutes'))
            end_datetime = start_datetime + duration
            event_blocks.append({
                "date": event['date'],
                "start_time": start_datetime.strftime('%H:%M'),
                "end_time": end_datetime.strftime('%H:%M'),
                "title": event['title']
            })
        except Exception as e:
            print(f"이벤트 블록 생성 중 오류: {event}, 오류: {e}")
            continue
    return event_blocks

def get_key_events_for_one_day(current_date_str, is_first_day, total_trip_info):
    """ 지정된 단 하루의 핵심 일정을 AI에게 요청하는 함수 """
    first_day_instruction = ""
    if is_first_day:
        first_day_instruction = f"This is the first day. The first event MUST be the travel from '{total_trip_info['start_location']}'. Estimate a realistic duration like '3 hours'."

    prompt = f"""
    You are a creative travel planner AI. Suggest 2 to 4 key activities for a single day: {current_date_str}.

    **Trip Context:**
    - Destination: {total_trip_info['destination']}
    - Theme: {total_trip_info['theme'] if total_trip_info['theme'] else 'Flexible'}

    **Instructions for today ({current_date_str}):**
    {first_day_instruction}Suggest diverse activities with varied durations. Some should be short (e.g., 1 hour), others longer (e.g., 2.5 hours, 150 minutes).
    The response MUST BE ONLY a valid JSON list of objects.
    Each object must have "date", "start_time" (HH:MM), "duration" (e.g., "90 minutes"), and "title".

    **Example Output:**
    [
      {{ "date": "{current_date_str}", "start_time": "10:00", "duration": "2.5 hours", "title": "Visit the Grand Museum" }},
      {{ "date": "{current_date_str}", "start_time": "14:30", "duration": "1 hour", "title": "Coffee break at a famous local cafe" }}
    ]
    """
    message = [{"role": "user", "content": prompt}]
    inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)
    outputs = model.generate(inputs, max_new_tokens=1024)
    model_response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
    print(f"--- Gemma 응답 ({current_date_str}) ---\n{model_response_text}\n--------------------")
    start_index = model_response_text.find('[')
    end_index = model_response_text.rfind(']')
    if start_index != -1 and end_index != -1:
        json_string = model_response_text[start_index:end_index+1]
        try:
            return json.loads(json_string)
        except json.JSONDecodeError:
            print(f"JSON 파싱 오류 발생: {json_string}")
            return []
    return []

# --- 메인 API 엔드포인트 ---
@app.route('/generate-schedule', methods=['POST'])
def generate_schedule_endpoint():
    try:
        data = request.json
        start_location = data.get('start_location', '충청북도 청주')
        destination = data.get('destination')
        start_date_str = data.get('startDate')
        end_date_str = data.get('endDate')
        theme = data.get('theme')
        contingency = data.get('contingency')
        existing_key_events = data.get('existing_key_events') 

        all_key_events = []

        if contingency and existing_key_events:
            # --- 일정 수정 로직 ---
            print(f"*** 일정 수정 요청 수신: {contingency} ***")
            prompt = f"""You are an adaptive travel planner AI. A user's travel plan needs to be modified due to an unexpected situation.

            **Unexpected Situation:**
            - {contingency}

            **Existing Key Activities (in JSON format):**
            - {json.dumps(existing_key_events, ensure_ascii=False, indent=2)}

            **Task:**
            Please modify the "Existing Key Activities" to suit the "Unexpected Situation".
            For example, if it's raining, change outdoor activities to indoor ones. If the user wants to add something, incorporate it into the schedule.
            The output MUST BE a new, revised list of key activities in the exact same JSON format as the input (date, start_time, duration, title).
            Do not add any text before or after the JSON list.
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
                all_key_events = json.loads(json_string)
            else:
                all_key_events = existing_key_events
        
        elif all([destination, start_date_str, end_date_str]):
            # --- 최초 일정 생성 로직 ---
            total_trip_info = { "start_location": start_location, "destination": destination, "start_date": start_date_str, "end_date": end_date_str, "theme": theme }
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
        else:
            return jsonify({"error": "요청에 필요한 데이터가 부족합니다."}), 400

        # 두 종류의 데이터를 모두 생성
        final_full_schedule = fill_in_full_schedule(all_key_events, start_date_str, end_date_str)
        final_schedule_blocks = create_event_blocks(all_key_events)
        
        print(f"--- 최종 생성된 데이터 ---")
        print(f"  - 핵심 일정: {len(all_key_events)}개")
        print(f"  - 전체 슬롯: {len(final_full_schedule)}개")
        print(f"  - 일정 블록: {len(final_schedule_blocks)}개")

        response_data = {
            "key_events": all_key_events,
            "full_schedule": final_full_schedule,
            "schedule_blocks": final_schedule_blocks
        }
        
        print("✅ 데이터 생성 완료. Flutter로 응답을 보냅니다...")
        

        
        # 모든 종류의 데이터를 담아서 Flutter에 반환
        try:
            response = jsonify(response_data)
            response.status_code = 200
            return response
        
        except Exception as e:
            print(f"❌ jsonify 또는 응답 생성 중 치명적인 오류 발생: {e}")
            # 이 경우, 최소한의 오류 응답이라도 보냅니다.
            return jsonify({"error": "서버에서 응답을 생성하는 데 실패했습니다."}), 500

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}), 500

# --- 서버 실행 ---
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)