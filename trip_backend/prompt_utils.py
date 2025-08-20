# trip_backend/prompt_utils.py
import json

def create_travel_prompt(destination, trip_period, num_people, theme, additional_request=""):
    """
    Firestore에서 가져온 여행 기본 정보를 바탕으로 Gemma에게 보낼 프롬프트를 생성합니다.
    """
    
    # 프롬프트의 기본 구조와 Gemma에게 내리는 지시사항
    prompt = f"""
    아래 조건에 맞춰 여행 계획을 생성해줘.
    너의 답변은 반드시 유효한 JSON 배열 형식이어야 해.
    각 배열의 요소는 "date" (YYYY-MM-DD), "time" (HH:MM 형식), "title" (문자열) 이라는 3개의 키를 가진 객체여야 한다.
    JSON 데이터 외에 어떠한 설명, 인사말, 주석, 마크다운(예: ```json)도 절대로 포함해서는 안 돼.

    [여행 조건]
    - 여행지: {destination}
    - 여행 기간: {trip_period}
    - 여행 인원: {num_people}
    - 여행 테마: {theme}
    - 추가 요청사항: {additional_request if additional_request else "없음"}

    이제 JSON 형식으로 여행 계획을 생성해줘.
    """
    
    # 불필요한 공백을 제거하여 모델에 더 깔끔한 입력을 제공
    return "\n".join([line.strip() for line in prompt.strip().split('\n')])


def create_gemma_prompt_for_day(current_date_str, total_trip_info, is_first_day):
    """Gemma-2 모델에 맞게 수정된, 하루치 일정을 요청하는 프롬프트를 생성합니다."""

    first_day_instruction = ""
    if is_first_day:
        first_day_instruction = f"- Note: This is the first day. The first event must be traveling from '{total_trip_info['start_location']}' to the destination."

    # Gemma-2 모델을 위해 더 간단하고 명확하게 수정된 프롬프트
    prompt = f"""
    **Task: Create a travel schedule for one day.**

    **Input:**
    - Day: {current_date_str}
    - Destination: {total_trip_info['destination']}
    - Theme: {total_trip_info['theme'] if total_trip_info['theme'] else 'Any'}
    {first_day_instruction}

    **Instructions:**
    1. Suggest 2 to 4 diverse and interesting activities for the given day.
    2. Your entire response must be a single, valid JSON list of objects.
    3. Each object must contain three keys: "date" (string), "time" (string in HH:MM format), and "title" (string).
    4. The value for the "date" key for all objects must be "{current_date_str}".

    **JSON Response:**
    """
    return prompt

def create_gemma_prompt_for_reschedule(destination, theme, contingency, existing_schedule):
    """돌발 상황에 맞춰 기존 일정을 수정하도록 요청하는 프롬프트를 생성합니다."""
    
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
    return prompt