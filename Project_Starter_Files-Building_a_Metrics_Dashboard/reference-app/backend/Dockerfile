# Use the official Python image.
# https://hub.docker.com/_/python
FROM --platform=linux/amd64 python:3.8-slim

# Copy local code to the container image.
ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . ./

ARG PROJECT_ID
ENV PROJECT_ID ${PROJECT_ID}


# Install production dependencies.
RUN apt-get update && \
    apt-get install -y curl dnsutils && \
    pip install --upgrade pip && \
    pip install -r requirements.txt

CMD ["gunicorn", "--access-logfile", "-", "--error-logfile", "-", "-w", "4", "-b", "0.0.0.0:8080", "app:app"]
