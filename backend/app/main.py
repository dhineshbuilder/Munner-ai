from fastapi import FastAPI, Depends, HTTPException, Query, Header, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional
from supabase import create_client, Client
from jose import jwt, JWTError

from app.core.config import settings

app = FastAPI(title=settings.PROJECT_NAME)

# Enable CORS for local development (crucial for Flutter debugging)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins, adjust in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Supabase Client
supabase: Client = None
if settings.SUPABASE_URL and settings.SUPABASE_KEY:
    try:
        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        print("Supabase client initialized successfully.")
    except Exception as e:
        print(f"Failed to initialize Supabase client: {e}")
else:
    print("Warning: SUPABASE_URL or SUPABASE_KEY not set. Backend will run in fallback/mock mode.")

# Pydantic Schemas
class ProfileOnboard(BaseModel):
    username: str = Field(..., min_length=3, max_length=20, pattern=r"^[a-zA-Z0-9_]+$")
    age: int = Field(..., gt=0, lt=120)
    height: float = Field(..., gt=30, lt=300)  # in cm
    weight: float = Field(..., gt=10, lt=500)  # in kg
    phone_number: str = Field(..., min_length=7, max_length=17)

class ProfileResponse(BaseModel):
    id: str
    username: str
    age: int
    height: float
    weight: float
    phone_number: str

# Dependency: Verify JWT and return user info
async def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing"
        )
    
    # Expecting: "Bearer <token>"
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format"
        )
    
    token = parts[1]

    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase client is not initialized"
        )

    # Verification Strategy 1: Local JWT decoding (if secret is provided)
    if settings.SUPABASE_JWT_SECRET:
        import base64
        try:
            # Supabase signs JWTs with the raw bytes of a Base64 encoded HS256 secret.
            # We must decode the base64 string to bytes before verification.
            try:
                # Add padding characters if missing (required by base64 module)
                padded_secret = settings.SUPABASE_JWT_SECRET
                missing_padding = len(padded_secret) % 4
                if missing_padding:
                    padded_secret += '=' * (4 - missing_padding)
                secret_key = base64.b64decode(padded_secret)
            except Exception:
                secret_key = settings.SUPABASE_JWT_SECRET

            payload = jwt.decode(
                token, 
                secret_key, 
                algorithms=["HS256"], 
                audience="authenticated"
            )
            user_id = payload.get("sub")
            email = payload.get("email")
            if not user_id:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject")
            return {"id": user_id, "email": email}
        except JWTError as e:
            # Fallback Strategy: If local verification fails, verify token directly via Supabase Auth API
            try:
                user_response = supabase.auth.get_user(token)
                if user_response and user_response.user:
                    return {
                        "id": user_response.user.id,
                        "email": user_response.user.email
                    }
            except Exception:
                pass  # Fall through to throw the original JWTError
                
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token verification failed: {str(e)}"
            )
            
    # Verification Strategy 2: Call Supabase Auth API (Default fallback)
    else:
        try:
            # We call get_user on the Supabase GoTrue API using the JWT
            user_response = supabase.auth.get_user(token)
            if not user_response or not user_response.user:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
            return {
                "id": user_response.user.id,
                "email": user_response.user.email
            }
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Supabase auth check failed: {str(e)}"
            )

@app.get("/")
def read_root():
    return {"message": "Welcome to முன்னேறு AI (Munner-Ai) Backend Service!"}

# Check if username is already taken
@app.get(f"{settings.API_V1_STR}/profiles/check-username")
def check_username(username: str = Query(..., min_length=3, max_length=20)):
    if not supabase:
        # Mock behavior for testing when Supabase is not configured
        if username.lower() == "admin" or username.lower() == "taken":
            return {"available": False, "message": f"Username '{username}' is already taken."}
        return {"available": True, "message": f"Username '{username}' is available."}

    try:
        # Try secure RPC function (checks database ignoring RLS select rules)
        result = supabase.rpc("check_username_exists", {"username_to_check": username}).execute()
        is_taken = result.data if isinstance(result.data, bool) else False
        return {
            "available": not is_taken,
            "message": f"Username '{username}' is {'already taken' if is_taken else 'available'}."
        }
    except Exception as rpc_error:
        # Fallback to direct select check if RPC fails (e.g. if SQL updates not executed yet)
        try:
            result = supabase.table("profiles").select("username").eq("username", username).execute()
            is_taken = len(result.data) > 0
            return {
                "available": not is_taken,
                "message": f"Username '{username}' is {'already taken' if is_taken else 'available'}."
            }
        except Exception as select_error:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Database query error: {str(select_error)}"
            )

