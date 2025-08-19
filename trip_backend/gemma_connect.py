# trip_backend/gemma_connect.py

import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
import json

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

# --- Gemma 응답 파싱 유틸리티 함수 (기존과 유사) ---
def parse_gemma_response_to_json(response_text):
    """Gemma가 생성한 텍스트에서 JSON 부분만 안전하게 추출하고 파싱합니다."""
    try:
        json_start_index = response_text.find('[')
        if json_start_index != -1:
            json_string = response_text[json_start_index:]
            # 닫히는 ']'를 기준으로 자르면 더 안정적일 수 있음
            json_end_index = json_string.rfind(']')
            if json_end_index != -1:
                json_string = json_string[:json_end_index + 1]

            return json.loads(json_string)
        return None
    except Exception as e:
        print(f"JSON 파싱 중 오류 발생: {e}\n원본 응답: {response_text}")
        return None

def transform_plan_data(plan_list):
    """파싱된 JSON 리스트를 Firestore 저장용 딕셔너리로 변환합니다."""
    plans_by_date = {}
    if not isinstance(plan_list, list): return None
    for item in plan_list:
        date, time, title = item.get('date'), item.get('time'), item.get('title')
        if not all([date, time, title]): continue
        if date not in plans_by_date:
            plans_by_date[date] = {}
        # 시간을 기준으로 정렬되도록 딕셔너리에 추가
        plans_by_date[date][time] = title
    
    # 시간 순으로 정렬된 딕셔너리를 반환하기 위한 추가 처리
    for date in plans_by_date:
        plans_by_date[date] = dict(sorted(plans_by_date[date].items()))
        
    return plans_by_date

# --- 메인 API 엔드포인트: 여행 계획 생성 및 저장 ---
@app.route('/api/generate-plan', methods=['POST'])
def generate_plan():
    if db is None:
        return jsonify({"error": "Firebase 서비스에 연결할 수 없습니다."}), 503

    try:
        data = request.json
        trip_id = data.get('tripId') # 이제 tripId를 받습니다.
        if not trip_id:
            return jsonify({"error": "tripId는 필수 항목입니다."}), 400

        # 1. Firestore에서 tripId로 여행 기본 정보 조회
        trip_ref = db.collection('trips').document(trip_id)
        trip_doc = trip_ref.get()
        if not trip_doc.exists:
            return jsonify({"error": "해당 여행 정보를 찾을 수 없습니다."}), 404
        
        trip_data = trip_doc.to_dict()
        print(f"Firestore에서 조회한 여행 정보: {trip_data}")

        # 2. 조회된 정보를 바탕으로 Gemma 프롬프트 생성 (prompt_utils.py 사용)
        full_prompt = create_travel_prompt(
            destination=trip_data.get('destination', '알 수 없음'),
            trip_period=trip_data.get('tripPeriod', '알 수 없음'),
            num_people=trip_data.get('numPeople', '알 수 없음'),
            theme=trip_data.get('theme', '자유 여행'),
            additional_request=trip_data.get('additionalRequest', '')
        )
        print(f"생성된 Gemma 프롬프트:\n{full_prompt}")

        # 3. Gemma 모델 호출
        chat_message = [{"role": "user", "content": full_prompt}]
        inputs = tokenizer.apply_chat_template(chat_message, return_tensors="pt").to(model.device)
        outputs = model.generate(inputs, max_new_tokens=2048, do_sample=True, temperature=0.7)
        response_text = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)
        print(f"Gemma 원본 응답:\n{response_text}")

        # 4. 응답 파싱 및 데이터 변환
        parsed_plan_list = parse_gemma_response_to_json(response_text)
        if not parsed_plan_list:
            trip_ref.update({'status': 'error_parsing'}) # 상태 업데이트
            return jsonify({"error": "모델로부터 유효한 여행 계획을 생성하지 못했습니다."}), 500
            
        transformed_plans = transform_plan_data(parsed_plan_list)
        if not transformed_plans:
            trip_ref.update({'status': 'error_transforming'}) # 상태 업데이트
            return jsonify({"error": "생성된 계획의 형식이 올바르지 않습니다."}), 500

        # 5. 변환된 최종 계획을 Firestore의 해당 문서에 업데이트
        trip_ref.update({
            'detailedPlan': transformed_plans,
            'status': 'completed'  # 계획 생성 완료 상태로 변경
        })
        print(f"'{trip_id}' 여행 계획이 Firestore에 성공적으로 저장되었습니다.")
        
        return jsonify({
            "success": True,
            "tripId": trip_id,
            "message": "여행 계획이 생성되어 저장되었습니다.",
            "plan": transformed_plans
        })

    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        # 오류 발생 시에도 tripId가 있으면 상태를 업데이트 해주는 것이 좋음
        if 'trip_ref' in locals():
            trip_ref.update({'status': 'error_server'})
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}), 500

# --- 서버 실행 ---
if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=True)