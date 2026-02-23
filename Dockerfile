FROM ubuntu:24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install sudo and minimal requirements for the script to initiate
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a 'developer' user and enable passwordless sudo
RUN useradd -m -s /bin/bash developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER developer
WORKDIR /home/developer/setup

# Copy the setup script with correct ownership
COPY --chown=developer:developer setup.sh .

# Run the setup script
# GUI tools and desktop configurations will be skipped automatically 
# as no $DISPLAY environment variable is present during build.
RUN chmod +x setup.sh && ./setup.sh

# Final environment settings
WORKDIR /home/developer
CMD ["/bin/bash"]
