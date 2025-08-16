from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import urllib.parse
import re
import time

def parse_operating_info(soup):
    """
    HTML에서 영업 시간 및 vV_z_ 영역의 텍스트를 반환합니다.
    """
    results = {}
    
    # ✅ 1) 기본 영업 시간 섹션 파싱
    operating_time_section = soup.select_one("div.place_section_operating_time")
    if operating_time_section:
        items = operating_time_section.select("li.sb8iW")
        for item in items:
            day_span = item.select_one("span.i8cJw")
            time_div = item.select_one("div.H3ua4")
            
            if day_span and time_div:
                day = day_span.get_text(strip=True)
                time_info = time_div.get_text(strip=True)
                results[day] = time_info
        
        # 영업/휴무 관련 추가 정보 추출
        extra_info_text = operating_time_section.get_text(separator='\n', strip=True)
        lines = extra_info_text.split('\n')
        operating_info_lines = [
            line.strip() for line in lines
            if re.search(r'영업|휴무|쉬는|마지막|라스트|BreakTime', line, re.I)
        ]
        
        if operating_info_lines:
            results['추가 정보'] = " / ".join(operating_info_lines)

    # ✅ 2) vV_z_ 영역 텍스트 추출
    vvz_sections = soup.select("div.vV_z_")
    vvz_texts = []
    for section in vvz_sections:
        text = section.get_text(separator="\n", strip=True)
        if text:
            vvz_texts.append(text)
    if vvz_texts:
        results["세부 안내"] = "\n---\n".join(vvz_texts)

    # ✅ 3) 결과 없으면 fallback (전체 텍스트에서 요일/영업 패턴만 추출)
    if not results:
        text = soup.get_text(separator='\n', strip=True)
        lines = text.split('\n')
        operating_info_lines = [
            line.strip() for line in lines
            if re.search(r'(월|화|수|목|금|토|일|영업|휴무|브레이크타임|정기휴무)', line)
        ]
        if operating_info_lines:
            return "\n".join(operating_info_lines)

    # ✅ 4) 최종 출력 포맷 가공
    extra_info = results.pop('추가 정보', None)
    lines = []
    for day, time_info in results.items():
        if day == "세부 안내":
            lines.append("\n세부 안내:")
            lines.append(time_info)
        else:
            lines.append(f"{day}")
            lines.append(f"  {time_info}")
    if extra_info:
        lines.append(f"\n추가 정보: {extra_info}")

    return "\n".join(lines)

def click_expand_button(driver):
    """
    정보 펼치기 버튼을 클릭합니다.
    """
    try:
        more_info_button = WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, 'a.gKP9i[aria-expanded="false"]'))
        )
        more_info_button.click()
        WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "li.sb8iW"))
        )
        return True
    except TimeoutException:
        return False

def get_place_info_from_naver_search_by_text(place_name):
    """
    Selenium으로 페이지를 로드하고 BeautifulSoup으로 텍스트를 필터링하여 정보를 추출합니다.
    """
    driver = None
    try:
        service = Service(ChromeDriverManager().install())
        options = webdriver.ChromeOptions()
        options.add_argument("headless")
        options.add_argument("window-size=1920x1080")
        options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36")
        driver = webdriver.Chrome(service=service, options=options)

        query = urllib.parse.quote(f"{place_name} 영업시간")
        url = f"https://search.naver.com/search.naver?query={query}"
        driver.get(url)

        # '더보기' 버튼이 있다면 클릭
        click_expand_button(driver)

        html = driver.page_source
        soup = BeautifulSoup(html, "html.parser")
        
        # iframe이 있다면 진입
        try:
            iframe = WebDriverWait(driver, 3).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "iframe#entryIframe"))
            )
            driver.switch_to.frame(iframe)
            click_expand_button(driver)  # iframe 내에 더보기 버튼이 있을 수 있으므로 재시도
            html = driver.page_source
            soup = BeautifulSoup(html, "html.parser")
        except:
            pass

        info = parse_operating_info(soup)
        
        if info:
            if isinstance(info, dict):
                return "\n".join(f"{k}: {v}" for k, v in info.items())
            return info
        else:
            return "운영 시간 정보를 찾을 수 없습니다."

    except Exception as e:
        return f"오류 발생: {e}"
    finally:
        if driver:
            driver.quit()

if __name__ == "__main__":
    place = input("🔍 휴무 정보를 확인할 장소 이름을 입력하세요: ")
    info = get_place_info_from_naver_search_by_text(place)
    print(f"\n📌 [{place}] 운영 정보:\n{info}")