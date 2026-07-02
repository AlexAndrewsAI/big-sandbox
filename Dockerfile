# big-sandbox Dockerfile
# =====================
# Extends simple-agent-sandbox with a full VNC-accessible XFCE desktop,
# browsers, editors, and user-configurable tools from config.yml.
#
# Build:  ./build.sh
# Run:    ./run.sh
# Connect: vnc://localhost:5901

FROM alexandrewsai/simple-agent-sandbox:latest

# --- Sudo setup (root) --------------------------------------------------------
# The sandbox user needs password-less sudo so start-vnc.sh can launch Xvfb
# (which requires root to create /tmp/.X11-unix) and fix /persist ownership.
USER root

RUN apt-get update && \
      apt-get install -y --no-install-recommends sudo openssh-server sshpass \
      && rm -rf /var/lib/apt/lists/* && \
      echo "sandbox ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sandbox && \
      chmod 0440 /etc/sudoers.d/sandbox

# Install yq
RUN apt-get update && apt-get install -y --no-install-recommends yq

# --- Copy config into the image -----------------------------------------------
COPY config.yml /tmp/config.yml
RUN chmod a+r /tmp/config.yml
# installer.sh runs as sandbox, needs read access

# --- Install apt packages from config.yml (root) ------------------------------
RUN if [ -f /tmp/config.yml ] && yq '.apt' /tmp/config.yml &>/dev/null; then \
      apt-get update && \
      PACKAGES=$(yq '.apt[]' /tmp/config.yml | tr '\n' ' ') && \
      apt-get install -y --no-install-recommends $PACKAGES && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# --- Silence rsyslog imklog warning ------------------------------------------
# Containers have no /proc/kmsg, so imklog would spam "kernel log not found".
# Loading the immark module replaces it with periodic mark messages instead.
RUN mkdir -p /etc/rsyslog.d && \
    echo 'module(load="immark")' > /etc/rsyslog.d/00-numeric.conf

# --- SSH server configuration -------------------------------------------------
# Configure SSH server for secure VNC tunneling with password auth
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
        /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' \
        /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' \
        /etc/ssh/sshd_config && \
    mkdir -p /home/sandbox/.ssh && \
    chmod 700 /home/sandbox/.ssh && \
    chown sandbox:sandbox /home/sandbox/.ssh && \
    echo 'sandbox:sandbox' | chpasswd



# --- Switch to sandbox user ---------------------------------------------------
USER sandbox
ENV HOME=/home/sandbox
WORKDIR /home/sandbox


# --- Install bashrc scripts ---------------------------------------------------
RUN git clone https://github.com/AlexAndrewsAI/useful-shell-scripts.git
RUN /bin/bash /home/sandbox/useful-shell-scripts/setup.sh
RUN chown -R sandbox:sandbox useful-shell-scripts

# --- Append to .bashrc --------------------------------------------------------
RUN echo '# Source personal customizations if present' \
        '(not committed to git)' >> /home/sandbox/.bashrc && \
    echo 'if [ -f /persist/bashrc-extra ]; then' >> /home/sandbox/.bashrc && \
    echo '    . /persist/bashrc-extra' >> /home/sandbox/.bashrc && \
    echo 'fi' >> /home/sandbox/.bashrc

RUN chown sandbox:sandbox /home/sandbox/.bashrc


# --- Install helper scripts ---------------------------------------------------
COPY scripts/start-vnc.sh /usr/local/bin/start-vnc.sh
COPY scripts/installer.sh /usr/local/bin/installer.sh


USER root
RUN chmod a+rx /usr/local/bin/*
RUN chown -R sandbox:sandbox /usr/local/bin

# --- Run custom install steps from config.yml (sandbox user) ------------------
# Running as sandbox ensures downloaded tools (AppImages, pip, npm globals)
# write to /home/sandbox without needing root.
USER sandbox
RUN installer.sh /tmp/config.yml

# --- Runtime ------------------------------------------------------------------
EXPOSE 5901 22

# HEALTHCHECK: verify x11vnc is listening on the expected port.
# Docker will report "unhealthy" if the VNC server crashes or fails to start.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD nc -z localhost 5901 || exit 1

# On container start:
#   1. Fix /persist ownership (may have been created by root on the host).
#   2. Copy .bashrc to /persist so it can be modified.
#   3. Start rsyslog so container logs are captured.
#   4. Generate SSH host keys and start SSH server for secure tunneling.
#   5. Launch the VNC desktop (Xvfb + XFCE + x11vnc).
#   6. Drop into an interactive bash shell.
CMD ["bash", "-c", \
     "sudo chown -R sandbox:sandbox /persist && \
      cp /home/sandbox/.bashrc /persist/.bashrc && \
      sudo rsyslogd && \
      sudo ssh-keygen -A && \
      sudo /usr/sbin/sshd && \
      start-vnc.sh && \
      exec bash -i"]
