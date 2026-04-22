@echo off
echo Starting Citadel Backend Server...
echo Using venv Python: %~dp0venv\Scripts\python.exe
call "%~dp0venv\Scripts\activate"
cd /d "%~dp0"
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload