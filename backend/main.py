from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from ai_service import detect_safety
import mysql.connector
import json
from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta


app = FastAPI(
    title="AI Industrial Safety Monitoring API",
    description="Backend API for industrial safety monitoring",
    version="1.0.0"
)


# ============================================================
# DATABASE CONNECTION
# ============================================================

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        port=3306,
        user="root",
        password="password@123",
        database="industrial_safety"
    )


# ============================================================
# AUTHENTICATION CONFIGURATION
# ============================================================

SECRET_KEY = "industrial-safety-secret-key-2026"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

security = HTTPBearer()


# ============================================================
# REQUEST MODELS
# ============================================================

class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    role: str = "USER"


class LoginRequest(BaseModel):
    email: str
    password: str


# ============================================================
# PASSWORD FUNCTIONS
# ============================================================

def hash_password(password: str):
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str):
    return pwd_context.verify(password, password_hash)


# ============================================================
# JWT FUNCTIONS
# ============================================================

def create_access_token(user_id: int, email: str, role: str):
    expire = datetime.utcnow() + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "user_id": user_id,
        "email": email,
        "role": role,
        "exp": expire
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials
):
    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        user_id = payload.get("user_id")
        email = payload.get("email")
        role = payload.get("role")

        if user_id is None or email is None or role is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid authentication token"
            )

        return {
            "user_id": user_id,
            "email": email,
            "role": role
        }

    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token"
        )


# ============================================================
# HOME
# ============================================================

@app.get("/")
def home():
    return {
        "message": "AI Industrial Safety Monitoring API is running",
        "status": "success"
    }


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
def health():
    return {
        "status": "healthy"
    }


# ============================================================
# DATABASE TEST
# ============================================================

@app.get("/db-test")
def db_test():

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute("SELECT DATABASE()")
        database = cursor.fetchone()[0]

        cursor.close()
        connection.close()

        return {
            "status": "success",
            "database": database
        }

    except Exception as e:

        return {
            "status": "error",
            "message": str(e)
        }


# ============================================================
# REGISTER
# ============================================================

@app.post("/register")
def register(user: RegisterRequest):

    connection = None
    cursor = None

    try:

        # Validate role
        role = user.role.upper()

        if role not in ["USER", "ADMIN"]:
            raise HTTPException(
                status_code=400,
                detail="Role must be USER or ADMIN"
            )

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        # Check whether email already exists
        cursor.execute(
            "SELECT id FROM users WHERE email = %s",
            (user.email,)
        )

        existing_user = cursor.fetchone()

        if existing_user:
            raise HTTPException(
                status_code=400,
                detail="Email already registered"
            )

        # Hash password
        password_hash = hash_password(user.password)

        # Insert user
        cursor.execute(
            """
            INSERT INTO users
            (name, email, password_hash, role)
            VALUES (%s, %s, %s, %s)
            """,
            (
                user.name,
                user.email,
                password_hash,
                role
            )
        )

        connection.commit()

        return {
            "status": "success",
            "message": "User registered successfully",
            "role": role
        }

    except HTTPException:
        raise

    except Exception as e:

        return {
            "status": "error",
            "message": str(e)
        }

    finally:

        if cursor:
            cursor.close()

        if connection:
            connection.close()


# ============================================================
# LOGIN
# ============================================================

@app.post("/login")
def login(user: LoginRequest):

    connection = None
    cursor = None

    try:

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                name,
                email,
                password_hash,
                role
            FROM users
            WHERE email = %s
            """,
            (user.email,)
        )

        db_user = cursor.fetchone()

        if not db_user:

            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        # Verify password
        if not verify_password(
            user.password,
            db_user["password_hash"]
        ):

            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        # Generate JWT
        access_token = create_access_token(
            db_user["id"],
            db_user["email"],
            db_user["role"]
        )

        return {
            "status": "success",
            "message": "Login successful",
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": db_user["id"],
                "name": db_user["name"],
                "email": db_user["email"],
                "role": db_user["role"]
            }
        }

    except HTTPException:
        raise

    except Exception as e:

        return {
            "status": "error",
            "message": str(e)
        }

    finally:

        if cursor:
            cursor.close()

        if connection:
            connection.close()


# ============================================================
# CURRENT USER
# ============================================================

@app.get("/me")
def get_me(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    return get_current_user(credentials)
    

@app.get("/admin/users")
def get_all_users(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    current_user = get_current_user(credentials)

    if current_user["role"] != "ADMIN":
        raise HTTPException(
            status_code=403,
            detail="Admin access required"
        )

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT id, name, email, role, created_at
            FROM users
            ORDER BY created_at DESC
        """)

        users = cursor.fetchall()

        cursor.close()
        conn.close()

        return {
            "status": "success",
            "users": [
                {
                    **user,
                    "created_at": (
                        user["created_at"].isoformat()
                        if user["created_at"]
                        else None
                    )
                }
                for user in users
            ]
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve users"
        )
