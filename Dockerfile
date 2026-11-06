FROM myoung34/github-runner:ubuntu-resolute

ENV DEBIAN_FRONTEND=noninteractive
ENV RUN_AS_ROOT=true \
    UNSET_CONFIG_VARS=true
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk

RUN apt-get update && apt-get install -y --no-install-recommends \
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

# Static JAVA_HOME setup
RUN ln -s /usr/lib/jvm/java-25-openjdk-arm64 /usr/lib/jvm/default-java
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH=/usr/local/cargo/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# Install Rust & Android targets
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal \
    && chmod -R a+w /usr/local/rustup /usr/local/cargo \
    && rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android \
    && cargo install cargo-ndk --locked \
    && rm -rf /usr/local/cargo/registry /usr/local/cargo/git

# Install Android SDK & NDK
RUN curl -fsSL https://dl.google.com/android/cli/latest/linux_arm64/install_root.sh | bash && \
    android sdk --no-metrics install "platforms/android-37.2" "build-tools/37.0.0-rc2" "platform-tools" "ndk/30.0.16248370"

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_26.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.android
