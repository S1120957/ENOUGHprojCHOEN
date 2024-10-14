FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ENVs
ENV DJANGO_SETTINGS_MODULE=bpmn2solidity.settings
ENV PYTHONPATH=/app/code:$PYTHONPATH

# eseguiamo ora le migration dato che il db è un sqlite
# RUN django-admin migrate

EXPOSE 3000

CMD ["django-admin", "runserver", "0.0.0.0:3000"]