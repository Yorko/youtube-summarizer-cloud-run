import streamlit as st
import requests # Added for making HTTP requests
import json # Added for parsing potential JSON error responses

# --- Configuration ---
BACKEND_URL = "http://0.0.0.0:8080"  # URL of your running Fast API application

# --- Helper Functions ---

def summarize_video_with_backend(video_url, model_name, custom_prompt):
    """
    Calls the backend to summarize the YouTube video.
    """
    summarize_endpoint = f"{BACKEND_URL}/summarize"
    payload = {
        "youtube_link": video_url,
        "model": model_name,
        "additional_prompt": custom_prompt
    }

    try:
        # Make a POST request to the Fast API backend
        # Increased timeout as video processing can take time
        response = requests.post(summarize_endpoint, data=payload, timeout=300) # Timeout of 5 minutes

        # Check if the request was successful
        if response.status_code == 200:
            return response.json()["summary"], None  # Fast API app returns plain text summary
        else:
            try:
                # Try to parse error from Fast API if it sends JSON
                error_details = response.json()
                error_message = f"Error from backend: {error_details.get('error', response.text)}"
            except ValueError: # If not JSON, use the raw text
                error_message = f"Backend Error (Status {response.status_code}): {response.text}"
            return None, error_message

    except requests.exceptions.RequestException as e:
        return None, f"Could not connect to the summarization backend: {e}. Ensure the Fast API app is running at {BACKEND_URL}."
    except Exception as e:
        return None, f"An unexpected error occurred: {str(e)}"

# --- Streamlit App UI ---
st.set_page_config(layout="wide", page_title="YouTube Video Summarizer")

st.title("🎬 YouTube Video Summarizer")
st.markdown(f"""
    Paste a YouTube video link below, choose your Gemini model, add any custom instructions,
    and get a summary of the video!
""")

# --- Input Fields ---
with st.container():
    youtube_link = st.text_input("🔗 YouTube Video Link:", placeholder="e.g., youtube.com/watch?v=")

    # Model options should align with what your Fast API app's Vertex AI client expects.
    # These are common Gemini model identifiers.
    model_options = [
        "gemini-2.0-flash-001", 
        "gemini-2.0-pro-001",
        "gemini-2.5-flash-001",
        "gemini-2.5-pro-001"
    ]
    selected_model = st.selectbox("🤖 Select Gemini Model:", model_options, index=0)

    custom_instructions = st.text_area("📝 Custom Instructions (Optional):", placeholder="e.g., Summarize for a beginner, focus on the technical aspects, provide a 3-bullet point summary...")

    summarize_button = st.button("✨ Generate Summary", type="primary", use_container_width=True)

# --- Summarization Logic and Output ---
if summarize_button:
    if not youtube_link:
        st.warning("⚠️ Please enter a YouTube video link.")
    else:
        with st.spinner(f"🔄 Requesting summary from backend ({selected_model})... This may take a few minutes for longer videos."):
            summary, error_msg = summarize_video_with_backend(youtube_link, selected_model, custom_instructions)

            if error_msg:
                st.error(f"🛑 Error: {error_msg}")
            elif summary:
                st.subheader("💡 Summary")
                st.markdown(summary)
            else:
                st.warning("⚠️ No summary could be generated, or an unknown error occurred.")

st.markdown("---")
st.markdown("Built with ❤️ using [Streamlit](https://streamlit.io). Based on [this](https://codelabs.developers.google.com/devsite/codelabs/build-youtube-summarizer) codelab.")