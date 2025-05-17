import os

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import RedirectResponse
from google import genai
from google.genai import types
from pydantic import BaseModel

# Initialize FastAPI app
app = FastAPI()


PROJECT_ID = "fussing-around-learning-gcp"  # "REPLACE_WITH_YOUR_PROJECT_ID"

# Initialize GenAI Client
# Ensure you have the correct authentication and project setup for this to work.
genai_client = None
genai_client_initialized = False
genai_initialization_error = None

try:
    # Configure the GenAI client (replace with your actual API key setup if not using ADC)
    # genai.configure(api_key="YOUR_API_KEY") # Example if using API key

    # Using Vertex AI as in the original setup
    genai_client = genai.Client(
        vertexai=True,  # This assumes Application Default Credentials (ADC) are set up.
        project=PROJECT_ID,
        location="us-central1",  # e.g., "us-central1"
    )
    # Attempt a simple call to check connectivity, e.g., listing models
    # This is a basic check; more robust checks might be needed.
    # For GenAI Python SDK client, a direct "ping" or "health" method isn't standard.
    # We'll assume it's healthy if initialization doesn't throw an error.
    genai_client_initialized = True
    print("GenAI Client initialized successfully.")
except Exception as e:
    genai_initialization_error = str(e)
    print(f"Error initializing GenAI Client: {genai_initialization_error}")
    # genai_client remains None


# Define a Pydantic model for the form data if you prefer strict typing
class SummarizeRequest(BaseModel):
    youtube_link: str
    model: str
    additional_prompt: str | None = None


class SummaryResponse(BaseModel):
    summary: str


# --- Pydantic Models ---
class HealthCheckResponse(BaseModel):
    status: str
    message: str
    genai_client_status: str
    genai_error_details: str | None = None


# --- Health Check Endpoint ---
@app.get("/", response_model=HealthCheckResponse, tags=["Health"])
async def health_check(request: Request):
    """
    Provides the health status of the application, including the GenAI client.
    """
    genai_status = "healthy"
    error_details = None
    if not genai_client_initialized or genai_client is None:
        genai_status = "unhealthy"
        error_details = genai_initialization_error or "Client not initialized."

    return HealthCheckResponse(
        status="healthy",
        message="Application is running. Visit /summarizer for the UI or /docs for API documentation.",
        genai_client_status=genai_status,
        genai_error_details=error_details,
    )


def generate_summary_content(
    youtube_link: str, model_name: str, additional_prompt: str | None
):
    """
    Generates a summary from a YouTube video link using the GenAI client.
    """
    if not genai_client:
        raise HTTPException(status_code=500, detail="GenAI Client not initialized.")

    # Prepare youtube video using the provided link
    try:
        youtube_video = types.Part.from_uri(
            file_uri=youtube_link,  # Corrected parameter name from file_uri to uri
            mime_type="video/*",
        )
    except Exception as e:
        # More specific error handling for URI issues might be needed
        raise HTTPException(
            status_code=400, detail=f"Invalid YouTube link or URI issue: {e}"
        )

    # If additional prompt is not provided, use a default or handle as needed
    DEFAULT_PROMPT = """
    Provide a summary of the video. Do not say 'Certainly', 'Sure', or 'Here is a summary'
    Just provide the summary.
    """
    prompt_text = DEFAULT_PROMPT
    if additional_prompt:
        prompt_text += f" {additional_prompt}"

    # Prepare content to send to the model
    contents = [
        youtube_video,
        types.Part.from_text(
            text=prompt_text
        ),  # Using the potentially modified prompt_text
    ]
    if (
        additional_prompt.strip()
    ):  # Add additional_prompt part only if it's not just whitespace
        contents.append(types.Part.from_text(text=additional_prompt))

    # Define content configuration
    generate_content_config = types.GenerateContentConfig(
        temperature=1.0,  # Float for temperature
        top_p=0.95,
        max_output_tokens=8192,
        # response_modalities = ["TEXT"], # This might be specific to older versions or certain models.
        # Often, the model infers this or it's set elsewhere.
        # If it causes issues, try removing it or check GenAI Python SDK documentation.
    )

    try:
        response = genai_client.models.generate_content(
            model=model_name, contents=contents, config=generate_content_config
        )
        return response.text
    except ValueError as e:  # Catching ValueError as in the original code
        raise HTTPException(status_code=400, detail=f"Input error for GenAI: {e}")
    except Exception as e:  # Catch other potential GenAI errors
        # Log the full error for debugging: print(f"GenAI Error: {e}")
        raise HTTPException(
            status_code=500, detail=f"GenAI content generation failed: {e}"
        )


@app.post("/summarize")
async def summarize_video(
    youtube_link: str = Form(...),
    model: str = Form(...),
    additional_prompt: str = Form(None),  # Use None for optional fields
):
    """
    Summarize the user provided YouTube video.
    Returns: Summary text or error.
    """
    try:
        summary = generate_summary_content(youtube_link, model, additional_prompt)
        return {"summary": summary}  # FastAPI typically returns JSON responses
    except HTTPException as e:
        raise e  # Re-raise HTTPException
    except Exception as e:
        # Catch any other unexpected errors from the generate_summary_content function
        # Log the error: print(f"Unexpected error in summarize_video: {e}")
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {e}"
        )


@app.get("/summarize")
async def redirect_summarize_get():
    """
    Redirects GET requests for /summarize to the home page.
    """
    return RedirectResponse(url="/", status_code=302)


if __name__ == "__main__":
    import uvicorn

    server_port = int(os.environ.get("PORT", "8080"))
    uvicorn.run(app, host="0.0.0.0", port=server_port)
