# Use the official Python image.
# https://hub.docker.com/_/python
FROM --platform=linux/amd64 python:3.8-slim

# Copy local code to the container image.
ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . ./

# Install production dependencies.
RUN apt-get update && \
    pip install --upgrade pip && \
    pip install Flask==2.1.0 Jinja2==3.0.3 MarkupSafe==2.0.1 && \
    pip install -r requirements.txt

CMD ["gunicorn", "--access-logfile", "-", "--error-logfile", "-", "-w", "4", "-b", "0.0.0.0:8080", "app:app"]
