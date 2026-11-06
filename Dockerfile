FROM myoung34/github-runner:ubuntu-resolute

ENV DEBIAN_FRONTEND=noninteractive
ENV RUN_AS_ROOT=true \
    UNSET_CONFIG_VARS=true
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_NDK_HOME=/opt/android-ndk/latest \
    NDK_HOME=/opt/android-ndk/latest

# Enable multi-arch execution for x86_64 NDK binaries inside an ARM64 container
RUN dpkg --add-architecture amd64 && \
    # 1. Scope default ARM repos so they ignore amd64
    sed -i 's/Types: deb/Types: deb\nArchitectures: arm64/g' /etc/apt/sources.list.d/ubuntu.sources && \
    CODENAME=resolute && \
    # 2. Add standard Ubuntu repos for amd64 binaries
    printf "Types: deb\n\
URIs: http://archive.ubuntu.com/ubuntu/\n\
Suites: ${CODENAME} ${CODENAME}-updates ${CODENAME}-backports\n\
Components: main restricted universe multiverse\n\
Architectures: amd64\n\
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\n\
Types: deb\n\
URIs: http://security.ubuntu.com/ubuntu/\n\
Suites: ${CODENAME}-security\n\
Components: main restricted universe multiverse\n\
Architectures: amd64\n\
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n" > /etc/apt/sources.list.d/amd64.sources && \
    # 3. Refresh and install
    apt-get update && apt-get install -y --no-install-recommends \
    qemu-user-binfmt \
    binfmt-support \
    libc6:amd64 \
    libstdc++6:amd64 \
    libncurses6:amd64 \
    zlib1g:amd64 \
    curl \
    git \
    bash \
    build-essential \
    make \
    cmake \
    patch \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    ca-certificates \
    openjdk-25-jdk-headless \
    unzip \
    openssh-client \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    binutils-mingw-w64-x86-64 \
    nsis \
    && rm -rf /var/lib/apt/lists/*

# Dynamic JAVA_HOME setup
RUN ARCH=$(dpkg --print-architecture) && \
    ln -s /usr/lib/jvm/java-25-openjdk-${ARCH} /usr/lib/jvm/default-java
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH=/usr/local/cargo/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# Install Rust & Android targets
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal \
    && chmod -R a+w /usr/local/rustup /usr/local/cargo \
    && rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android \
    && cargo install cargo-ndk --locked \
    && rm -rf /usr/local/cargo/registry /usr/local/cargo/git

# Install Android Command-line Tools (Android CLI)
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    curl -fSL "https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip" -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# Accept Android SDK licenses & install SDK 36 + build-tools
RUN java -version && \
    yes | android sdk --licenses > /dev/null 2>&1 || true; \
    android sdk --install --channel=0 "platforms;android-36" "build-tools;36.0.0" "platform-tools"

# Install Android NDK (architecture-aware)
RUN ARCH=$(uname -m) && \
    NDK_ZIP="android-ndk-r27c-linux.zip" && \
    curl -fSL "https://dl.google.com/android/repository/${NDK_ZIP}" -o /tmp/ndk.zip && \
    mkdir -p /opt/android-ndk && \
    unzip -q /tmp/ndk.zip -d /opt/android-ndk && \
    ln -s /opt/android-ndk/android-ndk-* /opt/android-ndk/latest && \
    rm -f /tmp/ndk.zip

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_26.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.android