# Create user profile (Onboarding completion)
@app.post(f"{settings.API_V1_STR}/profiles/create", response_model=ProfileResponse)
def create_profile(profile: ProfileOnboard, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    
    # If using dev bypass / mock mode
    if not supabase:
        return ProfileResponse(
            id=user_id,
            username=profile.username,
            age=profile.age,
            height=profile.height,
            weight=profile.weight,
            phone_number=profile.phone_number
        )

    # 1. Double check username availability
    try:
        username_check = supabase.rpc("check_username_exists", {"username_to_check": profile.username}).execute()
        is_taken = username_check.data if isinstance(username_check.data, bool) else False
        if is_taken:
            existing = supabase.rpc("get_profile_by_id", {"p_id": user_id}).execute()
            if not (existing.data and existing.data.get("username", "").lower() == profile.username.lower()):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username is already taken by another user."
                )
    except HTTPException:
        raise
    except Exception:
        pass

    # 2. Insert or Update profile in database using secure RPC
    try:
        rpc_params = {
            "p_id": user_id,
            "p_username": profile.username,
            "p_age": profile.age,
            "p_height": profile.height,
            "p_weight": profile.weight,
            "p_phone_number": profile.phone_number
        }
        result = supabase.rpc("upsert_profile", rpc_params).execute()
        if result.data:
            saved_profile = result.data
            return ProfileResponse(
                id=saved_profile["id"],
                username=saved_profile["username"],
                age=saved_profile["age"],
                height=saved_profile["height"],
                weight=saved_profile["weight"],
                phone_number=saved_profile["phone_number"]
            )
    except Exception:
        pass

    # Fallback to direct upsert
    profile_data = {
        "id": user_id,
        "username": profile.username,
        "age": profile.age,
        "height": profile.height,
        "weight": profile.weight,
        "phone_number": profile.phone_number
    }
    
    try:
        result = supabase.table("profiles").upsert(profile_data).execute()
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save profile record."
            )
        saved_profile = result.data[0]
        return ProfileResponse(
            id=saved_profile["id"],
            username=saved_profile["username"],
            age=saved_profile["age"],
            height=saved_profile["height"],
            weight=saved_profile["weight"],
            phone_number=saved_profile["phone_number"]
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error writing profile to database: {str(e)}"
        )

# Get current user profile
@app.get(f"{settings.API_V1_STR}/profiles/me", response_model=ProfileResponse)
def get_my_profile(current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]

    if not supabase:
        return ProfileResponse(
            id=user_id,
            username="mock_developer",
            age=25,
            height=175.0,
            weight=70.0,
            phone_number="+919876543210"
        )

    # 1. Try secure RPC function
    try:
        result = supabase.rpc("get_profile_by_id", {"p_id": user_id}).execute()
        if result.data:
            saved_profile = result.data
            return ProfileResponse(
                id=saved_profile["id"],
                username=saved_profile["username"],
                age=saved_profile["age"],
                height=saved_profile["height"],
                weight=saved_profile["weight"],
                phone_number=saved_profile["phone_number"]
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found. User needs onboarding."
            )
    except HTTPException:
        raise
    except Exception:
        pass

    # 2. Fallback to direct table query
    try:
        result = supabase.table("profiles").select("*").eq("id", user_id).execute()
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found. User needs onboarding."
            )
        saved_profile = result.data[0]
        return ProfileResponse(
            id=saved_profile["id"],
            username=saved_profile["username"],
            age=saved_profile["age"],
            height=saved_profile["height"],
            weight=saved_profile["weight"],
            phone_number=saved_profile["phone_number"]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database retrieval error: {str(e)}"
        )
