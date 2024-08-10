
FROM python:3.8-slim
RUN mkdir /app
WORKDIR /app
COPY src/ .
RUN pip install -r requirements.txt
ENV FLASK_APP=app.py
ENV FLASK_ENV=development
EXPOSE 5000
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0"]
