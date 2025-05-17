run_backend:
	uv run python -m uvicorn youtube_summarizer_cloud_run.fast_api_backend:app --host 0.0.0.0 --port 8081 --reload

run_frontend:
	uv run python -m streamlit run youtube_summarizer_cloud_run/streamlit_frontend.py --server.address 0.0.0.0 --server.port 8501