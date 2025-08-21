# trip_backend/prompt_utils.py
import json

def create_gemma_prompt(current_date_str, total_trip_info, is_first_day, tourist_spots, restaurants):
    """하루치 일정을 생성하기 위한 프롬프트를 생성합니다. (지시사항 강화 버전)"""

    first_day_instruction = ""
    if is_first_day:
        first_day_instruction = f"- Note: This is the first day. The first event must be traveling from '{total_trip_info['start_location']}' to the destination."

    # Debugging: Check type of 'place'
    if tourist_spots and not isinstance(tourist_spots[0], dict):
        print(f"DEBUG: tourist_spots contains non-dict elements. Example: {tourist_spots[0]} (type: {type(tourist_spots[0])})")
    if restaurants and not isinstance(restaurants[0], dict):
        print(f"DEBUG: restaurants contains non-dict elements. Example: {restaurants[0]} (type: {type(restaurants[0])})")

    tourist_spots_str = "\n".join([
        f"- Name: {place['name']}, Lat: {place.get('mapy', 'N/A')}, Lon: {place.get('mapx', 'N/A')}, Hours: {place.get('hours', 'N/A')}, Closed: {place.get('restDate', 'N/A')}"
        for place in tourist_spots
    ])
    restaurants_str = "\n".join([
        f"- Name: {place['name']}, Lat: {place.get('mapy', 'N/A')}, Lon: {place.get('mapx', 'N/A')}, Hours: {place.get('hours', 'N/A')}, Closed: {place.get('restDate', 'N/A')}"
        for place in restaurants
    ])

    prompt = f"""
    **Task:** Create a detailed travel schedule for {current_date_str}.

    **Input Data:**
    - Day: {current_date_str}
    - Destination: {total_trip_info['destination']}
    - Theme: {total_trip_info.get('theme', 'Any')}
    {first_day_instruction}

    **Available Tourist Spots:**
    {tourist_spots_str}

    **Available Restaurants:**
    {restaurants_str}

    **Instructions:**
    Your entire response MUST BE ONLY the JSON code block. Do NOT include any other text, explanations, or conversational elements.
    - **Route Optimization:** STRICTLY prioritize minimizing travel distance and time between consecutive locations. For each activity, select the next activity that is geographically closest to the current location, using their Latitude (Lat) and Longitude (Lon) values. Ensure a logical, efficient flow that avoids any backtracking or unnecessary travel.
    The JSON schedule MUST follow these rules:
    1.  **Lunch:** Include exactly one restaurant from the "Restaurants" list. The time must be between 12:00 and 13:00.
    2.  **Dinner:** Include exactly one restaurant from the "Restaurants" list. The time must be between 18:00 and 19:00.
    3.  **Tourist Activities:** Include between 2 and 4 activities from the "Tourist Spots" list, scheduled at other times of the day.
    4.  Each activity must be an object with "date", "time", and "title" keys.
    5.  The "title" should be the exact name of the place from the provided lists, without any additional text like "(Lunch)" or "(Dinner)".
    6.  The schedule must be ordered by time.

    **JSON Response:**
    ```json
    [
      {{"date": "{current_date_str}", "time": "10:00", "title": "[Tourist Spot Name 1]"}},
      {{"date": "{current_date_str}", "time": "12:30", "title": "[Lunch Restaurant Name]"}},
      {{"date": "{current_date_str}", "time": "14:00", "title": "[Tourist Spot Name 2]"}},
      {{"date": "{current_date_str}", "time": "18:30", "title": "[Dinner Restaurant Name]"}}
    ]
    ```
    """
    return prompt

def create_gemma_prompt_for_reschedule(destination, theme, contingency, existing_schedule, places_data):
    """돌발 상황에 맞춰 기존 일정을 수정하도록 요청하는 프롬프트를 생성합니다."""
    
    places_list_str = "\n".join([f"- {place}" for place in places_data])

    prompt = f"""
    You are an adaptive travel planner AI. A user's original travel plan needs to be modified due to an unexpected situation.

    **Original Trip Details:**
    - Destination: {destination}
    - Theme: {theme if theme else 'Flexible'}

    **Available Places for Substitution (Name, Type, Hours, Closed Days):**
    {places_list_str}

    **Unexpected Situation:**
    - {contingency}

    **Existing Key Activities:**
    - {json.dumps(existing_schedule, ensure_ascii=False, indent=2)}

    **Task:**
    1. Modify the "Existing Key Activities" to suit the "Unexpected Situation".
    2. If you need to replace an activity, you MUST choose a substitute from the "Available Places" list.
    3. The output MUST BE a new, revised list of key activities in the exact same JSON format as the input.
    """
    return prompt
