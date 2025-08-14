import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
from dotenv import load_dotenv

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

# --- Flask 앱 초기화 --- => 왜함?
app = Flask(__name__)

# --- API 엔드포인트 정의 ---
@app.route('/api/plan-trip', methods=['POST'])
def plan_trip():
    try:
        # data = request.json
        data = {'prompt':'1박2일로 부산 여행계획 짜줘'} # 임시임
        # 입력 값 유효성 검사
        if not data or 'prompt' not in data:
            return jsonify({"error": "유효하지 않은 입력입니다. 'prompt' 키가 필요합니다."}), 400

        prompt = data['prompt']
        print(f"수신된 프롬프트: {prompt}")

        message = [
            {"role" : "user",
             "content" : prompt}
        ]
        inputs = tokenizer.apply_chat_template(message, return_tensors="pt").to(model.device)

        # 모델 응답 생성
        outputs = model.generate(inputs, max_new_tokens=1000, do_sample=True, temperature=0.7)

        # 2. 입력 프롬프트를 제외한 순수 응답만 추출
        input_length = inputs.shape[1]
        response_text = tokenizer.decode(outputs[0][input_length:], skip_special_tokens=True)
        
        print(f"생성된 응답: {response_text}")

        return jsonify({"response": response_text})

    # 3. 예외 처리 추가
    except Exception as e:
        print(f"API 처리 중 오류 발생: {e}")
        return jsonify({"error": "내부 서버 오류가 발생했습니다."}), 500

# --- 서버 실행 ---
if __name__ == '__main__':
    port_str = os.getenv("PORT", "5000")
    port = int(port_str)
    print(f"Flask 서버를 포트 {port}에서 시작합니다.")
    # 실제 운영 시에는 debug=False 로 설정하거나 Gunicorn 같은 WSGI 서버를 사용해야 합니다.
    app.run(host='0.0.0.0', port=port, debug=True) # 개발 중에는 True로 유지 