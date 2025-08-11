import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

print("Loading model...")
model_id = "google/gemma-2b-it"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16, device_map="auto")
print("Model loaded successfully.")
print(f"Model ID: {model_id} loded.")

# Initialize Flask app
app = Flask(__name__)

@app.route('.api/plan-trip', methods=['POST'])
def plan_trip():
    data = request.json
    if not data or 'prompt' not in data:
        return jsonify({"error": "Invalid input"}), 400

    prompt = data['prompt']
    print(f"Received prompt: {prompt}")

    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    outputs = model.generate(**inputs, max_new_tokens=1000, do_sample=True, temperature=0.7)

    response_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
    print(f"Generated response: {response_text}")

    return jsonify({"response": response_text})

if __name__ == '__main__':
    port = int(os.getenv("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
    print(f"Flask app running on port {port}")