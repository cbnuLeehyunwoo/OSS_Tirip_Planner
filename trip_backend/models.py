from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship, sessionmaker
from sqlalchemy.ext.declarative import declarative_base
import enum

# 1. DB 연결 설정
DATABASE_URL = "mysql+mysqlconnector://<db_user>:<db_password>@<db_host>:<db_port>/<db_name>"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Enum 타입 정의 (Python 3.4+의 enum 활용)
class ItemTypeEnum(enum.Enum):
    tourism = "관광"
    meal = "식사"
    accommodation = "숙소"
    transport = "이동"

# 2. 테이블을 정의하는 클래스들 (스키마)
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, index=True)
    nickname = Column(String(50))
    # 관계 설정: User는 여러 Trip을 가질 수 있다.
    trips = relationship("Trip", back_populates="user")

class Trip(Base):
    __tablename__ = "trips"
    id = Column(Integer, primary_key=True, index=True)
    destination_city = Column(String(50))
    start_date = Column(DateTime)
    end_date = Column(DateTime)
    user_id = Column(Integer, ForeignKey("users.id"))
    # 관계 설정
    user = relationship("User", back_populates="trips")
    items = relationship("ItineraryItem", back_populates="trip")

class ItineraryItem(Base):
    __tablename__ = "itinerary_items"
    id = Column(Integer, primary_key=True, index=True)
    day_of_trip = Column(Integer)
    start_time = Column(DateTime)
    end_time = Column(DateTime)
    item_type = Column(Enum(ItemTypeEnum))
    priority = Column(Integer, default=3)
    trip_id = Column(Integer, ForeignKey("trips.id"))
    # 관계 설정
    trip = relationship("Trip", back_populates="items")
    # 여기에 location_id 외래키도 추가되어야 함

# 3. 실제 DB에 테이블을 생성하는 함수
def create_database_tables():
    Base.metadata.create_all(bind=engine)

# 이 파일을 직접 실행하면 테이블이 생성되도록 설정
if __name__ == "__main__":
    create_database_tables()
    print("Database tables created successfully.")