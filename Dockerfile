FROM ai-office-backend:latest

WORKDIR /app
COPY app/ /app/

CMD ["python3", "-u", "main.py"]