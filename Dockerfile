FROM ubuntu:latest

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# Update and install dependencies as root
RUN apt-get update && apt-get install -y sudo tzdata

# Copy the setup script
COPY setup.sh /setup/setup.sh

# Make the script executable
RUN chmod +x /setup/setup.sh

# Run the setup script
RUN /setup/setup.sh --no-gui
