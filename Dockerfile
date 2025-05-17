# Use a specific, stable Python version
FROM python:3.13-slim-bookworm

# Set Python and Pip/UV environment variables for best practices
ENV PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=random \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    # Optional: Tell uv to use the Python from the base image path
    UV_SYSTEM_PYTHON=1

# Install uv using the base image's pip
RUN pip install uv

# Set the working directory
ENV APP_HOME=/app
WORKDIR $APP_HOME

# --- Dependency Installation ---

# Create the virtual environment FIRST
# This creates a .venv directory in $APP_HOME
RUN uv venv

# Copy ONLY the dependency definition files first to leverage Docker layer caching
COPY pyproject.toml . 
COPY .python-version .  
COPY uv.lock .      

# Install dependencies into the virtual environment using uv
RUN uv sync

# --- Application Code ---

# Copy the rest of your application code AFTER dependencies are installed
# This assumes your application code (e.g., youtube_summarizer_cloud_run directory)
# is in the same directory as the Dockerfile.
COPY ./youtube_summarizer_cloud_run ./youtube_summarizer_cloud_run

# --- Runtime Configuration ---

# Expose ports
# As there are 2 services running in one container (not the best practice)
# we won't be using the default CLoud Run oport 8080 
ENV BACKEND_PORT=8081
ENV STREAMLIT_PORT=8501
EXPOSE ${BACKEND_PORT:-8081}
EXPOSE ${STREAMLIT_PORT:-8501}

# Start both FastAPI and Streamlit.
CMD ["sh", "-c", "uv run python -m uvicorn youtube_summarizer_cloud_run.fast_api_backend:app --host 0.0.0.0 --port $BACKEND_PORT --reload & uv run python -m streamlit run youtube_summarizer_cloud_run/streamlit_frontend.py --server.address 0.0.0.0 --server.port $STREAMLIT_PORT"]