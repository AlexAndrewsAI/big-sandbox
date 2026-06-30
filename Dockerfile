FROM alexandrewsai/simple-agent-sandbox:latest

# Install apt packages from config.yml (must be root)
USER root

# Install sudo and grant sandbox password-less sudo access
RUN apt-get update && \
      apt-get install -y --no-install-recommends sudo && \
      rm -rf /var/lib/apt/lists/* && \
      echo "sandbox ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sandbox && \
      chmod 0440 /etc/sudoers.d/sandbox

COPY config.yml /tmp/config.yml

# Make config readable by sandbox user (used by installer.sh)
RUN chmod a+r /tmp/config.yml

RUN if [ -f /tmp/config.yml ] && yq '.apt' /tmp/config.yml &>/dev/null; then \
      apt-get update && \
      PACKAGES=$(yq '.apt[]' /tmp/config.yml | tr '\n' ' ') && \
      apt-get install -y --no-install-recommends $PACKAGES && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# Suppress rsyslog imklog warning (kernel log not available in containers)
RUN mkdir -p /etc/rsyslog.d && \
    echo 'module(load="immark")' > /etc/rsyslog.d/00-numeric.conf && \
    echo '$ModLoad immark' >> /etc/rsyslog.d/00-numeric.conf

# Return to non-root user (matching upstream)
USER sandbox
ENV HOME=/home/sandbox
WORKDIR /home/sandbox

COPY scripts/start-vnc.sh /usr/local/bin/start-vnc.sh
COPY scripts/installer.sh /usr/local/bin/installer.sh

USER root
RUN chmod a+rx /usr/local/bin/*
RUN chown -R sandbox:sandbox /usr/local/bin

# Run installer.sh (processes install: section in config.yml) as sandbox user
# so that tools (npm install -g, pip, curl-based installers) write to
# /home/sandbox instead of requiring root.
USER sandbox
RUN installer.sh /tmp/config.yml

EXPOSE 5901

CMD ["bash", "-c", "sudo chown -R sandbox:sandbox /persist && sudo rsyslogd && start-vnc.sh && exec bash -i"]
