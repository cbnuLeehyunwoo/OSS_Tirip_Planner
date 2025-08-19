# trip_backend/prompt_utils.py

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