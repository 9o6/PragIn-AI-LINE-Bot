# Find the Dockerfile at this URL
# https://github.com/Azure/azure-functions-docker/blob/dev/host/4/bullseye/amd64/python/python38/python38-core-tools.Dockerfile
# https://github.com/Azure/azure-functions-docker
FROM mcr.microsoft.com/azure-functions/python:4-python3.8-core-tools

RUN curl -Lo /usr/local/bin/bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
    && chmod +x /usr/local/bin/bicep 