# ============================================================
# AI PREDICTION
# ============================================================
@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    # Identify the logged-in user
    current_user = get_current_user(credentials)
    user_id = current_user["user_id"]

    image_bytes = await file.read()

    # Run the existing YOLO detection
    result = detect_safety(image_bytes)

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        query = """
            INSERT INTO safety_detections
            (user_id, status, violations, detections)
            VALUES (%s, %s, %s, %s)
        """

        cursor.execute(
            query,
            (
                user_id,
                result["status"],
                json.dumps(result["violations"]),
                json.dumps(result["detections"])
            )
        )

        connection.commit()
        result["database"] = "saved"

    except Exception as e:
        if connection:
            connection.rollback()

        result["database"] = "error"
        result["database_message"] = str(e)

    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

    return result
# ============================================================
# INCIDENT HISTORY
# ============================================================
@app.get("/incidents")
def get_incidents(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    current_user = get_current_user(credentials)

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        if current_user["role"] == "ADMIN":
            query = """
                SELECT
                    id,
                    user_id,
                    status,
                    violations,
                    detected_at
                FROM safety_detections
                ORDER BY detected_at DESC
            """
            cursor.execute(query)

        else:
            query = """
                SELECT
                    id,
                    user_id,
                    status,
                    violations,
                    detected_at
                FROM safety_detections
                WHERE user_id = %s
                ORDER BY detected_at DESC
            """
            cursor.execute(query, (current_user["user_id"],))

        incidents = cursor.fetchall()

        for incident in incidents:
            if incident["detected_at"]:
                incident["detected_at"] = incident[
                    "detected_at"
                ].strftime("%Y-%m-%d %H:%M:%S")

        return {
            "status": "success",
            "count": len(incidents),
            "incidents": incidents
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve incident history"
        )

    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

# ============================================================
# DASHBOARD STATISTICS
# ============================================================

@app.get("/stats")
def get_stats(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    current_user = get_current_user(credentials)

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        # Admin sees all records; worker sees only their records.
        if current_user["role"] == "ADMIN":
            filter_sql = ""
            params = ()
        else:
            filter_sql = " WHERE user_id = %s"
            params = (current_user["user_id"],)

        # Total inspections
        cursor.execute(
            f"""
            SELECT COUNT(*)
            FROM safety_detections
            {filter_sql}
            """,
            params
        )
        total_checks = cursor.fetchone()[0]

        # Safe inspections
        cursor.execute(
            f"""
            SELECT COUNT(*)
            FROM safety_detections
            {filter_sql}
            {"AND" if filter_sql else "WHERE"} status = %s
            """,
            params + ("SAFE",)
        )
        safe_count = cursor.fetchone()[0]

        # Violation inspections
        cursor.execute(
            f"""
            SELECT COUNT(*)
            FROM safety_detections
            {filter_sql}
            {"AND" if filter_sql else "WHERE"} status = %s
            """,
            params + ("SAFETY VIOLATION",)
        )
        violation_count = cursor.fetchone()[0]

        # Count PPE violations
        cursor.execute(
            f"""
            SELECT violations
            FROM safety_detections
            {filter_sql}
            {"AND" if filter_sql else "WHERE"} status = %s
            """,
            params + ("SAFETY VIOLATION",)
        )

        rows = cursor.fetchall()

        no_helmet = 0
        no_vest = 0
        no_gloves = 0
        no_shoes = 0

        for row in rows:
            violations_text = (row[0] or "").lower()

            if "no-helmet" in violations_text:
                no_helmet += 1
            if "no-vest" in violations_text:
                no_vest += 1
            if "no-gloves" in violations_text:
                no_gloves += 1
            if "no-shoes" in violations_text:
                no_shoes += 1

        # Registered users: admin only
        registered_users = None

        if current_user["role"] == "ADMIN":
            cursor.execute("SELECT COUNT(*) FROM users")
            registered_users = cursor.fetchone()[0]

        return {
            "status": "success",
            "total_checks": total_checks,
            "safe_count": safe_count,
            "violation_count": violation_count,
            "registered_users": registered_users,
            "violations": {
                "no_helmet": no_helmet,
                "no_vest": no_vest,
                "no_gloves": no_gloves,
                "no_shoes": no_shoes
            }
        }

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve safety statistics"
        )

    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

@app.get("/incident-trends")
def get_incident_trends(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    current_user = get_current_user(credentials)

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        if current_user["role"] == "ADMIN":
            filter_sql = ""
            params = ()
        else:
            filter_sql = " AND user_id = %s"
            params = (current_user["user_id"],)

        cursor.execute(
            f"""
            SELECT
                DATE(detected_at) AS incident_date,
                COUNT(*) AS incident_count
            FROM safety_detections
            WHERE status = %s
              AND detected_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
              {filter_sql}
            GROUP BY DATE(detected_at)
            ORDER BY incident_date ASC
            """,
            ("SAFETY VIOLATION",) + params
        )

        rows = cursor.fetchall()

        return {
            "status": "success",
            "trends": [
                {
                    "date": row[0].isoformat(),
                    "count": row[1]
                }
                for row in rows
            ]
        }

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve incident trends"
        )

    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

@app.get("/admin/incident-report")
def get_admin_incident_report(
    period: str = "weekly",
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    current_user = get_current_user(credentials)

    # Only administrators can access this report.
    if current_user["role"] != "ADMIN":
        raise HTTPException(
            status_code=403,
            detail="Admin access required"
        )

    # Validate the reporting period.
    period = period.lower()

    period_intervals = {
        "daily": 1,
        "weekly": 7,
        "monthly": 30
    }

    if period not in period_intervals:
        raise HTTPException(
            status_code=400,
            detail="Period must be daily, weekly, or monthly"
        )

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        days = period_intervals[period]

        # Calculate inspection totals for the selected period.
        cursor.execute(
            """
            SELECT
                COUNT(*) AS total_checks,
                SUM(CASE WHEN status = 'SAFE' THEN 1 ELSE 0 END)
                    AS safe_count,
                SUM(
                    CASE
                        WHEN status = 'SAFETY VIOLATION' THEN 1
                        ELSE 0
                    END
                ) AS violation_count
            FROM safety_detections
            WHERE detected_at >= DATE_SUB(
                CURDATE(), INTERVAL %s DAY
            )
            """,
            (days,)
        )

        totals = cursor.fetchone()

        total_checks = totals[0] or 0
        safe_count = totals[1] or 0
        violation_count = totals[2] or 0

        # Retrieve violations recorded during the same period.
        cursor.execute(
            """
            SELECT violations
            FROM safety_detections
            WHERE status = %s
              AND detected_at >= DATE_SUB(
                  CURDATE(), INTERVAL %s DAY
              )
            """,
            ("SAFETY VIOLATION", days)
        )

        rows = cursor.fetchall()

        no_helmet = 0
        no_vest = 0
        no_gloves = 0
        no_shoes = 0

        for row in rows:
            violations_text = (row[0] or "").lower()

            if "no-helmet" in violations_text:
                no_helmet += 1
            if "no-vest" in violations_text:
                no_vest += 1
            if "no-gloves" in violations_text:
                no_gloves += 1
            if "no-shoes" in violations_text:
                no_shoes += 1

        violation_rate = (
            round((violation_count / total_checks) * 100, 2)
            if total_checks > 0 else 0
        )

        return {
            "status": "success",
            "period": period,
            "days": days,
            "total_checks": total_checks,
            "safe_count": safe_count,
            "violation_count": violation_count,
            "violation_rate": violation_rate,
            "violations": {
                "no_helmet": no_helmet,
                "no_vest": no_vest,
                "no_gloves": no_gloves,
                "no_shoes": no_shoes
            }
        }

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Failed to generate admin incident report"
        )

    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
